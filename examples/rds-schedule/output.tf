# Used for connection in application config
output "rds_db_instance_address" {
  value       = aws_db_instance.mariadb_scheduled.address
}

output "rds_db_instance_id" {
  value       = aws_db_instance.mariadb_scheduled.id
}

output "rds_db_instance_port" {
  value       = aws_db_instance.mariadb_scheduled.port
}

output "rds_db_instance_username" {
  value       = aws_db_instance.mariadb_scheduled.username
}

output "rds_db_instance_password" {
  value       = aws_db_instance.mariadb_scheduled.password
}

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
