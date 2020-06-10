const AWS = require('aws-sdk');
const Utils = require('utils');

class RdsScheduler {

  constructor(awsRegion) {
    if (awsRegion) {
      AWS.config.update({ region: awsRegion });
    }
    this.rds = new AWS.RDS();
  }

  async run(action, resourceTags, callback) {
    if (!resourceTags) {
      throw new Error('Resource tags must be specified otherwise you will shoutdown all instances');
    }

    let rdsData = await this.rds.describeDBInstances().promise();
    for (let dbInstance of rdsData.DBInstances) {
      try {
        let rdsTagParams = {
          ResourceName: dbInstance.DBInstanceArn
        };
        let tagData = await this.rds.listTagsForResource(rdsTagParams).promise();
        let tags = tagData.TagList || [];

        if (Utils.matchTags(tags, resourceTags)) {
          let data = await this[action](dbInstance.DBInstanceIdentifier);
          //callback(null, data);

          console.log(`${Utils.ucFirst(action)} RDS instance ${dbInstance.DBInstanceIdentifier}`);
        }
      } catch (e) {
        //callback(e, null);
        console.error(e.stack);
      }
    }
  }

  /**
   * Stop RDS instance by identifier
   *
   * @param instanceIdentifier
   * @returns {Promise<*>}
   */
  async stop(instanceIdentifier) {
    let shutdownParams = {
      DBInstanceIdentifier: instanceIdentifier
    };

    return await this.rds.stopDBInstance(shutdownParams).promise();
  }

  /**
   * Start RDS instance by identifier
   *
   * @param instanceIdentifier
   * @returns {Promise<*>}
   */
  async start(instanceIdentifier) {
    let startParams = {
      DBInstanceIdentifier: instanceIdentifier
    };

    return await this.rds.startDBInstance(startParams).promise();
  }
}

module.exports = RdsScheduler;
