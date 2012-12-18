var cfg = require('./cfg.js')
  , c
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
  console.log('Noracle psp.web server start at ', new Date());
  var mon = require('./monitor.js')
    , ports = mon.ports
    , servers = mon.servers
    ;
  servers.http = require('http').createServer(handler)
    .listen(cfg.http_port, function(){
      ports.http = cfg.http_port;
      console.log('PSP.WEB server is listening at http port ' + cfg.http_port);
    })
    .on('error', function(error){
      console.warn(error.toString());
      console.trace();
    })
    .on('clientError', function(){
      console.warn('client error occurred ！');
    });

  if (!cfg.https_port || !cfg.ssl_key || !cfg.ssl_cert) return;

  var options = {
    key : cfg.ssl_key,
    cert : cfg.ssl_cert
  };

  servers.https = require('https').createServer(options, handler)
    .listen(cfg.https_port, function(){
      ports.https = cfg.https_port;
      console.log('PSP.WEB server is listening at https port ' + cfg.https_port);
    })
    .on('clientError', function(){
      console.warn('client error occurred ！');
    });
};

exports.start_static = function(app){
  console.log('Noracle static file server start at ', new Date());
  app.use(c.favicon(cfg.favicon_path, {maxAge : cfg.favicon_max_age}));

  require('http').createServer(app)
    .listen(cfg.static_port, function(){
      console.log("static server (http) is listening at port " + cfg.static_port);
    });

  if (!cfg.static_ssl_port || !cfg.ssl_key || !cfg.ssl_cert) return;

  var options = {
    key : cfg.ssl_key,
    cert : cfg.ssl_cert
  };

  require('https').createServer(options, app)
    .listen(cfg.static_ssl_port, function(){
      console.log("static server (https) is listening at port " + cfg.static_ssl_port);
    });
};

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
};

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
};