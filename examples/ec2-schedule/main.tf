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

# Create VPC use by EC2
resource "aws_vpc" "network" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "dev-env"
  }
}

# Attach public IP to EC2
resource "aws_eip" "ip" {
  instance = aws_instance.ec2.id
  vpc = true
}

# Create subnet use by EC2
resource "aws_subnet" "public-subnet" {
  cidr_block = cidrsubnet(aws_vpc.network.cidr_block, 3, 1)
  vpc_id = aws_vpc.network.id
  availability_zone = "eu-central-1a"
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
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.route-table-dev-env.id
}

resource "aws_internet_gateway" "gw-dev-env" {
  vpc_id = aws_vpc.network.id
  tags = {
    Name = "dev-env-gw"
  }
}

# Our default security group to access the instances over SSH
resource "aws_security_group" "ingress-all" {
  name = "allow-ssh-sg"
  vpc_id = aws_vpc.network.id

  # SSH access from anywhere
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  # Outbound internet access.
  # Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Automatically find out the most resent AMI
data "aws_ami" "ec2-ami" {
  most_recent = true
  owners = ["137112412989"]

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2",]
  }
}

# EC2 host
resource "aws_instance" "ec2" {
  ami = data.aws_ami.ec2-ami.id
  instance_type = "t3a.nano"
  key_name = var.ec2_key
  security_groups = [aws_security_group.ingress-all.id]

  tags = {
    Name = "ec2-instance"
    Environment = "test"
    ToStop = "true"
  }

  subnet_id = aws_subnet.public-subnet.id
}

# Terraform Lambda Scheduler Module
module "infra-stop-nightly" {
  source                         = "../../"
  name                           = "stop-ec2-bastion"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 17 ? * MON-SUN *)" # UTC
  schedule_action                = "stop"

  spot_schedule                  = false
  ec2_schedule                   = true
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

module "infra-start-daily" {
  source                         = "../../"
  name                           = "start-ec2-bastion"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 07 ? * MON-SUN *)" # UTC
  schedule_action                = "start"

  spot_schedule                  = false
  ec2_schedule                   = true
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
