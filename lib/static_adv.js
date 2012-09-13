module.exports = function(setting){

  require('./util.js').override2(require('./cfg.js'), setting);

  var common = require('./common.js')
    , app = require('connect').createServer()
    ;

  common.mount_doc(app);
  common.mount_static(app);
  common.start_static(app);
};
