resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-sg"
  description = "Security group for MongoDB server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "mongodb_eks_access" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mongodb.id
  source_security_group_id = module.eks.eks_managed_node_groups["workwiz_app"].node_security_group_id
}

resource "aws_iam_role" "mongodb_role" {
  name = "${var.project_name}-mongodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount": data.aws_caller_identity.current.account_id
          }
          StringLike = {
            "aws:SourceArn": "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "mongodb_policy" {
  name = "${var.project_name}-mongodb-policy"
  role = aws_iam_role.mongodb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.backup.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.mongosecret.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb_profile" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb_role.name
}

resource "aws_secretsmanager_secret" "mongosecret" {
  name = "${var.project_name}-mongodb-creds"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongosecret" {
  secret_id = aws_secretsmanager_secret.mongosecret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

resource "aws_instance" "mongodb" {
  ami           = var.db_ami
  instance_type = var.db_instance_type
  subnet_id     = module.vpc.public_subnets[0]

  vpc_security_group_ids = [
    aws_security_group.mongodb.id
  ]

  iam_instance_profile = aws_iam_instance_profile.mongodb_profile.name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get upgrade -y
    apt-get install -y gnupg curl unzip jq
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install

    apt-get install -y ec2-instance-connect 

    echo "deb [ arch=arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    apt-get install -y software-properties-common
    apt-get update
    apt-get install -y mongodb-org

    sed -i -e 's/  bindIp: 127.0.0.1/  bindIp: 0.0.0.0/g' /etc/mongod.conf
    echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf

    systemctl enable mongod
    systemctl daemon-reload
    systemctl restart mongod

    # Wait for MongoDB to be ready
    max_attempts=30
    attempt=0
    while ! mongo --eval "db.runCommand({ ping: 1 })" >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            echo "Failed to connect to MongoDB after $max_attempts attempts"
            exit 1
        fi
        echo "Waiting for MongoDB to be ready... (attempt $attempt/$max_attempts)"
        sleep 5
    done

    # Retrieve credentials from AWS Secrets Manager
    max_attempts=10
    attempt=0
    while ! CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongosecret.id} --region ${var.region} --query SecretString --output text); do
        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            echo "Failed to retrieve secrets from AWS Secrets Manager"
            exit 1
        fi
        echo "Retrying secrets retrieval... (attempt $attempt/$max_attempts)"
        sleep 5
    done

    CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongosecret.id} --region ${var.region} --query SecretString --output text)
    DB_USERNAME=$(echo "$CREDENTIALS" | jq -r .username)
    DB_PASSWORD=$(echo "$CREDENTIALS" | jq -r .password)

    mongo admin --eval "db.createUser({user: '$DB_USERNAME', pwd: '$DB_PASSWORD', roles:[{role:'root',db:'admin'}]})"

    sudo -u ubuntu mkdir -p /home/ubuntu/tmp

    # Create backup script
    cat << 'EOB' > /usr/local/bin/backup_mongo.sh
    #!/bin/bash
    export PATH="/usr/local/bin:/usr/bin:/bin"

    TIMESTAMP=$(date +"%F-%H%M%S")
    BACKUP_NAME="mongo-backup-$TIMESTAMP"
    BACKUP_DIR="/home/ubuntu/tmp/$BACKUP_NAME"
    S3_BUCKET="${aws_s3_bucket.backup.bucket}"

    CREDENTIALS=$(/usr/local/bin/aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongosecret.id} --region ${var.region} --query SecretString --output text)
    DB_USERNAME=$(echo "$CREDENTIALS" | /usr/bin/jq -r .username)
    DB_PASSWORD=$(echo "$CREDENTIALS" | /usr/bin/jq -r .password)

    /usr/bin/mongodump --host localhost --archive="$BACKUP_DIR.archive" --gzip --username "$DB_USERNAME" --password "$DB_PASSWORD" --authenticationDatabase admin

    /usr/local/bin/aws s3 cp "$BACKUP_DIR.archive" "s3://$S3_BUCKET/$BACKUP_NAME.archive"

    rm -f "$BACKUP_DIR.archive"
    EOB

    chmod +x /usr/local/bin/backup_mongo.sh

    # Setup cron job
    echo "0 * * * * /bin/bash -c 'export PATH=\"/usr/local/bin:/usr/bin:/bin\" && /usr/local/bin/backup_mongo.sh >> /home/ubuntu/backup_mongo.log 2>&1'" | crontab -u ubuntu -
  EOF

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}

output "mongodb_private_ip" {
    value = aws_instance.mongodb.private_ip
}

output "mongodb_instance_id" {
    value = aws_instance.mongodb.id
}
