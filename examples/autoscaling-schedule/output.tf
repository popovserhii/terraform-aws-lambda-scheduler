# Lambda information
output "lambda_stop_name" {
  value = module.infra-stop-nightly.scheduler_lambda_name
}

output "lambda_stop_arn" {
  value = module.infra-stop-nightly.scheduler_lambda_arn
}

output "lambda_start_name" {
  value = module.infra-start-daily.scheduler_lambda_name
}

output "lambda_start_arn" {
  value = module.infra-start-daily.scheduler_lambda_arn
}
