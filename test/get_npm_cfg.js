/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 13-4-1
 * Time: 下午4:55
 */

module.exports = (function get_npm_cfg(){
  var cfg = {}
    , env = process.env
    ;

  for (var k in env) {
    if (k.match(/^npm_config_noradle_.*/))
      cfg[k.substr(19)] = env[k];
  }
  console.log('custom configuration is as below:');
  console.log(cfg);
  console.log();
  return cfg;
})();
