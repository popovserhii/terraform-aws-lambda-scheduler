// Great tutorial how to use Sinon @link https://semaphoreci.com/community/tutorials/best-practices-for-spies-stubs-and-mocks-in-sinon-js
// Use sinon assertions and matchers where it is possible https://sinonjs.org/releases/v9.0.2/matchers/
require('app-module-path').addPath(process.cwd() + '/src');

const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const chai = require('chai');
const sinon = require('sinon');
const AutoScalingScheduler = require('autoscaling-scheduler');

describe('AWS AutoScaling Group Lambda Scheduler', () => {
  let consoleLogStub = null;
  beforeEach(() => {
    AWSMock.setSDKInstance(AWS);
    // Ignore console.log() output
    consoleLogStub = sinon.stub(console, 'log');
  });

  afterEach(() => {
    AWSMock.restore();
    consoleLogStub.restore();
  });

  [
    { action: 'stop', method: 'stopInstances', processMethod: 'suspendProcesses', responseKey: 'StoppingInstances' },
    { action: 'start', method: 'startInstances', processMethod: 'resumeProcesses', responseKey: 'StartingInstances' },
  ].forEach(function (run) {
    it(`run: "${run.method}" should be called once`, async () => {
      let tags = [{ "Key": "ToStop", "Value": "true" }, { "Key": "Environment", "Value": "test" }];

      // Important creating the spy/sub in such way, because there are several calls to AWS under the hood
      let actionInstancesSpy = sinon.spy((params, callback) => {
        callback(null, { [run.responseKey]: [{ InstanceId: "TEST-EC2-ID-123" }] });
      })

      // Mock successful execution
      AWSMock.mock('EC2', run.method, actionInstancesSpy);

      AWSMock.mock('AutoScaling', 'describeAutoScalingGroups', async (callback) => {
        callback(null, { AutoScalingGroups: [
          {
            Tags: tags,
            AutoScalingGroupName: "TEST-AUTO-SCALING-GROUP-NAME",
            Instances: [{ InstanceId: "TEST-EC2-ID-123" }]
          }
        ]});
      });
      AWSMock.mock('AutoScaling', run.processMethod, async (params, callback) => {
        callback(null, { });
      });

      let spotScheduler = new AutoScalingScheduler('eu-central-1');
      await spotScheduler.run(run.action, tags);

      // Assert on your Sinon spy as normal
      sinon.assert.calledOnce(actionInstancesSpy);
      sinon.assert.calledWith(actionInstancesSpy, { InstanceIds: ['TEST-EC2-ID-123'] });
    });
  });

  it(`stop: "terminateInstances should be called if stopInstances throw Error`, async () => {
    // Important creating the spy/sub in such way, because there are several calls to AWS under the hood
    let stopInstancesSpy = sinon.spy((params, callback) => {
      throw Error();
    });
    AWSMock.mock('EC2', 'stopInstances', stopInstancesSpy);

    let terminateInstancesSpy = sinon.spy((params, callback) => {
      callback(null, { 'TerminateInstances': [{ InstanceId: "TEST-EC2-ID-123" }] });
    })
    AWSMock.mock('EC2', 'terminateInstances', terminateInstancesSpy);

    AWSMock.mock('AutoScaling', 'suspendProcesses', async (params, callback) => {
      callback(null, { });
    });

    let spotScheduler = new AutoScalingScheduler('eu-central-1');
    await spotScheduler.stop({
      AutoScalingGroupName: "TEST-AUTO-SCALING-GROUP-NAME",
      Instances: [{ InstanceId: "TEST-EC2-ID-123" }]
    });

    // Assert on your Sinon spy as normal
    sinon.assert.threw(stopInstancesSpy);
    sinon.assert.calledWith(terminateInstancesSpy, { InstanceIds: ['TEST-EC2-ID-123'] });
  });
});
