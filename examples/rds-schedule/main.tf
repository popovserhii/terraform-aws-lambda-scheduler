# Specify the provider and access details
provider "aws" {
  region = "eu-central-1"
  profile = var.profile

  # Make it faster by skipping something (don't use it in production)
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

resource "random_pet" "random-tag" {
  length = 2
}

# Create VPC use by RDS
resource "aws_vpc" "network" {
  cidr_block = "10.103.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "dev-env"
  }
}

# Create subnets use by RDS
resource "aws_subnet" "primary" {
  cidr_block = "10.103.98.0/24"
  vpc_id = aws_vpc.network.id
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "secondary" {
  cidr_block = "10.103.99.0/24"
  vpc_id = aws_vpc.network.id
  availability_zone = "eu-central-1b"
}

resource "aws_db_subnet_group" "db-subnet-group" {
  name       = "db-subnet"
  subnet_ids = [aws_subnet.primary.id, aws_subnet.secondary.id]
}

# Create RDS Mariadb instance with tag
resource "aws_db_instance" "mariadb_scheduled" {
  identifier           = "mariadb-instance-with-tag"
  name                 = "mariadbwithtag"
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.id
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mariadb"
  engine_version       = "10.3"
  instance_class       = "db.t2.micro"
  username             = "foo"
  password             = "foobarbaz"
  skip_final_snapshot  = "true"

  tags = {
    ToStop        = "true"
    TestTag = random_pet.random-tag.id
  }
}

# Create RDS MySQL instance with tag
resource "aws_db_instance" "mysql_not_scheduled" {
  identifier           = "mysql-instance-without-tag"
  name                 = "mysqlwithouttag"
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.id
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.6"
  instance_class       = "db.t2.micro"
  username             = "foo"
  password             = "foobarbaz"
  skip_final_snapshot  = "true"

  tags = {
    ToStop        = "false"
    TestTag = random_pet.random-tag.id
  }
}

# Terraform Lambda Scheduler Module
module "infra-stop-nightly" {
  source                         = "../../"
  name                           = "stop-rds-mariadb"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 17 ? * MON-SUN *)" # UTC
  schedule_action                = "stop"

  spot_schedule                  = false
  ec2_schedule                   = false
  rds_schedule                   = true
  autoscaling_schedule           = false
  cloudwatch_alarm_schedule      = false

  resource_tags = [{
      Key = "ToStop"
      Value = "true"
    }]
}

module "infra-start-daily" {
  source                         = "../../"
  name                           = "start-rds-mariadb"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 07 ? * MON-SUN *)" # UTC
  schedule_action                = "start"

  spot_schedule                  = false
  ec2_schedule                   = false
  rds_schedule                   = true
  autoscaling_schedule           = false
  cloudwatch_alarm_schedule      = false

  resource_tags = [{
      Key = "ToStop"
      Value = "true"
    }]
}
