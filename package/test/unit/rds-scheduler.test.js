// Great tutorial how to use Sinon @link https://semaphoreci.com/community/tutorials/best-practices-for-spies-stubs-and-mocks-in-sinon-js
require('app-module-path').addPath(process.cwd() + '/src');

const AWSMock = require('aws-sdk-mock');
const AWS = require('aws-sdk');
const chai = require('chai');
const chaiAsPromised = require("chai-as-promised");
const sinon = require('sinon');
const RdsScheduler = require('rds-scheduler');

chai.use(chaiAsPromised);

let expect = chai.expect;
let assert = chai.assert;

describe('AWS RDS Lambda Scheduler', () => {
  beforeEach(function() {
    AWSMock.setSDKInstance(AWS);
  });

  it('run: resourceTags cannot be empty', async() => {
    let rdsScheduler = new RdsScheduler();

    // You must use "chai-as-promised" to this example works
    return expect(rdsScheduler.run('stop')).to.be.eventually.rejectedWith(Error, 'Resource tags must be');
  });

  it('run: "stop" action should be called once', async() => {
    // Ignore console.log() output
    let consoleLogSpy = sinon.stub(console, 'log');

    let tags = [{ "Key": "ToStop", "Value": "true" }, { "Key": "Environment", "Value": "stage" }];

    AWSMock.mock('RDS', 'describeDBInstances', async (callback) => {
      callback(null, { DBInstances: [{ DBInstanceArn: 'DB-INSTANCE-TEST-ARN', DBInstanceIdentifier: 'DB-INSTANCE-TEST-ID' }] });
    });
    AWSMock.mock('RDS', 'listTagsForResource', async (params, callback) => {
      callback(null, { TagList: tags });
    });

    let rdsScheduler = new RdsScheduler('eu-central-1');
    let stopStub = sinon.stub(rdsScheduler, 'stop');

    await rdsScheduler.run('stop', tags);

    sinon.assert.calledOnce(stopStub);
    sinon.assert.calledWith(stopStub, 'DB-INSTANCE-TEST-ID');

    // Important! Restore AWS SDK
    AWSMock.restore('RDS');
    consoleLogSpy.restore();
  });

  it('run: "stop" action should not be called according to mismatching of tags', async() => {
    let resourceTags = [{ "Key": "ToStop", "Value": "true" }, { "Key": "Environment", "Value": "stage" }];
    let instanceTags = [{ "Key": "Environment", "Value": "stage" }];

    AWSMock.mock('RDS', 'describeDBInstances', async (callback) => {
      callback(null, { DBInstances: [{ DBInstanceArn: 'DB-INSTANCE-TEST-ARN', DBInstanceIdentifier: 'DB-INSTANCE-TEST-ID' }] });
    });
    AWSMock.mock('RDS', 'listTagsForResource', async (params, callback) => {
      callback(null, { TagList: instanceTags });
    });

    let rdsScheduler = new RdsScheduler('eu-central-1');
    let stopStub = sinon.stub(rdsScheduler, 'stop');

    await rdsScheduler.run('stop', resourceTags);

    sinon.assert.notCalled(stopStub);
    //sinon.assert.calledWith(stopStub, 'DB-INSTANCE-TEST-ID');

    // Important! Restore AWS SDK
    AWSMock.restore('RDS');
  });

  it('stop: should stop instance by certain ID', async() => {
    // Ignore console.log() output
    let consoleLogSpy = sinon.stub(console, 'log');

    let stopDBInstanceSpy = sinon.spy((params, callback) => {
      callback(null, { 'StoppingInstances': [{ DBInstanceIdentifier: "TEST-RDS-ID-123" }] });
    })

    // Important! Prepare AWS SDK Mock
    AWSMock.mock('RDS', 'stopDBInstance', stopDBInstanceSpy);


    let expectedParams = {
      DBInstanceIdentifier: 'TEST-RDS-ID-123'
    };

    // Object under test
    let rdsScheduler = new RdsScheduler();
    await rdsScheduler.stop('TEST-RDS-ID-123');

    // Assert on your Sinon spy as normal
    assert.isTrue(stopDBInstanceSpy.calledOnce, 'should stop RDS via AWS SDK');
    assert.isTrue(stopDBInstanceSpy.calledWith(expectedParams), 'should pass correct parameters');
    // Expect passed JSON parameters have required 'DBInstanceIdentifier' property
    expect(stopDBInstanceSpy.getCall(0).args[0]).to.have.property('DBInstanceIdentifier');

    // Important! Restore AWS SDK
    AWSMock.restore('RDS');

    consoleLogSpy.restore();
  });

});
