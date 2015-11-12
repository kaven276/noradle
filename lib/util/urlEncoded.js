"use strict";
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
      if (n.substr(0, 1) === '_') {
        v && parse(v, '%26', '%3D');
      } else {
        if (qstr[n]) qstr[n].push(v);
        else qstr[n] = [v];
      }
    });
  })(text, '&', '=');

  if (unitTest) console.log(qstr);
  return qstr;
}

module.exports = urlEncoded;

// unit test
if (unitTest) {
  console.log(urlEncoded('a=1&a=2&a=attr1 4&b=1&_b=2'));
}
