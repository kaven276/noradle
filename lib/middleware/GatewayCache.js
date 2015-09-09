/**
 * Created by kaven276@vip.sina.com on 15-8-11.
 * rules:
 * A) trigger gateway cache mechanism on
 *   - only cache readonly request whose http method is GET
 *   - only when cache-control exists, and have public, gateway cache will save response
 *   - if server cache-control:no-store, bypass
 *   - if server cache-control:private or no public exists, bypass
 *   - do no cache cookie
 *   - 304 update Date, Expires, Cache-Control
 *  if no public, bypass gateway cache mechanism
 *  if no s-maxage, take max-age as it
 *  if no proxy-revalidate, take must-revalidate as it
 *  if has no-store, do not store with 200 response
 * B) make gateway cache meaningful
 *   servlet should call h.last_modified, h.last_scn, h.etag_md5_on, h.etag to generate any validators
 *   or call cache.max_age, cache.s_maxage to set public cache fresh lifetime
 *   to make gateway cache meaningful
 *   but gateway cache implementation will not check this for performance reason
 *   s-maxage default to max-age default to 0
 * C) destroy of a cache item
 *   - oracle respond with 404 status will delete cache item
 *   - when authoration fail, app should set status=403 forbidden
 *   - when authentication fail, app should set status=3xx to temporary redirect to login page
 * D) determine if cache item is fresh
 * when gateway cache use age>s-maxage, return status=203 as no authoritive, when load is high
 * for request
 *   - gateway cache will respect client request's control-control header(max-stale,min-fresh,max-age,no-cache,no-store)
 * E) cache clean when low memory
 * save LAH at save, update LAH at find
 * periodically check, when low memory, release items in the oldest LAH bucket
 *
 *
 * design priciple
 * 1. for servlet not using gateway cache, overhead should be minimized
 *
 * todo:
 * - respect complex request cache-control(only-if-cached)
 * - use precise age calculation (got_response delay is very low, can be ignored, use keep age is ok)
 * - LRU data management
 * - AAA relax with comparison between x-pw-check=name,regexp and session data
 * - response header vary will affect cache item version
 *
 * example:
 * Cache-Control: public, s-maxage=0, proxy-revalidate, max-age=600
 * for all different user-agents, will force gateway cache to revalidate with original server, do AAA check
 * but for the same user-agent, will use its local cache within 600 seconds
 */

/**
 * store[dbu/prog][key|url|content-location] = { head, body, meta }
 */
var store = {};

var Response = require('../Request.js').Response
  , C = require('../constant.js')
  , debug = require('debug')('noradle:GWCache')
  ;

var LAH
  , curBucketNo = 0
  , lastClearBucketNo = 0
  , reservedSize
  ;

memLimit = (function(){
  var os = require('os');
  if (os.arch().match(/64/)) {
    return 1464 * 1024 * 1024;
  } else {
    return 732 * 1024 * 1024;
  }
})();

function startTimer(minutes, buckets){
  debug('startTimer(minutes=%d, buckets=%d)', minutes, buckets);
  LAH = new Array(buckets);
  for (var i = 0; i < buckets; i++) {
    LAH[i] = {};
  }
  setInterval(function(){
    debug('change bucketNo', curBucketNo);
    debug(LAH);
    cleanBucket(curBucketNo);
    curBucketNo++;

    if (curBucketNo == buckets) {
      curBucketNo = 0;
    }
  }, minutes * 60 * 1000);
}

function isLowMemory(){
  return (process.memoryUsage().heapUsed > memLimit - reservedSize * 1024 * 1024);
}

function cleanBucket(bucketNo){
  var bucket = LAH[bucketNo];
  for (n in bucket) {
    var p = n.split('#')
      , prog = p[0]
      , url = p[1]
      ;
    delete store[prog][url];
  }
  LAH[bucketNo] = {};
  debug('clear bucket no ', bucketNo, curBucketNo);
}

function releaseCache(){
  debug('enter releaseCache');
  debug(LAH);
  debug(lastClearBucketNo, curBucketNo, LAH.length);
  if (!isLowMemory()) {
    return;
  }
  var old = lastClearBucketNo++;
  if (lastClearBucketNo == LAH.length) {
    lastClearBucketNo = 0;
  }
  if (lastClearBucketNo == curBucketNo) {
    // can not release current hour cache
    lastClearBucketNo = old;
    return;
  }
  cleanBucket(lastClearBucketNo);
}

