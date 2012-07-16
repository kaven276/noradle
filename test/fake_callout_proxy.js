require('../lib/dco_proxy.js').createServer(FakeServer).listen(parseInt(process.argv[2]) || 1528);

// parse the request PDU into SMS structure
function SimpleSmsSubmit(req){
  var lines = req.content.toString('utf8').split('\n');
  this.smg = lines.shift();
  this.target = lines.shift();
  this.content = lines.join('\n');
}

// the fake request handler
function FakeServer(dcoReq, dcoRes){
  var req = new SimpleSmsSubmit(dcoReq);
  if (dcoReq.sync) {
    // artificial process delay
    setTimeout(function(){
      dcoRes.end(req.content.split('\n')[0] + '... sent to ' + req.target + ' is completed.\n');
    }, 0);
  } else {
    // tell server an on-the-way request is handled, allow server to safely exit
    dcoRes.end();
  }
}
