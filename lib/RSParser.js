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
      , keyCur
      , stripKey
      , attrsCur
      , rowsCur
      , hashCur
      , valAttr
      , rmFk
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

    function parseNameKey(p00){
      var nk = p00.split('^');
      rsNameCur = nk[0];
      keyCur = nk[1];
      if (keyCur === undefined) {
        stripKey = undefined;
        hashCur = undefined;
      } else {
        if (keyCur.charAt(0) === '-') {
          keyCur = keyCur.substr(1);
          stripKey = true;
        } else {
          stripKey = false;
        }
        hashCur = {};
        if (keyCur === '') {
          keyCur = attrsCur[0].name;
        }
      }
    }

    for (var i = 0, len = lines.length; i < len; i++) {
      line = lines[i];
      if (line.length === 0) {
        // result set section start with a empty line
        // process header including empty line, resultset name, field attributes row
        rsHead = lines[++i];
        if (!rsHead) continue; // maybe there is trailing blank line
        if (rsHead.charAt(0) === '*') {
          scalar(rsHead);
          continue;
        }

        valAttr = -1;
        attrsCur = lines[++i].split(colsep); // next line will be header line for attr names
        attrsCur = attrsCur.map(function(v, i){
          var tp = v.split(':'); // attr should be in format attrName:attrTypeId
          if (tp[0] === '-') {
            valAttr = i;
          }
          return new Attr(tp[0], tp[1]);
        });

        rsHead = rsHead.slice(1, -1).split('|'); // [rsName] in line
        if (rsHead.length > 1) {
          var p0 = rsHead[0].split('/')
            , p1 = rsHead[1].split('/')
            , parent = p1[0]
            , fk = p0[1] || p1[1] || attrsCur[0].name
            , pk = p1[1] || p0[1] || rss[parent].attrs[0].name
            , prows = rss[parent].rows
            , pidx = 0
            , subs = false
            ;
          if (fk.charAt(0) === '-') {
            fk = fk.substr(1);
            rmFk = fk;
          } else {
            rmFk = '';
          }
          parseNameKey(p0[0]);
          rss[rsNameCur] = {
            name: rsNameCur,
            attrs: attrsCur,
            key: keyCur,
            stripKey: stripKey,
            parent: parent,
            pk: pk,
            fk: fk
          };
        } else {
          parseNameKey(rsHead[0]);
          parent = '';
          rowsCur = [];
          rss[rsNameCur] = {
            name: rsNameCur,
            attrs: attrsCur,
            key: keyCur,
            stripKey: stripKey,
            rows: rowsCur,
            hash: hashCur
          };
        }
      } else {
        if (line.charAt(0).match(/(#|;|\t| )/)) continue;
        // process data
        var rec = new Record(attrsCur, line.split(colsep));
        if (parent) {
          var prow = prows[pidx];
          while (prow[pk] !== rec[fk]) {
            prow = prows[++pidx];
            if (!prow) {
              throw new Error('[convert resultsets] could not find parent for ' + rsHead.join('|'));
            }
            subs = false;
          }
          if (valAttr >= 0) {
            rec = rec[attrsCur[valAttr].name];
          } else if (rmFk) {
            delete rec[rmFk];
          }
          if (!subs) {
            prow[rsNameCur] = subs = [rec];
          } else {
            subs.push(rec);
          }
        } else {
          if (valAttr >= 0) {
            rec = rec[attrsCur[valAttr].name];
          }
          rowsCur.push(rec);
          if (hashCur) {
            hashCur[rec[keyCur]] = rec;
          }
        }
      }
    }

    (function convert_hash(){
      for (var rsNameCur in rss) {
        var rs = rss[rsNameCur];
        if (rs.key && rs.parent) {
          var prows = rss[rs.parent].rows
            , key = rs.key
            ;
          for (var i = 0, len = prows.length; i < len; i++) {
            var prow = prows[i]
              , crows = prow[rsNameCur]
              ;
            if (!crows) continue;
            var chash = prow[rsNameCur] = {}
              ;
            for (var j = 0, jlen = crows.length, crow = crows[0]; j < jlen; j++, crow = crows[j]) {
              chash[crow[key]] = crow;
              if (rs.stripKey) {
                delete crow[key];
              }
            }
          }
        }
      }
      for (var rsNameCur in rss) {
        var rs = rss[rsNameCur];
        if (rs.key && !rs.parent) {
          var rows = rs.rows
            , key = rs.key
            ;
          if (rs.stripKey) {
            for (var i = 0, len = rows.length; i < len; i++) {
              delete rows[i][key];
            }
          }
          delete rs.rows;
        }
      }
    })();

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