# Terraform mit ALB Helm Deployment

Installiert einen Kubernetes Cluster mit für ALB Controller (inkl IAM Policy):

```bash
terraform init
terraform plan
terraform apply
```

Dauer etwa 15 Minuten

Wenn der Cluster läuft, liegt ein kubeconfig File im Verzeichnis:
```bash
aws eks update-kubeconfig --region eu-central-1 --name learnk8s
```


