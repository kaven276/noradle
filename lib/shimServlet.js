/**
 * print detail request info
 * @param r request structure
 * @param p socket to nodejs
 * @param cb when process complete, call it to signal ogw
 */
function printRequestInfo(r, p, cb){
  setTimeout(function(){
    p.write('<pre>');
    p.write('protocol' + ': ' + r.protocol + '\r\n');
    p.write('hprof' + ': ' + r.hprof + '\r\n');
    p.write('\r\n');
    Object.keys(r.nvp).sort().forEach(function(n){
      p.write(n + ': ' + r.nvp[n] + '\r\n');
    });
    p.write('</pre>');
    cb();
  }, (parseInt(r.nvp.dur) || 0));
}

exports.printRequestInfo = printRequestInfo;