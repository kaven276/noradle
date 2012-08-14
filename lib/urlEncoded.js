var unitTest = (process.argv[1] === __filename);

function urlEncoded(text){
  if (!text) return '';
  text = text.replace(/\+/g, ' ');
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

  if (unitTest) console.log(qstr);

  var ora_qstr = [];
  for (var n in qstr) {
    ora_qstr.push(n, qstr[n].join(','));
  }
  if (unitTest) console.log(ora_qstr);
  return ora_qstr.join('\r\n');

}

module.exports = urlEncoded;

// unit test
if (unitTest) {
  console.log(urlEncoded('a=1&a=2&a=attr1 4&b=1&_b=2'));
}
