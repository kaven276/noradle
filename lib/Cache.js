/**
 * Created with JetBrains WebStorm.
 * User: kaven276
 * Date: 12-6-18
 * Time: 下午4:21
 */
var bUnitTest = (process.argv[1] === __filename)
  , urlMD5Map = {}
  , md5Contents = {}
  , createHash = require('crypto').createHash
  , zip = require('./zip.js')
  , chooseZip = zip.chooseZip
  , zipMap = zip.zipMap
  , gzip = zipMap['gzip']
  , cfg = require('./cfg.js')
  ;

function urlDigest(url){
  var hash = createHash('md5');
  hash.update(url);
  return hash.digest('base64');
}

function findCacheHit(url, md5){
  urlMD5Map[urlDigest(url)] = md5;
  var md5Content = md5Contents[md5];
  if (md5Content)
    return md5Content;
}

function addCacheItem(url, md5){
  urlMD5Map[urlDigest(url)] = md5;
  var md5cache = md5Contents[md5];
  if (md5cache && md5cache.finished)
    return md5Contents[md5].chunks;
  else
    return new MD5Content(md5);
}

function MD5Content(md5, ohdr, cLen){
  var me = this;
  md5Contents[md5] = this;
  this.md5 = md5;
  this.headers = ohdr;
  this.chunks = [];
  this.refs = 0;
  this.length = 0;
  this.useZip = false;
  this.finished = false;
  if (cfg.use_gw_cache && cLen && cLen > cfg.zip_threshold) {
    this.zipChunks = [];
    this.zipLength = 0;
    this.gzip = gzip();
    this.gzip.on('data', function(data){
      me.zipChunks.push(data);
      me.zipLength += data.length;
    });
    this.gzip.on('end', function(){
      delete me.gzip;
      if (me.zipLength / me.length < cfg.zip_min_radio) {
        // delete me.chunks;
        me.useZip = true;
      } else {
        delete me.zipChunks;
        delete me.zipLength;
        delete me.gzip;
      }
    });
  }
}

MD5Content.prototype.write = function(data){
  this.chunks.push(data);
  this.length += data.length;
  this.gzip && this.gzip.write(data);
};

MD5Content.prototype.end = function(data){
  if (data) this.write(data);
  delete this.headers['Transfer-Encoding'];
  delete this.headers['Content-Encoding'];
  this.headers['x-pw-noradle-cache'] = 'hit';
  this.gzip && this.gzip.end();
  this.finished = true;
  // this.dump();
};

MD5Content.prototype.respond = function(req, res){

  this.headers['Date'] = (new Date()).toGMTString();
  if (!this.useZip) {
    this.headers['Content-Length'] = String(this.length);
    this.chunks.forEach(function(chunk){
      res.write(chunk);
    });
    res.end();
  } else {
    if (~req.headers['accept-encoding'].indexOf('gzip')) {
      this.headers['Content-Length'] = String(this.zipLength);
      this.headers['Content-Encoding'] = 'gzip';
      this.headers['x-pw-zip-radio'] = String(Math.round(this.zipLength / this.length * 100)) + '%';
      res.writeHead(200, this.headers);
      this.zipChunks.forEach(function(chunk){
        res.write(chunk);
      });
      res.end();
    } else {
      // todo uncompress
      this.headers['Content-Length'] = String(this.length);
      this.chunks.forEach(function(chunk){
        res.write(chunk);
      });
      res.end();
    }
  }
}

MD5Content.prototype.dump = function(){
  console.log(this.md5, this.finished);
  console.log(this.headers);
  this.chunks.forEach(function(chunk){
    console.log(chunk.toString('utf8'));
  });
}

exports.findCacheHit = findCacheHit;
exports.MD5Content = MD5Content;