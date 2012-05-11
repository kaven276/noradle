function urlEncoded(text){
  if (!text) return '';
  var qstr = {};

  (function parse(body, sep, equ){
    body.split(sep).forEach(function(nv){
      nv = nv.split(equ);
      var n = nv[0];
      var v = nv[1];
      if (qstr[n]) qstr[n].push(v);
      else qstr[n] = [v];
      if (n.substr(0, 1) === '_') {
        parse(v, '%26', '%3D');
        if (n.length === 1 || n.substr(1, 2) === '_') {
          qstr[n].pop();
        }
      }
    });
  })(text, '&', '=');

  var ora_qstr = [];
  for (var n in qstr) {
    ora_qstr.push(n, qstr[n]);
  }
  return ora_qstr.join('\r\n');

}

module.exports = urlEncoded;