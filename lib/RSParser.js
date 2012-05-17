function Record(attrs, vals){
  var self = this;
  attrs.forEach(function(attr, i){
    self[attr.name] = vals[i];
  });
}
Record.prototype.print = function(){
  console.log('I am object with class.');
}
function Attr(name, dataType){
  this.name = name;
  this.dataType = dataType;
}

function parse(data){
  var rss = {}
    , lines = data.split('\n')
    , line
    , rsNameCur
    , attrsCur
    , rowsCur
    ;

  for (var i = 0, len = lines.length; i < len; i++) {
    line = lines[i];
    if (line.length === 0) {
      rsNameCur = lines[++i];
      if (!rsNameCur) return rss; // maybe there is trailing blank line
      rsNameCur = rsNameCur.slice(1, -1); // [rsName] in line
      attrsCur = lines[++i].split(','); // next line will be header line for attr names
      attrsCur = attrsCur.map(function(v, i){
        var tp = v.split(':'); // attr should be in format attrName:attrTypeId
        return new Attr(tp[0], tp[1]);
      })
      rss[rsNameCur] = {
        name : rsNameCur,
        attrs : attrsCur,
        rows : []
      };
      rowsCur = rss[rsNameCur].rows;
    } else {
      if (line.charAt(0).match(/(#|;|\t| )/)) continue;
      rowsCur.push(new Record(attrsCur, line.split(',')));
    }
  }
  return rss;
}

exports.parse = parse;