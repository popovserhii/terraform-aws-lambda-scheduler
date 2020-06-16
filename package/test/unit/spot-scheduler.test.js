// Great tutorial how to use Sinon @link https://semaphoreci.com/community/tutorials/best-practices-for-spies-stubs-and-mocks-in-sinon-js
// Use sinon assertions and matchers where it is possible https://sinonjs.org/releases/v9.0.2/matchers/
require('app-module-path').addPath(process.cwd() + '/src');

const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const chai = require('chai');
const sinon = require('sinon');
const SpotScheduler = require('spot-scheduler');

let consoleLogStub = null;

describe('AWS EC2 Spot Instances Lambda Scheduler', async () => {
  beforeEach(function() {
    AWSMock.setSDKInstance(AWS);
    consoleLogStub = sinon.stub(console, 'log');
  });

  afterEach(function() {
    AWSMock.restore();

    // Ignore console.log() output
    consoleLogStub.restore();
  });

  [
    { action: 'stop', method: 'stopInstances', type: 'persistent', responseKey: 'StoppingInstances' },
    { action: 'stop', method: 'terminateInstances', type: 'one-time', responseKey: 'StoppingInstances' },
    { action: 'start', method: 'startInstances', type: 'persistent', responseKey: 'StartingInstances' },
  ].forEach(function (run) {
    it(`run: "${run.method}" should be called once if an instance is "${run.type}"`, async () => {
      let tags = [{ "Key": "ToStop", "Value": "true" }, { "Key": "Environment", "Value": "stage" }];

      // Ignore console.log() output
      //let consoleLogSpy = sandbox.stub(console, 'log');
      // Important creating the spy/sub in such way there are several calls to AWS under the hood
      let actionInstancesSpy = sinon.spy((params, callback) => {
        callback(null, { [run.responseKey]: [{ InstanceId: "TEST-SPOT-ID-123" }] });
      })

      // mock successful execution
      AWSMock.mock('EC2', run.method, actionInstancesSpy);

      AWSMock.mock('EC2', 'describeSpotInstanceRequests', async (param, callback) => {
        callback(null, { SpotInstanceRequests: [{ InstanceId: "TEST-SPOT-ID-123", Type: run.type }] });
      });
      AWSMock.mock('AutoScaling', 'describeAutoScalingInstances', async (params, callback) => {
        callback(null, { AutoScalingInstances: [] });
      });

      let spotScheduler = new SpotScheduler('eu-central-1');
      await spotScheduler.run(run.action, tags);

      // Assert on your Sinon spy as normal
      sinon.assert.calledOnce(actionInstancesSpy);
      sinon.assert.calledWith(actionInstancesSpy, { InstanceIds: ['TEST-SPOT-ID-123'] });

      // Important! Restore AWS SDK
      AWSMock.restore('EC2');
      AWSMock.restore('AutoScaling');

      //actionInstancesSpy.restore();
      //consoleLogSpy.restore();
    });
  });
});
