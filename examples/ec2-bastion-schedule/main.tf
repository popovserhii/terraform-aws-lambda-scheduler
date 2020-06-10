# Create AWS region
provider "aws" {
  region = "eu-central-1"
  profile = "terraform"

  # Make it faster by skipping something (don't use it in production)
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

# Create VPC use by Bastion
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

# Create subnet use by Bastion
resource "aws_subnet" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
}

# Bastion host
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.bastion.id
  key_name                    = "terraform-keypair"
  instance_type               = "t3a.nano"
  vpc_security_group_ids      = [data.aws_security_group.bastion.id]

  subnet_id = aws_subnet.this.id

  associate_public_ip_address = true
  monitoring                  = true

  tags = {
    Name = "ec2-bastion"
    Environment = "dev"
    ToStop = "true"
  }
}


# Terraform Lambda Scheduler Module
module "infra-stop-nightly" {
  source                         = "../../"
  name                           = "stop-ec2-bastion"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 17 ? * MON-SUN *)" # UTC
  schedule_action                = "stop"

  spot_schedule                  = true
  ec2_schedule                   = false
  rds_schedule                   = false
  autoscaling_schedule           = false
  cloudwatch_alarm_schedule      = false

  resource_tags = [
    {
      Key = "ToStop"
      Value = "true"
    },
    {
      Key = "Environment"
      Value = "dev"
    }]
}

module "infra-start-daily" {
  source                         = "../../"
  name                           = "start-ec2-bastion"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 07 ? * MON-SUN *)" # UTC
  schedule_action                = "start"

  spot_schedule                  = true
  ec2_schedule                   = false
  rds_schedule                   = false
  autoscaling_schedule           = false
  cloudwatch_alarm_schedule      = false

  resource_tags = [
    {
      Key = "ToStop"
      Value = "true"
    },
    {
      Key = "Environment"
      Value = "test"
    }]
}
