data "aws_guardduty_detector" "existing" {}

resource "aws_guardduty_detector" "main" {
  count = length(data.aws_guardduty_detector.existing.id) == 0 ? 1 : 0
  enable = true
}

resource "aws_cloudwatch_log_group" "guardduty_logs" {
  name = "/aws/guardduty/findings"
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings"
  description = "Capture GuardDuty findings"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_logs" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToCloudWatch"
  arn       = aws_cloudwatch_log_group.guardduty_logs.arn
}

resource "aws_cloudwatch_log_resource_policy" "guardduty_policy" {
  policy_name = "GuardDutyToCloudWatch"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "logs:PutLogEvents"
      Resource = aws_cloudwatch_log_group.guardduty_logs.arn
    }]
  })
}