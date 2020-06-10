/**
 * Main function entry-point for lambda.
 *
 * Stop and start AWS resources:
 *  - rds instances
 *  - rds aurora clusters
 *  - instance ec2
 *
 *  Suspend and resume AWS resources:
 *  - ec2 autoscaling groups
 *
 * Terminate spot instances (spot instance cannot be stopped by a user).
 *
 * @link https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html
 *
 * @param event
 * @param context
 * @param callback Callback, is a function that you can call in non-async handlers to send a response.
 *                 The callback function takes two arguments: an Error and a response.
 *                 When you call it, Lambda waits for the event loop to be empty
 *                 and then returns the response or error to the invoker.
 *                 The response object must be compatible with JSON.stringify.
 */
exports.handler = (event, context, callback) => {
  const strategy = {};

  // Retrieve  variables from aws lambda ENVIRONMENT
  const scheduleAction = process.env.SCHEDULE_ACTION;
  const awsRegions = process.env.AWS_REGIONS.replace(' ', '').split(',');
  const resourceTags = JSON.parse(process.env.RESOURCE_TAGS);

  strategy['autoscaling-scheduler'] = process.env.AUTOSCALING_SCHEDULE;
  strategy['spot-scheduler'] = process.env.SPOT_SCHEDULE;
  strategy['ec2-scheduler'] = process.env.EC2_SCHEDULE;
  strategy['rds-scheduler'] = process.env.RDS_SCHEDULE;
  //strategy['CloudWatchAlarmScheduler'] = process.env.CLOUDWATCH_ALARM_SCHEDULE;

  for (const serviceName in strategy) {
    let toSchedule = strategy[serviceName];
    if (toSchedule === 'true') {
      for (const awsRegion of awsRegions) {
        let Service = require(serviceName);
        let service = new Service(awsRegion);
        service.run(scheduleAction, resourceTags);
      }
    }
  }
};
