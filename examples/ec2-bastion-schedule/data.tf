data "aws_ami" "bastion" {
  most_recent = true
  owners = ["137112412989"]

  filter {
    name = "name"

    values = ["amzn2-ami-hvm-*-x86_64-gp2",]
  }
}

data "aws_security_group" "bastion" {
  vpc_id = aws_vpc.this.id
  name = module.ssh_sg.this_security_group_name
}
