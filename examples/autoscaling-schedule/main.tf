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

# Terraform autoscaling group with lambda scheduler
data "aws_ami" "ami" {
  most_recent = true
  owners = ["137112412989"]

  filter {
    name = "name"

    values = ["amzn2-ami-hvm-*-x86_64-gp2",]
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_launch_configuration" "launch" {
  name          = "web_config"
  image_id      = data.aws_ami.ami.id
  instance_type = "t3a.nano"
}

# Create autoscaling group with tag
resource "aws_autoscaling_group" "scheduled" {
  count                     = 3
  name                      = "bar-with-tag-${count.index}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch.name
  vpc_zone_identifier       = [aws_subnet.subnet.id]

  tags = [
    {
      key                 = "ToStop"
      value               = "true"
      propagate_at_launch = true
    },
    {
      key                 = "TestTag"
      value               = random_pet.random-tag.id
      propagate_at_launch = true
    },
  ]
}

# Create autoscaling group without tag
resource "aws_autoscaling_group" "not_scheduled" {
  count                     = 2
  name                      = "foo-without-tag-${count.index}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch.name
  vpc_zone_identifier       = [aws_subnet.subnet.id]

  tags = [
    {
      key                 = "ToStop"
      value               = "false"
      propagate_at_launch = true
    },
    {
      key                 = "TestTag"
      value               = random_pet.random-tag.id
      propagate_at_launch = true
    },
  ]
}

# Terraform Lambda Scheduler Module
module "infra-stop-nightly" {
  source                         = "../../"
  name                           = "stop-autoscaling"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 17 ? * MON-SUN *)" # UTC
  schedule_action                = "stop"

  spot_schedule                  = false
  ec2_schedule                   = false
  rds_schedule                   = false
  autoscaling_schedule           = true
  cloudwatch_alarm_schedule      = false

  resource_tags = [
    {
      Key = "ToStop"
      Value = "true"
    },
    {
      Key = "TestTag"
      Value = random_pet.random-tag.id
    }
  ]
}

module "infra-start-daily" {
  source                         = "../../"
  name                           = "start-autoscaling"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 07 ? * MON-SUN *)" # UTC
  schedule_action                = "start"

  spot_schedule                  = false
  ec2_schedule                   = false
  rds_schedule                   = false
  autoscaling_schedule           = true
  cloudwatch_alarm_schedule      = false

  resource_tags = [
    {
      Key = "ToStop"
      Value = "true"
    },
    {
      Key = "TestTag"
      Value = random_pet.random-tag.id
    }
  ]
}
