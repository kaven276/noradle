var cfg = require('./cfg.js')
  , http_port = process.argv[3] || cfg.http_port
  , https_port = process.argv[4] || cfg.https_port
  , c
  , mon = require('./monitor.js')
  , ports = mon.ports
  , servers = mon.servers
  ;

if (process.argv[1] !== require('path').join(__dirname, 'plsql.js')) {
  try {
    c = require('connect');
  } catch (e) {
    console.error('You should install connect first. Or run plsql.js for dynamic page only.');
    console.info('npm -g install connect --production');
    process.exit(1);
  }
}

exports.start_dynamic = function(handler){
  servers.http = require('http').createServer(handler)
    .listen(http_port, function(){
      console.log('PSP.WEB server is listening at http port ' + http_port);
    })
    .on('clientError', function(){
      console.warn('client error occurred ！');
    });
  ports.http = http_port;

  if (!https_port || !cfg.ssl_key || !cfg.ssl_cert) return;

  var options = {
    key : cfg.ssl_key,
    cert : cfg.ssl_cert
  };

  servers.https = require('https').createServer(options, handler).listen(https_port, function(){
    console.log('PSP.WEB server is listening at https port ' + https_port);
  });
  ports.https = https_port;
};

exports.start_static = function(app){
  var port = process.argv[2] || 8000;
  app.use(c.favicon(cfg.favicon_path, {maxAge : cfg.favicon_max_age}));
  app.listen(port, function(){
    console.log("static server is listening at port " + port);
  });
  ports.static = port;
}

exports.mount_doc = function(app){

  app.use('/doc', require('./compiler.js')({
    src : cfg.docDir,
    enable : ['marked', 'stylus']
  }));
  app.use('/doc', c.static(cfg.docDir, {
    maxAge : cfg.oneDay * 1
  }));
  app.use('/doc', c.directory(cfg.docDir, {
    icons : true
  }));

}

exports.mount_static = function(app){

  app.use('/demo', c.static(cfg.demoDir, {
    maxAge : cfg.oneDay * 1,
    redirect : false
  }));
  if (cfg.show_dir) {
    app.use('/demo', c.directory(cfg.demoDir, {
      maxAge : cfg.oneDay,
      icons : true
    }));
  }

  app.use('/psp', c.static(cfg.pspDir, {
    maxAge : cfg.oneDay * 1,
    redirect : false
  }));
  if (cfg.show_dir) {
    app.use('/psp', c.directory(cfg.pspDir, {
      maxAge : cfg.oneDay,
      icons : true
    }));
  }

  app.use('/', c.static(cfg.static_root, {
    maxAge : cfg.oneDay * 1,
    redirect : false
  }));
  if (cfg.show_dir) {
    app.use(c.directory(cfg.static_root, {
      maxAge : cfg.oneDay,
      icons : true
    }));
  }

  return app;
}