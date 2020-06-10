class Utils {

  /**
   * Filter and compare tags which we got from AWS resource (RDS Instance, EC2, AutoScaling etc.)
   * with tags witch we pass from Lambda configuration.
   *
   * AWS resource must include all tags which were passed from configuration,
   * otherwise action won't dispatch.
   *
   * @param {Array} resourceTags Lambda configuration tags
   * @param {Array} instanceTags AWS instance tags
   */
  static matchTags(instanceTags, resourceTags) {
    let matched = false;
    resourceTags.forEach((resourceTag, i) => {
      instanceTags.forEach((tag) => {
        if (tag.Key === resourceTag.Key) {
          if (0 === i) {
            matched = true;
          }
          matched = (tag.Value === resourceTag.Value) ? (matched && true) : (matched && false)
        }
      });
    });

    return matched;
  }

  static ucFirst(string) {
    return string[0].toUpperCase() + string.slice(1);
  }
}

module.exports = Utils;
