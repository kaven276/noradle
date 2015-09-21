/**
 * Created by cuccpkfs on 14-11-18.
 */

(function(exports){
  "use strict"

  function Record(attrs, vals){
    var self = this;
    attrs.forEach(function(attr, i){
      switch (attr.dataType) {
        case 2: /* number */
        case 100: /* binary_float */
        case 101: /* binary_double */
          self[attr.name] = parseFloat(vals[i]);
          break;
        default:
          self[attr.name] = vals[i];
      }
    });
  }

  function Attr(name, dataType){
    this.name = name.toLowerCase();
    this.dataType = parseInt(dataType);
  }

  var linefeed = String.fromCharCode(30) + '\n'
    , colsep = String.fromCharCode(31) + ','
    , nvseq = String.fromCharCode(31) + '='
    , TF = {"T": true, "F": false}
    ;

  function parse(data){
    var rss = {}
      , lines = data.split(linefeed)
      , line
      , rsHead
      , rsNameCur
      , attrsCur
      , rowsCur
      ;

    function scalar(line){
      // *t|name=value
      var t = line.charAt(1)
        , p = line.split(nvseq)
        , n = p[0].substr(3)
        , v = p[1]
        ;
      switch (t) {
        case 's':
        case 'd':
          break;
        case 'n':
          v = parseFloat(v);
          break;
        case 'b':
          v = TF[v];
          break;
      }
      rss[n] = v;
    }

    for (var i = 0, len = lines.length; i < len; i++) {
      line = lines[i];
      if (line.length === 0) {
        // result set section start with a empty line
        // process header including empty line, resultset name, field attributes row
        rsHead = lines[++i];
        if (!rsHead) return rss; // maybe there is trailing blank line
        if (rsHead.charAt(0) === '*') {
          scalar(rsHead);
          continue;
        }

        attrsCur = lines[++i].split(colsep); // next line will be header line for attr names
        attrsCur = attrsCur.map(function(v, i){
          var tp = v.split(':'); // attr should be in format attrName:attrTypeId
          return new Attr(tp[0], tp[1]);
        });

        rsHead = rsHead.slice(1, -1).split('|'); // [rsName] in line
        if (rsHead.length > 1) {
          var p0 = rsHead[0].split('/')
            , p1 = rsHead[1].split('/')
            , parent = p1[0]
            , fk = p0[1] || p1[1]
            , pk = p1[1] || p0[1]
            , prows = rss[parent].rows
            , pidx = 0
            , subs = false
            ;
          rsNameCur = p0[0];
          rss[rsNameCur] = {
            name: rsNameCur,
            attrs: attrsCur,
            parent: parent,
            pk: pk,
            fk: fk
          };
        } else {
          rsNameCur = rsHead[0];
          parent = '';
          rowsCur = [];
          rss[rsNameCur] = {
            name: rsNameCur,
            attrs: attrsCur,
            rows: rowsCur
          };
        }
      } else {
        if (line.charAt(0).match(/(#|;|\t| )/)) continue;
        // process data
        var rec = new Record(attrsCur, line.split(colsep));
        if (parent) {
          var prow = prows[pidx];
          while (prow[pk] !== rec[fk]) {
            prow = prows[++pidx]
            subs = false;
          }
          if (!subs) {
            prow[rsNameCur] = subs = [rec];
          } else {
            subs.push(rec);
          }
        } else {
          rowsCur.push(rec);
        }
      }
    }
    return rss;
  }

  exports.rsParse = parse;

  if (typeof define === 'function' && define.amd) {
    define([], function(){
      return parse;
    });
  }

})((function(){
  try {
    return window;
  } catch (e) {
    return exports;
  }
})());