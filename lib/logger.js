var logger = {}
  , whiteList = 'db'
  , blackList = 'turn,oraReq,msgStream'
  , i
  ;

whiteList.split(',').forEach(function(v){
  logger[v] = console.log;
});

blackList.split(',').forEach(function(v){
  logger[v] = function(){
  };
});

module.exports = logger;
