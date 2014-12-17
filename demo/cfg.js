/**
 * Created by cuccpkfs on 14-12-17.
 */

var path = require('path')
  ;

module.exports = {
  http_port : 8522,
  oracle_port : 1522,
  oracle_keep_alive : 60,
  demo_dbu : 'demo1',
  static_url : '/',
  static_root : path.join(__dirname, '../static/demo'),
  upload_dir : __dirname + '/upload'
}