var http = require('http');
var Url = require('url');
var Qstr = require('querystring');
var Path = require('path');
var cfg = require('./cfg.js');
var findFreeOraLink = require('./db');
var CRLF = '\r\n';
var CRLF2 = '\r\n\r\n';
var CRLF3 = '\r\n\r\n\r\n';
var feedback_seq = 0;

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase() {
    return;
}
ReqBase.prototype.toOraLines = function() {
    var a = this;
    var r = [a.method, a.hostp, a.port, a.base, a.dad, a.prog, a.pack, a.proc, a.path, a.search, a.hash].join(CRLF);
    console.log(r);
    return r;
}
ReqBase.parse = function(method, host, url) {
    var r = new ReqBase();
    console.log(host);

    r.method = method;
    r.hostp = host[0];
    r.port = parseInt(host[1] || '80');

    var path_sects = url.pathname.split('/');
    r.base = path_sects.splice(0, cfg.path_base_parts + 1).join('/');
    r.dad = path_sects.shift();
    r.prog = path_sects.shift();
    var parts = r.prog.split('.');
    if (parts.length === 1) {
        r.pack = '';
        r.proc = r.prog;
    } else {
        r.pack = parts[0];
        r.proc = parts[1];
    }
    r.path = path_sects.join('/') || '';
    r.search = url.search || '';
    r.hash = url.hash || '';
    return r;
}

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
        res.writeHead(200, {
            'Content-Type': 'image/icon',
            'Content-Length': 3
        });
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

    var rb = ReqBase.parse(req.method, reqHeaders.host.split(':'), url);

        });
        res.write(res.socket.feedback_1st_chunk);
        oraHeaderEnd = true;
        res.socket.oraSock.resume();
    } else {
        send2oracle();
    }

    function send2oracle() {
        oraSock.write(endMark + rb.toOraLines() + CRLF);

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
    }

    function accept_oracle_data(data) {
        console.log('-- received data');
        console.log(data);
        if (oraHeaderEnd) {
            write_chunk(data);
            return;
        }
        var pos = data.indexOf(CRLF2);
        if (~pos) {
            var oraResHead = data.substr(0, pos).split(CRLF);
            var bodyChunk = data.substr(pos + 4);
            console.log(oraResHead);
            var status = oraResHead[0];
            for (var i = 1; i < oraResHead.length; i++) {
                var nv = oraResHead[i].split(/:\s?/);
                resHeaders[nv[0]] = nv[1];
            }
            resHeaders['x-powered-by'] = 'PSPDWEB';
            resHeaders['Transfer-Encoding'] = 'chunked';
            // resHeaders['Content-Encoding'] = 'gzip';
            res.writeHead(status, resHeaders);
            oraHeaderEnd = true;
            console.log('--- response headers ---');
            console.log(resHeaders);

            if (bodyChunk.length) {
                write_chunk(bodyChunk);
                console.warn('\nfirst chunk has http header and parts of http body !');
                console.log('cupled http body size is %d', chunk.length);
            }
        }
    }
    oraSock.setEncoding('utf8');
    oraSock.on('data', accept_oracle_data);

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
            oraSock.removeListener('data', accept_oracle_data);
        }
    }
});
UAListener.listen(cfg.client_port);
