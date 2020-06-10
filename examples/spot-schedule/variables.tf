variable "profile" {
  description = "Custom profile name setuped in ~/.aws/credentials"
  type        = string
}

variable "ec2_key" {
  description = "SSH keypair name. A file must be with *.pem extension"
  type        = string
}
