# Terraform variables file

# Set cloudwatch events for shutingdown instances
# trigger lambda functuon every night at 22h00 from Monday to Friday.
# Cron time must be in UTC format.
# cf doc : https://docs.aws.amazon.com/lambda/latest/dg/tutorial-scheduled-events-schedule-expressions.html
variable "cloudwatch_schedule_expression" {
  description = "Define the aws cloudwatch event rule schedule expression"
  type        = string
  default     = "cron(0 18 ? * MON-FRI *)"
}

variable "name" {
  description = "Define name to use for lambda function, cloudwatch event and iam role"
  type        = string
}

variable "custom_iam_role_arn" {
  description = "Custom IAM role arn for the scheduling lambda"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "The ARN for the KMS encryption key. If this configuration is not provided when environment variables are in use, AWS Lambda uses a default service key."
  type        = string
  default     = null
}

variable "aws_regions" {
  description = "A list of one or more aws regions where the lambda will be apply, default use the current region"
  type        = list(string)
  default     = null
}

variable "schedule_action" {
  description = "Define schedule action to apply on resources, accepted value are 'stop or 'start"
  type        = string
  default     = "stop"
}

variable "resource_tags" {
  description = "Set the tags use for identify resources to stop or start"
  type        = list(map(string))

  default = [{
    key   = "ToStop"
    value = "true"
  }]
}

variable "autoscaling_schedule" {
  description = "Enable scheduling on autoscaling resources"
  type        = bool
  default     = false
}

variable "spot_schedule" {
  description = "Enable scheduling on spot instance resources"
  type        = bool
  default     = false
}

variable "ec2_schedule" {
  description = "Enable scheduling on ec2 resources"
  type        = bool
  default     = false
}

variable "rds_schedule" {
  description = "Enable scheduling on rds resources"
  type        = bool
  default     = false
}

variable "cloudwatch_alarm_schedule" {
  description = "Enable scheduleding on cloudwatch alarm resources"
  type        = bool
  default     = false
}
