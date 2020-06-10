const AWS = require('aws-sdk');
const Utils = require('utils');

class AutoScalingScheduler {

  constructor(awsRegion = null) {
    if (awsRegion) {
      AWS.config.update({ region: awsRegion });
    }
    this.ec2 = new AWS.EC2();
    this.autoScaling = new AWS.AutoScaling();
  }

  /**
   * Aws autoscaling suspend function.
   *
   * Suspend autoscaling group and stop its instances with defined tag.
   *
   * @param {String} action Perform an action name
   * @param {Array} resourceTags "{tag:value}" pairs to use for filter resources
   * @param callback
   * @returns {Promise<void>}
   */
  async run(action, resourceTags, callback) {
    if (!resourceTags) {
      throw new Error('"resourceTags" must be specified, otherwise you will shoutdown all instances');
    }

    try {
      let asgData = await this.autoScaling.describeAutoScalingGroups().promise();
      for (const asg of asgData.AutoScalingGroups) {
        if (asg.Tags.length && Utils.matchTags(resourceTags, asg.Tags)) {
          let data = await this[action](asg);
          //callback(null, data);
        }
      }
    } catch (e) {
      //callback(e, null);
      console.error(e.stack);
    }
  }

  /**
   * Stop AutoScalingGroup
   *
   * @param {JSON} asg AutoScalingGroup object gotten from AWS SDK
   * @returns {JSON}
   */
  async stop(asg) {
    let params = {
      AutoScalingGroupName: asg.AutoScalingGroupName,
    };
    let data = await this.autoScaling.suspendProcesses(params).promise();
    console.log(`Suspend AutoScaling group ${asg.AutoScalingGroupName}`, JSON.stringify(data));

    //let instanceIds = asg.Instances.forEach((instance) => { instance.InstanceId });

    for (const instance of asg.Instances) {
      let params = {
        InstanceIds: [instance.InstanceId],
        //DryRun: true
      };

      let data = [];
      try {
        try {
          // Try to stop EC2 instances
          data = await this.ec2.stopInstances(params).promise();
        } catch (e) {
          // Otherwise try to terminate it (in most cases for EC2 Spot instances)
          data = await this.ec2.terminateInstances(params).promise();
        }
        console.log(`Stop EC2 instance ${instance.InstanceId}`, JSON.stringify(data));
      } catch (e) {
        console.error(e.stack);
      }
    }
  }

  /**
   * Start AutoScalingGroup
   *
   * @param {JSON} asg AutoScalingGroup object gotten from AWS SDK
   * @returns {JSON}
   */
  async start(asg) {
    let params = {
      AutoScalingGroupName: asg.AutoScalingGroupName,
    };
    let data = await this.autoScaling.resumeProcesses(params).promise();

    console.log(`Resume AutoScaling group ${asg.AutoScalingGroupName}`, JSON.stringify(data));

    for (const instance of asg.Instances) {
      let params = {
        InstanceIds: [instance.InstanceId],
        //DryRun: true
      };
      // @todo Start only instances which can be started: "Values": ["pending", "stopping", "stopped"],
      let data = await this.ec2.startInstances(params).promise();

      console.log(`Stop EC2 instance ${instance.InstanceId}`, JSON.stringify(data));
    }
    return data;
  }
}

module.exports = AutoScalingScheduler;
