/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-9-3
 * Time: 下午3:04
 */

var SGIP = require('../../sms/node_sms')
  , SP = SGIP.nodeSP.Class
  ;

exports.sp = new SP('202.99.87.201', 8801, 'dialbook', 'dialbooktest', 8801, '', 'dialbook', 'dialbooktest');