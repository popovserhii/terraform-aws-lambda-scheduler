# Create AWS region
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

# Create VPC use by EC2
resource "aws_vpc" "network" {
  cidr_block = "10.0.0.0/16"
}

# Create subnet use by EC2
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.network.id
  cidr_block = "10.0.1.0/24"
}

# Next three resources configured traffic to be routed into VPC,
# otherwise you get `request timed out`.
resource "aws_route_table" "route-table-dev-env" {
  vpc_id = aws_vpc.network.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw-dev-env.id
  }
  tags = {
    Name = "dev-env-route-table"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route-table-dev-env.id
}

resource "aws_internet_gateway" "gw-dev-env" {
  vpc_id = aws_vpc.network.id
  tags = {
    Name = "dev-env-gw"
  }
}

# Create EC2 Spot instance
resource "aws_spot_instance_request" "bastion" {
  ami                    = data.aws_ami.bastion.id
  #spot_price             = var.spot_price
  instance_type          = "t3a.nano"
  spot_type              = "persistent"
  wait_for_fulfillment   = true
  key_name               = var.ec2_key
  vpc_security_group_ids      = [data.aws_security_group.bastion.id]
  subnet_id = aws_subnet.public.id

  tags = {
    Name = "spot-bastion"
    Environment = "dev"
    ToStop = "true"
  }

  # Apply tags to Spot Instance
  provisioner "local-exec" {
    command = join("", formatlist("aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=\"%s\",Value=\"%s\" --profile terraform; ", keys(self.tags), values(self.tags)))
  }

  # Aplly tags to Instance Volume
  provisioner "local-exec" {
    command = "for eachVolume in `aws ec2 describe-volumes --profile terraform --filters Name=attachment.instance-id,Values=${self.spot_instance_id} | jq -r .Volumes[].VolumeId`; do ${join("", formatlist("aws ec2 create-tags --resources $eachVolume --tags Key=\"%s\",Value=\"%s\" --profile terraform;", keys(self.tags), values(self.tags)))} done;"
  }
}

# Terraform Lambda Scheduler Module
module "infra-stop-nightly" {
  source                         = "../../"
  name                           = "stop-spot-bastion"
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
  name                           = "start-spot-bastion"
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
