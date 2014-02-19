exports.Servlet = function(dbu, prog){
  this.dbu = dbu;
  this.prog = prog;
  var parts = prog.split('.');
  if (parts.length === 1) {
    this.pack = '';
    this.proc = prog;
  } else {
    this.pack = parts[0];
    this.proc = parts[1];
  }
}