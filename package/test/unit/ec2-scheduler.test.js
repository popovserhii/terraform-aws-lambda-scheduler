// Great tutorial how to use Sinon @link https://semaphoreci.com/community/tutorials/best-practices-for-spies-stubs-and-mocks-in-sinon-js
// Use sinon assertions and matchers where it is possible https://sinonjs.org/releases/v9.0.2/matchers/
require('app-module-path').addPath(process.cwd() + '/src');

const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const chai = require('chai');
const sinon = require('sinon');
const Ec2Scheduler = require('ec2-scheduler');

describe('AWS EC2 Lambda Scheduler', () => {
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
    { action: 'stop', method: 'stopInstances', responseKey: 'StoppingInstances' },
    { action: 'start', method: 'startInstances', responseKey: 'StartingInstances' },
  ].forEach(function (run) {
    it(`run: "${run.method}" should be called once`, async () => {
      let tags = [{ "Key": "ToStop", "Value": "true" }, { "Key": "Environment", "Value": "test" }];

      // Important creating the spy/sub in such way, because there are several calls to AWS under the hood
      let actionInstancesSpy = sinon.spy((params, callback) => {
        callback(null, { [run.responseKey]: [{ InstanceId: "TEST-EC2-ID-123" }] });
      })

      // Mock successful execution
      AWSMock.mock('EC2', run.method, actionInstancesSpy);

      AWSMock.mock('EC2', 'describeInstances', async (params, callback) => {
        callback(null, { Reservations: [
            {
              Instances: [{ InstanceId: "TEST-EC2-ID-123" }]
            }
        ]});
      });

      AWSMock.mock('AutoScaling', 'describeAutoScalingInstances', async (params, callback) => {
        callback(null, { AutoScalingInstances: []});
      });

      let spotScheduler = new Ec2Scheduler('eu-central-1');
      await spotScheduler.run(run.action, tags);

      // Assert on your Sinon spy as normal
      sinon.assert.calledOnce(actionInstancesSpy);
      sinon.assert.calledWith(actionInstancesSpy, { InstanceIds: ['TEST-EC2-ID-123'] });
    });
  });
});
