try {
  var e = require('connect');
} catch (e) {
  console.error('You should install connect first.');
  console.info('npm -g install connect --production')
  return;
}
var app = e.createServer();
var cfg = require('./cfg.js');
var path = require('path');

var oneDay = 24 * 60 * 60 * 1000;
var dir = cfg.static_root || path.join(__dirname, '../static');
var doc = path.join(__dirname, '../doc');

app.use(e.favicon());

app.use('/doc', require('./compiler.js')({
  src:doc,
  enable:['marked', 'stylus']
}));
app.use('/doc', e.static(doc, {
  maxAge:oneDay * 1
}));
app.use('/doc', e.directory(doc, {
  icons:true
}));
app.use(cfg.file_mount_point, e.static(dir, {
  maxAge:oneDay * 1,
  redirect:false
}));

/* by default, not expose directory structure for end users
 app.use(cfg.file_mount_point, e.directory(dir, {
 icons: true
 }));
 */

app.use(cfg.plsql_mount_point || '/', require('./psp.web.js'));

console.log('usage: node combined_server <oracle_port> <client_port> <client_port_ssl>');
console.log('This is combined/integrated server (service both dynamic PL/SQL page and static file) ')

var http_port = process.argv[3] || cfg.http_port;
var https_port = process.argv[4] || cfg.https_port;

require('http').createServer(app).listen(http_port,
  function(){
    console.log('PSP.WEB server is listening at http port ' + http_port);
  });

if (!https_port || !cfg.ssl_key || !cfg.ssl_cert) return;
var options = {
  key:cfg.ssl_key,
  cert:cfg.ssl_cert
};

require('https').createServer(options, app).listen(https_port,
  function(){
    console.log('PSP.WEB server is listening at https port ' + https_port);
  });


