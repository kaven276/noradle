var logger = {}
  , whiteList = ''
  , blackList = 'db,steps,TimeOut,turn,oraReq,oraResp,msgStream'
  ;

blackList.split(',').forEach(function(v){
  logger[v] = function(){
  };
});

whiteList.split(',').forEach(function(v){
  logger[v] = function(){
    var arr = Array.prototype.slice.call(arguments);
    arr.unshift("[" + v + "]");
    console.log.apply(console, arr);
  }
});

module.exports = logger;

