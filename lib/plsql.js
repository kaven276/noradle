var pspdweb = require('./psp.web.js');
var cfg = require('./cfg');

console.log('usage: node psp.web <oracle_port> <client_port> <client_port_ssl>');

var http_port = process.argv[3] || cfg.http_port;
var https_port = process.argv[4] || cfg.https_port;

require('http').createServer(pspdweb).listen(http_port,
  function(){
    console.log('PSP.WEB server is listening at http port ' + http_port);
  });

if (!cfg.ssl_key || !cfg.ssl_cert) return;
var options = {
  key:cfg.ssl_key,
  cert:cfg.ssl_cert
};

require('https').createServer(options, pspdweb).listen(https_port,
  function(){
    console.log('PSP.WEB server is listening at https port ' + https_port);
  });