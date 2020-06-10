# Freeze aws provider version
terraform {
  required_version = ">= 0.12"

  required_providers {
    aws     = ">= 2.9.0"
    archive = ">= 1.2.2"
  }
}

data "aws_region" "current" {}

################################################
#
#            IAM CONFIGURATION
#
################################################
data "aws_iam_policy_document" "role_policy" {
  statement {
    sid = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

resource "aws_iam_role" "this" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name = "${var.name}-scheduler-lambda"
  assume_role_policy = data.aws_iam_policy_document.role_policy.json
}

data "aws_iam_policy_document" "autoscaling_policy" {
  statement {
    sid = ""
    effect = "Allow"
    resources = ["*"]

    actions = [
      "autoscaling:DescribeScalingProcessTypes",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeTags",
      "autoscaling:SuspendProcesses",
      "autoscaling:ResumeProcesses",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:TerminateInstances"
    ]
  }
}

resource "aws_iam_role_policy" "schedule_autoscaling" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name  = "${var.name}-autoscaling-custom-policy-scheduler"
  role  = aws_iam_role.this[0].id

  policy = data.aws_iam_policy_document.autoscaling_policy.json
}

data "aws_iam_policy_document" "spot_policy" {
  statement {
    sid = ""
    effect = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeSpotInstanceRequests"
    ]
  }
}

resource "aws_iam_role_policy" "schedule_spot" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name  = "${var.name}-spot-custom-policy-scheduler"
  role  = aws_iam_role.this[0].id

  policy = data.aws_iam_policy_document.spot_policy.json
}

data "aws_iam_policy_document" "ec2_policy" {
  statement {
    sid = ""
    effect = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:DescribeTags"
    ]
  }
}

resource "aws_iam_role_policy" "schedule_ec2" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name  = "${var.name}-ec2-custom-policy-scheduler"
  role  = aws_iam_role.this[0].id

  policy = data.aws_iam_policy_document.ec2_policy.json
}

data "aws_iam_policy_document" "rds_policy" {
  statement {
    sid = ""
    effect = "Allow"

    resources = ["*"]

    actions = [
      "rds:ListTagsForResource",
      "rds:DescribeDBClusters",
      "rds:StartDBCluster",
      "rds:StopDBCluster",
      "rds:DescribeDBInstances",
      "rds:StartDBInstance",
      "rds:StopDBInstance"
    ]
  }
}

resource "aws_iam_role_policy" "schedule_rds" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name  = "${var.name}-rds-custom-policy-scheduler"
  role  = aws_iam_role.this[0].id

  policy = data.aws_iam_policy_document.rds_policy.json
}

data "aws_iam_policy_document" "cloudwatch_policy" {
  statement {
    sid = ""
    effect = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:ListTagsForResource"
    ]
  }
}

resource "aws_iam_role_policy" "schedule_cloudwatch" {
  count = var.custom_iam_role_arn == null ? 1 : 0
  name  = "${var.name}-cloudwatch-custom-policy-scheduler"
  role  = aws_iam_role.this[0].id

  policy = data.aws_iam_policy_document.cloudwatch_policy.json
}

locals {
  lambda_logging_policy = {
    "Version": "2012-10-17",
    "Statement": [
      {
        Action: [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: "arn:aws:logs:*:*:*",
        Effect: "Allow"
      }
    ]
  }
  lambda_logging_and_kms_policy = {
    "Version": "2012-10-17",
    "Statement": [
      {
        Action: [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: "arn:aws:logs:*:*:*",
        Effect: "Allow"
      },
      {
        Action: [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:CreateGrant"
        ],
        Resource: var.kms_key_arn
        Effect: "Allow"
      }
    ]
  }
}


resource "aws_iam_role_policy" "lambda_logging" {
  count  = var.custom_iam_role_arn == null ? 1 : 0
  name   = "${var.name}-lambda-logging"
  role   = aws_iam_role.this[0].id
  policy = var.kms_key_arn == null ? jsonencode(local.lambda_logging_policy) : jsonencode(local.lambda_logging_and_kms_policy)
}

################################################
#
#            LAMBDA FUNCTION
#
################################################

# Convert *.js to .zip because AWS Lambda need .zip
data "archive_file" "zip" {
  type = "zip"
  source_dir  = "${path.module}/package/src/"
  output_path = "${path.module}/aws-stop-start-resources.zip"
}

resource "aws_lambda_function" "this" {
  function_name = var.name

  handler = "index.handler"
  role = aws_iam_role.this[0].arn
  runtime = "nodejs12.x"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  timeout          = "600"

  kms_key_arn      = var.kms_key_arn == null ? "" : var.kms_key_arn

  environment {
    variables = {
      AWS_REGIONS               = var.aws_regions == null ? data.aws_region.current.name : join(", ", var.aws_regions)
      SCHEDULE_ACTION           = var.schedule_action
      RESOURCE_TAGS            = jsonencode(var.resource_tags)
      EC2_SCHEDULE              = var.ec2_schedule == true ? "true" : "false"
      RDS_SCHEDULE              = var.rds_schedule == true ? "true" : "false"
      AUTOSCALING_SCHEDULE      = var.autoscaling_schedule == true ? "true" : "false"
      SPOT_SCHEDULE             = var.spot_schedule == true ? "true" : "false"
      CLOUDWATCH_ALARM_SCHEDULE = var.cloudwatch_alarm_schedule == true ? "true" : "false"
    }
  }
}

################################################
#
#            CLOUDWATCH EVENT
#
################################################

resource "aws_cloudwatch_event_rule" "this" {
  name                = "trigger-lambda-scheduler-${var.name}"
  description         = "Trigger lambda scheduler"
  schedule_expression = var.cloudwatch_schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  arn  = aws_lambda_function.this.arn
  rule = aws_cloudwatch_event_rule.this.name
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = aws_lambda_function.this.function_name
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

################################################
#
#            CLOUDWATCH LOG
#
################################################
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 14
}
