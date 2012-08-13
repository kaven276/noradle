var logger = {}
  , whiteList = ''
  , blackList = 'db,TimeOut,turn,oraReq,oraResp,msgStream'
  ;

whiteList.split(',').forEach(function(v){
  logger[v] = function(){
    arguments[0] = '[' + v + '] ' + arguments[0];
    console.log.apply(console, arguments);
  }
});

blackList.split(',').forEach(function(v){
  logger[v] = function(){
  };
});

module.exports = logger;