exports.filter = function(cfg){
  /**
   * find cache item by key, it's synchronous call
   * @param key
   */
  function find(prog, key){
    var sub = store[prog];
    if (!sub) return null;
    var item = sub[key];
    if (!item) return null;
    if (item.meta.lastAccessBucketNo !== curBucketNo) {
      delete LAH[item.meta.lastAccessBucketNo][prog + '#' + key];
      LAH[item.meta.lastAccessBucketNo = curBucketNo][prog + '#' + key] = undefined;
    }
    debug('%s,%s found', prog, key);
    return sub[key];
  }

  function mimicOrigin(item, type){
    item.headers['Age'] = Math.round((Date.now() - item.meta.oTime) / 1000);
    item.headers['x-gw-cache'] = type;
    var oraRes = new Response(200, item.headers, true);
    // set oraRes.headers from cache or reuse
    process.nextTick(function(){
      oraRes.emit('data', item.entity, C.BODY_FRAME);
      oraRes.emit('end');
    });
    debug('------- reuse cache item (hit) (%s) ----------', type);
    return oraRes;
  }

  /**
   * if cache item exists and still fresh, use it as oraResponse
   * otherwise, validate its cache with cached item's cache validators
   * change the oraReq's cache validator headers from cached item
   *
   * @param rb
   * @param cb
   * @returns {*}
   */
  function beforeFilter(req, rb){
    if (req.method !== 'GET') return;
    var item = find(rb.x$dbu + '/' + rb.x$prog, rb.u$url);
    if (!item) return
    debug('cache item found')
    req.cacheItem = item;
    var cacheControl = (req.headers['cache-control'] || '').replace(' ', '')
      , sMaxAge = item.meta.sMaxAge || 0
      , age = Math.round((Date.now() - item.meta.oTime) / 1000)
      , match
      ;
    if (!cacheControl) {
      ;
    } else if (cacheControl.match(/no-store/)) {
      // delete cache item
      var sub = store[rb.x$dbu + '/' + rb.x$prog];
      delete sub[rb.u$url];
      delete req.cacheItem;
      req.noStore = true;
      return;
    } else if (cacheControl.match(/no-cache/)) {
      sMaxAge = 0;
    } else if (item.meta.proxyRevalidate == true) {
      ;
    } else if (match = cacheControl.match(/max-stale(=(\d+))?/)) {
      sMaxAge = (match[2]) ? (sMaxAge + parseInt(match[2])) : Number.POSITIVE_INFINITY;
    } else if (match = cacheControl.match(/min-fresh=(\d+)/)) {
      sMaxAge = sMaxAge - parseInt(match[1]);
    } else if (match = cacheControl.match(/max-age=(\d+)/)) {
      sMaxAge = parseInt(match[1]);
    }
    debug('sMaxAge=%d, age=%d', sMaxAge, age);
    if (age < sMaxAge) {
      debug('mimic a oracle response');
      return mimicOrigin(item, 'fresh');
    } else {
      debug('add cache validators to oraReq');
      var etag, lmt;
      // when use gateway cache, then must remove client validators
      if (etag = item.headers['ETag']) {
        rb['h$if-none-match'] = etag;
      } else {
        delete rb['h$if-none-match'];
      }
      if (lmt = item.headers['Last-Modified']) {
        rb['h$if-modified-since'] = lmt;
      } else {
        delete rb['h$if-modified-since'];
      }
      return;
    }
  }

  /**
   * if response have cache validator, catch it, save it to cache
   * if cache item exists and receive 304 status, treat cache item as validated, and mimic real response to the chain
   * if receive 200 status, create/update cache item, and repeat a cache hit procedure
   * if receive 404 not found, delete the cache item
   * if receive other status, bypass it
   *
   * only filter who can change status
   * whether cache hit or not, return status = 200, but headers[x-no-cache-hit]=Y
   * so not need to change status in the filter
   * filter may save/emit or use/emit
   */
  function afterFilter(oraRes, res, req, rb){

    function try_client_304(oraRes){
      // return oraRes;
      if (req.headers['if-modified-since']) {
        if (req.headers['if-modified-since'] !== oHeaders['Last-Modified']) {
          return oraRes;
        }
      } else if (req.headers['if-none-match']) {
        if (req.headers['if-none-match'] !== oHeaders['ETag']) {
          return oraRes;
        }
      } else {
        return oraRes;
      }
      var headers = {};
      headers['Date'] = oHeaders['Date'];
      oHeaders['Expires'] && (headers['Expires'] = oHeaders['Expires']);
      oHeaders['Cache-Control'] && (headers['Cache-Control'] = oHeaders['Cache-Control']);
      //headers['Age'] = oHeaders['Age'];
      debug('response client with 304');
      oraRes = new Response(304, headers);
      process.nextTick(function(){
        debug('mimic end event');
        oraRes.emit('end');
      });
      return oraRes;
    }

    function sMaxAge(){
      if (cacheControl.match(/no-cache/)) return 0;
      var match = cacheControl.match(/s-maxage=(\d+)/) || cacheControl.match(/max-age=(\d+)/);
      return match ? parseInt(match[1]) : 0;
    }

    // receive response body and create/replace cache item
    function saveCacheItem(){
      var chunks = []
        , count = 0
        ;
      oraRes.on('data', function(data){
        if (!data) return true;
        chunks.push(data);
        count += data.length;
      });
      oraRes.on('end', function(){
        var buf = new Buffer(count)
          , offset = 0
          ;
        if (!oraRes.headers['Content-Length']) {
          delete oraRes.headers['Transfer-Encoding'];
          oraRes.headers['Content-Length'] = count.toString();
        }
        delete oraRes.headers['Set-Cookie'];
        chunks.forEach(function(chunk){
          chunk.copy(buf, offset);
          offset += chunk.length;
        });
        var prog = rb.x$dbu + '/' + rb.x$prog
          , key = rb.u$url
          , sub = store[prog]
          ;
        if (!sub) {
          sub = store[prog] = {};
        }
        sub[key] = {
          headers : oHeaders,
          entity : buf,
          meta : {
            oTime : Date.now(),
            sMaxAge : sMaxAge(),
            proxyRevalidate : !!cacheControl.match(/(must-revalidate|proxy-revalidate)/),
            lastAccessBucketNo : curBucketNo
          }
        };
        LAH[curBucketNo][prog + '#' + key] = undefined;
      });
      debug('save cache item');
    }

    if (req.method !== 'GET') {
      return oraRes;
    }

    var item = req.cacheItem
      , oHeaders = oraRes.headers
      , cacheControl = oHeaders['Cache-Control'] || ''
      ;

    if (oraRes.cached) {
      return try_client_304(oraRes);
    }

    if (req.noStore || cacheControl.match(/no-store/)) {
      return oraRes;
    }

    if (!cacheControl || cacheControl.search(/public/) == -1 || req.noStore == true) {
      // || cacheControl.search(/(private|no-store)/) >= 0
      // public cache must not be no-store, and must not be private
      if (item) {
        var sub = store[rb.x$dbu + '/' + rb.x$prog];
        delete sub[rb.u$url];
        debug('delete cache item when no cache-control:public');
      } else {
        debug('bypass caching process');
        //return oraRes;
        return try_client_304(oraRes);
      }
    }

    switch (oraRes.status) {
      case 304:
        if (item) {
          // cached item exists, and servlet status=304, update cached item headers, and use the cached item
          item.headers['Date'] = oHeaders['Date'];
          if (oHeaders['Expires']) {
            item.headers['Expires'] = oHeaders['Expires'];
          }
          if (cacheControl) {
            item.headers['Cache-Control'] = cacheControl;
            item.meta.proxyRevalidate = !!cacheControl.match(/(must-revalidate|proxy-revalidate)/);
          }
          item.meta.oTime = Date.now();
          item.meta.sMaxAge = sMaxAge();
          return try_client_304(mimicOrigin(item, 'revalidated'));
        } else {
          // not throught gateway cache, return to client directly
          return oraRes;
        }
      case 200:
        saveCacheItem();
        oHeaders['Age'] = '0';
        return item ? try_client_304(oraRes) : oraRes;
      case 404:
        // delete cache item, and return as original response
        if (item) {
          var sub = store[rb.x$dbu + '/' + rb.x$prog];
          delete sub[rb.u$url];
          debug('delete cache item by 404')
        }
        return oraRes;
      default:
        return oraRes;
    }
  }

  var gwcfg = cfg.GatewayCache || {};
  startTimer(gwcfg.BucketTimespan || 60, gwcfg.BucketAmount || 24);
  setInterval(releaseCache, (gwcfg.RecycleInterval || 5) * 60 * 1000);
  reservedSize = gwcfg.ReservedSize || 50;

  return {
    before : beforeFilter,
    after : afterFilter
  };

}

