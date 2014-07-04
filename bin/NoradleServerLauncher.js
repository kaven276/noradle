var spawn = require('child_process').spawn;

try {
  var setting = require(process.argv[2]);
} catch (e) {
  // console.error(e);
  console.log('usage: node SPLancher.js path_to_the_setting_file');
  console.log('setting file content like:');
  console.log(" module.exports = { 'user/pass@connid' : { 'server_config_t.cfg_id' : number_of_servers } };");
  process.exit(1);
}

var oper = process.argv[3] || 'start';

function startServer(connStr, cfg, slot){
  var sqlplus = spawn('sqlplus', [connStr])
    , sql = "exec gateway.listen('" + cfg + "'," + slot + ")"
    , lastData
    ;

  sqlplus.stdin.write('SET SERVEROUTPUT ON\n');
  sqlplus.stdin.write("alter session set NLS_DATE_FORMAT='yyyy-mm-dd hh24:mi:ss';\n");
  sqlplus.stdin.write(sql + '\n');
  sqlplus.stdin.write('exit\n');
  console.log(sql);

  sqlplus.stdout.on('data', function(data){
    var text = data.toString();
    if (text.match(/^Noradle Server Status:\w+/)) {
      lastData = text.split('.')[0].split(':')[1];
    }
  });

  sqlplus.stderr.on('data', function(data){
    // console.error('ps stderr: ' + data.toString());
  });

  sqlplus.on('error', function(e){
    console.error(connstr, cfg, slot, e);
  });

  sqlplus.on('close', function(code){
    console.log('last data', lastData);
    if (lastData === 'restart') {
      console.log('server quit and restarting.', connStr, cfg, slot);
      startServer(connStr, cfg, slot);
    }
    if (code !== 0) {
      console.log('ps process exited with code ' + code);
    }
  });
}

function stopServer(connStr, cfg){
  var sqlplus = spawn('sqlplus', [connStr])
    , sql = "exec kill('" + cfg + "')"
    , lastData
    ;

  sqlplus.stdin.write(sql + '\nexit\n');
  console.log(sql);

  sqlplus.stdout.on('data', function(data){
    ;
  });

  sqlplus.stderr.on('data', function(data){
    ;
  });

  sqlplus.on('close', function(code){
    if (code !== 0) {
      console.log('ps process exited with code ' + code);
    }
  });
}

if (oper === 'start') {
  for (connStr in setting) {
    var cfgs = setting[connStr];
    for (var cfg in cfgs) {
      for (var i = 1; i <= cfgs[cfg]; i++) {
        startServer(connStr, cfg, i);
      }
    }
  }
} else {
  for (connStr in setting) {
    var cfgs = setting[connStr];
    for (var cfg in cfgs) {
      stopServer(connStr, cfg);
    }
  }
}

