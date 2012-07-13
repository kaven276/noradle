require('../lib/dco_proxy.js').createServer(FakeServer).listen(1528);

function SimpleSmsSubmit(req){
  var lines = req.content.toString('utf8').split('\n');
  this.smg = lines.shift();
  this.target = lines.shift();
  this.content = lines.join('\n');
}

function FakeServer(dcoReq, dcoRes){
  var req = new SimpleSmsSubmit(dcoReq);
  if (dcoReq.sync) {
    //setTimeout(function(){
    dcoRes.end(req.content.toString().split('\n')[0] + '... sent to ' + req.target + ' is completed.\n');
    //}, 0);
  } else {
    dcoRes.end();
  }
}
