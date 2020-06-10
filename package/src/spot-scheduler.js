const AWS = require('aws-sdk');
const Utils = require('utils');

class SpotScheduler {

  constructor(awsRegion = null) {
    if (awsRegion) {
      AWS.config.update({ region: awsRegion });
    }
    this.ec2 = new AWS.EC2();
    this.autoScaling = new AWS.AutoScaling();
  }

  /**
   * AWS EC2 instance performing operation function.
   *
   * Operate EC2 instances with defined tag and disable its CloudWatch alarms.
   *
   * @param action String
   * @param resourceTags Array {key:value} pairs to use for filter resources
   * @returns {Promise<void>}
   */
  async run(action, resourceTags) {
    if (!resourceTags) {
      throw new Error('Resource tags must be specified otherwise you will shoutdown all instances');
    }

    let params = {
      //DryRun: false
      Filters: [{
        "Name": "state",
        "Values": ["open", "active", "disabled"],
      }]
    };

    resourceTags.forEach((resourceTag) => {
      params.Filters.push({ "Name": "tag:" + resourceTag.Key, "Values": [resourceTag.Value] })
    });

      // Call EC2 to retrieve policy for selected bucket
      let response = await this.ec2.describeSpotInstanceRequests(params).promise();
      for (let request of response.SpotInstanceRequests) {
        try {
          let asParams = {
            InstanceIds: [request.InstanceId]
          };
          let autoScaling = await this.autoScaling.describeAutoScalingInstances(asParams).promise();
          if (!autoScaling.AutoScalingInstances.length) {
            let data = await this[action](request);

            console.log(`${Utils.ucFirst(action)} EC2 Spot instance ${request.InstanceId}`, JSON.stringify(data));
          }
        } catch (e) {
          //callback(e, null);
          console.error(e.stack);
        }
      }
  }

  /**
   * Stop EC2 Spot instance
   *
   * @param request
   * @returns {Promise<*>}
   */
  async stop(request) {
    let params = {
      InstanceIds: [request.InstanceId],
      //DryRun: true
    };

    let data = {
      SpotInstanceRequests: [
        {
          CreateTime: '<Date Representation>',
          InstanceId: "i-1234567890abcdef0",
          LaunchSpecification: {
            BlockDeviceMappings: [
              {
                DeviceName: "/dev/sda1",
                Ebs: {
                  DeleteOnTermination: true,
                  VolumeSize: 8,
                  VolumeType: "standard"
                }
              }
            ],
            EbsOptimized: false,
            ImageId: "ami-7aba833f",
            InstanceType: "m1.small",
            KeyName: "my-key-pair",
            SecurityGroups: [
              {
                GroupId: "sg-e38f24a7",
                GroupName: "my-security-group"
              }
            ]
          },
          LaunchedAvailabilityZone: "us-west-1b",
          ProductDescription: "Linux/UNIX",
          SpotInstanceRequestId: "sir-08b93456",
          SpotPrice: "0.010000",
          State: "active",
          Status: {
            Code: "fulfilled",
            Message: "Your Spot request is fulfilled.",
            UpdateTime: '<Date Representation>'
          },
          Type: "one-time"
        }
      ]
    }

    return (request.Type === 'persistent')
      ? await this.ec2.stopInstances(params).promise()
      : await this.ec2.terminateInstances(params).promise();
  }

  /**
   * Start EC2 Spot instance
   *
   * @param request
   * @returns {Promise<*>}
   */
  async start(request) {
    let params = {
      InstanceIds: [request.InstanceId],
      //DryRun: true
    };
    return await this.ec2.startInstances(params).promise();
  }
}

module.exports = SpotScheduler;
