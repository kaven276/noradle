var http = require('http');
var Url = require('url');
var Qstr = require('querystring');
var Path = require('path');
var cfg = require('./cfg.js');
var findFreeOraLink = require('./db');
var CRLF = '\r\n';
var CRLF2 = '\r\n\r\n';
var CRLF3 = '\r\n\r\n\r\n';

var UAListener = http.createServer(function(req, res) {
    var n;
    var oraHeaderEnd = false;
    var endMark = '--the end--' + CRLF;
    var oraSock = findFreeOraLink();
    var reqHeaders = req.headers;
    var resHeaders = {};
    var url = Url.parse(req.url, false);
    var gzip = false;
    
    // res.socket.setNoDelay();

    if (url.pathname === '/favicon.ico') {
        res.writeHead(200,{'Content-Type':'image/icon', 'Content-Length':3});
        res.end('xxx');
        return;
    }

    if (!oraSock) {
        console.log('no oracle server connection/process available');
        var errmsg = 'no oracle connection available';
        res.writeHead(500, {
            'Content-Length': errmsg.length
        });
        res.end(errmsg);
        return;
    }
    oraSock.busy = true;

    // fixed part from request line, use to find the plsql stored procedure called
    console.log(url);
    var host = reqHeaders.host.split(':');
    var port = parseInt(host[1] || '80');
    var hostp = host[0];
    var path_sects = url.pathname.split('/');

    var base = path_sects.splice(0, cfg.path_base_parts + 1).join('/');
    console.log(path_sects);
    var dad = path_sects.shift();
    var prog = path_sects.shift();
    var parts = prog.split('.');
    if (parts.length === 1) {
        pack = '';
        proc = prog;
    } else {
        pack = parts[0];
        proc = parts[1];
    }
    var path = path_sects.join('/');

    var ora_loc = [hostp, port, req.method, base, dad, prog, pack, proc, path, url.search, url.hash || ''];
    console.log(ora_loc);
    oraSock.write(endMark + ora_loc.join(CRLF) + CRLF);

    // http request headers, pass throuth to oracle except for cookies
    var ora_head = [];
    for (n in reqHeaders) if (n.toLowerCase !== 'cookie') ora_head.push(n, reqHeaders[n]);
    oraSock.write(ora_head.join(CRLF));
    oraSock.write(CRLF3);

    // http request header's cookies
    var ora_cookie = [];
    if (reqHeaders.cookie) {
        reqHeaders.cookie.forEach(function(cookie) {
            var nv = cookie.split('=');
            ora_cookie.push(nv[0], nv[1]);
        });
        oraSock.write(ora_cookie.join(CRLF) + CRLF3);
    }
    else {
        oraSock.write(CRLF2);
    }

    // parameters, for method=get from querystring, for method=post from body
    var qstr = Qstr.parse(url.query);
    var ora_qstr = [];
    for (n in qstr) ora_qstr.push(n, qstr[n]);
    if (ora_qstr.length) {
        oraSock.write(ora_qstr.join(CRLF) + CRLF3);
    } else {
        oraSock.write(CRLF2);
    }

    req.on('data',
    function(chunk) {
        // sent http request body to oracle if oracle can accept
        // oraSock.write(chunk);
        });

    req.on('end',
    function() {
        // console.log(req.url + ' has made its request');
        })

    oraSock.setEncoding('utf8');
    oraSock.on('data',
    function(data) {
        console.log('-- received data');
        if (oraHeaderEnd) {
            write_chunk(data);
            return;
        }
        var pos = data.indexOf(CRLF2);
        if (~pos) {
            var oraResHead = data.substr(0, pos).split(CRLF);
            var status = oraResHead[0];
            var mime = oraResHead[1];
            var charset = oraResHead[2];
            resHeaders['Content-Type'] = mime + '; charset=' + charset;
            resHeaders['x-powered-by'] = 'PSPDWEB';
            resHeaders['Transfer-Encoding'] = 'chunked';
            // resHeaders['Content-Encoding'] = 'gzip';
            res.writeHead(status, resHeaders);
            oraHeaderEnd = true;
            console.log('--- response headers ---');
            console.log(resHeaders);

            var chunk = data.substr(pos + 4);
            if (chunk.length) {
                write_chunk(chunk);
                console.warn('\nfirst chunk has http header and parts of http body !');
                console.log('cupled http body size is %d', chunk.length);
            }
        }
    });
    oraSock.on('end',
    function() {

        });

    function write_chunk(data) {
        console.log();
        var bLen = (new Buffer(data)).length;
        if (data.substr( - endMark.length) !== endMark) {
            if (!oraHeaderEnd) console.log(data);
            res.write(data);
        } else {
            res.end(data.substr(0, data.length - endMark.length));
            console.log('-- end response --');
            oraSock.busy = false;
        }
    }
});
UAListener.listen(cfg.client_port);
