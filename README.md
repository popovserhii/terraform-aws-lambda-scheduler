# Terraform AWS Lambda Scheduler

Terraform module which allow to **stop** and **start** EC2 instances, RDS resources and AutoScaling Groups 
by a schedule with Lambda function.

## Summary

  - [Features](#features)
  - [Getting Started](#getting-started)
      - [As Terraform module](#as-terraform-module)
      - [For developer](#for-developer)
  - [Running the tests](#running-the-tests)
  - [Versioning](#versioning)
  - [License](#license)
  - [Acknowledgments](#acknowledgments)

## Features

  - [x] Terraform 0.12 code style
  - [x] AWS Lambda in a pure Node.js 12
  - [x] EC2 instances scheduling
  - [x] EC2 Spot instances scheduling
  - [x] RDS instances scheduling
  - [x] AutoScaling Group scheduling
  - [x] AWS CloudWatch logs for Lambda
  - [x] Multi AWS tags support
  - [ ] Pagination for more than 50 items
  - [ ] RDS clusters scheduling
  - [ ] CloudWatch Alarm scheduling

### Caveats

Spot instances have slightly different [running/stopping](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-requests.html#stopping-a-spot-instance) process on AWS, so we need consider in separately.

#### Limitations

- Amazon EC2 Spot instances **can** now be [stopped and started](https://aws.amazon.com/about-aws/whats-new/2020/01/amazon-ec2-spot-instances-stopped-started-similar-to-on-demand-instances/) similar to On-Demand instances.
  This feature is only available for instances with an Amazon EBS volume as their root device. 
- AWS can **stop** instance if it has been run with `persistance` request, otherwise we can only terminate it.
- AWS **can't stop** a Spot Instance if it is part of a fleet or launch group, Availability Zone group, or Spot block. 
  You can only **terminate** them.  
- The **stop** feature is available for **persistent** Spot requests and Spot Fleets with the **maintain** fleet option enabled. 
  You will not be charged for instance usage while your instance is stopped.

## Getting Started

### As Terraform module
Copy and paste into your Terraform configuration, insert the variables, 
and run `terraform init`:

```hcl-terraform
module "infra-stop-nightly" {
  source                         = "popov/aws-lambda-scheduler"
  name                           = "${terraform.workspace}-stop-infra"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 17 ? * MON-SUN *)" # UTC
  schedule_action                = "stop"

  spot_schedule                  = true
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
      Value = terraform.workspace
    }
  ]
} 

module "infra-start-daily" {
  source                         = "popov/aws-lambda-scheduler"
  name                           = "${terraform.workspace}-stop-infra"
  aws_regions                    = ["eu-central-1"]

  cloudwatch_schedule_expression = "cron(0 07 ? * MON-FRI *)" # UTC
  schedule_action                = "start"

  spot_schedule                  = true
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
      Value = terraform.workspace
    }
  ]
}
```

#### Example

> NOTE: All examples stop every day from Monday to Friday at 17:00 UTC and start every day from Monday to Friday at 07:00 UTC
>
* [AutoScaling scheduler](examples/autoscaling-schedule) - Create lambda functions to suspend autoscaling group 
with `ToStop = true` and ` TestTag = <radom_value>` tags and terminate its EC2 instances.
* [Spot scheduler](examples/spot-schedule) - Create lambda functions to stop Spot instance with `ToStop = true` and `Environment = test` tags.
* [EC2 scheduler](examples/ec2-schedule) - Create lambda functions to stop EC2 with `ToStop = true` and `Environment = test` tags.
* [EC2 Bastion scheduler](examples/ec2-bastion-schedule) - Create lambda functions to stop EC2 Bastion host with `ToStop = true` and `Environment = test` tags.
* [RDS MariaDB scheduler](examples/rds-schedule) - Create lambda functions to stop RDS MariaDB with `ToStop = true` tag.

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Define name to use for lambda function, cloudwatch event and iam role | string | n/a | yes |
| custom_iam_role_arn | Custom IAM role arn for the scheduling lambda | string | null | no |
| kms_key_arn | The ARN for the KMS encryption key. If this configuration is not provided when environment variables are in use, AWS Lambda uses a default service key | string | null | no |
| aws_regions | A list of one or more aws regions where the lambda will be apply, default use the current region | list | null | no |
| cloudwatch_schedule_expression | The scheduling expression | string | `"cron(0 22 ? * MON-FRI *)"` | yes |
| schedule_action | Define schedule action to apply on resources | string | `"stop"` | yes |
| autoscaling_schedule | Enable scheduling on autoscaling resources | string | `"false"` | no |
| spot_schedule | Enable scheduling on spot instance resources | string | `"false"` | no |
| ec2_schedule | Enable scheduling on EC2 instance resources | string | `"false"` | no |
| rds_schedule | Enable scheduling on RDS resources | string | `"false"` | no |
| cloudwatch_alarm_schedule | Enable scheduleding on cloudwatch alarm resources | string | `"false"` | no |
| resource_tags | Set the tags use for identify resources to stop or start | map | { ToStop = "true" } | yes |

#### Outputs

| Name | Description |
|------|-------------|
| lambda_iam_role_arn | The ARN of the IAM role used by Lambda function |
| lambda_iam_role_name | The name of the IAM role used by Lambda function |
| scheduler_lambda_arn | The ARN of the Lambda function |
| scheduler_lambda_name | The name of the Lambda function |
| scheduler_lambda_invoke_arn | The ARN to be used for invoking Lambda function from API Gateway |
| scheduler_lambda_function_last_modified | The date Lambda function was last modified |
| scheduler_lambda_function_version | Latest published version of your Lambda function |
| scheduler_log_group_name | The name of the scheduler log group |
| scheduler_log_group_arn | The Amazon Resource Name (ARN) specifying the log group |


### For developer

These instructions will get you a copy of the project up and running on
your local machine for development and testing purposes.

#### Prerequisites

Clone the source locally:
```bash
$ git clone https://github.com/popovserhii/terraform-aws-lambda-scheduler
$ cd terraform-aws-lambda-scheduler
```

If you're on Debian or Ubuntu or Mint, you'll need to install NodeJS version not less 13:

Use your package manager to install NPM and NodeJS.

```bash
$ curl -sL https://deb.nodesource.com/setup_13.x | sudo bash -
$ sudo apt-get install -y npm nodejs
```

Install project dependencies:
```bash
$ npm install
```

## Running the tests

At that moment only Unit tests are implemented, so you can run the tests as much as you need 
without bother that some resources will be  created on AWS. 

### Unit tests

Unit tests are using:
  - [Mocha](https://mochajs.org/) as JavaScript test framework
  - [Sinon](https://sinonjs.org/) for test spies, stubs and mocks
  - [Chai](https://www.chaijs.com/) as a BDD/TDD assertion library
  - [AWSomocks](https://github.com/dwyl/aws-sdk-mock) as mocks for Javascript AWS-SDK services
  
Run the tests with:
```bash
$ npm test
```

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/popovserhii/terraform-aws-lambda-scheduler/tags).

## License

This project is licensed under the [MIT](LICENSE.md)

## Acknowledgments

There is a library which does almost the same, but its Lambda functions are written on Python. 
At the moment when I was searching for a Terraform module to stop and run my infrastructure, 
it didn't work correctly with Spot Instances, so there was a dilemma to write an issue 
and wait till the maintainer fix it, or implement it by myself. The result you can see in this repository. 

As I know NodeJS it was easier for me to rewrite it and improve missing parts. 

Many thanks to the author who implemented this on Python for inspiration. 
