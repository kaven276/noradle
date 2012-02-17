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
var fbSock = [];
var cssSocks = {};

// parsing request line
// fixed part from request line, use to find the plsql stored procedure called
function ReqBase() {
    return;
}
ReqBase.prototype.toOraLines = function() {
    var a = this;
    var r = [a.method, a.hostp, a.port, a.base, a.dad, a.prog, a.pack, a.proc, a.path, a.search, a.hash].join(CRLF);
    return r;
}
ReqBase.parse = function(method, host, url) {
    var r = new ReqBase();

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

function parse_send_qstr(body, oraSock) {
    if (!body) {
        oraSock.write(CRLF2);
        return;
    }
    var qstr = {};

    body.split('&').forEach(function(nv) {
        nv = nv.split('=');
        var n = nv[0];
        if (qstr[n]) qstr[n].push(nv[1]);
        else qstr[n] = [nv[1]];
    });

    var ora_qstr = [];
    for (n in qstr) {
        var val = qstr[n];
        ora_qstr.push(n, qstr[n]);
    }
    if (ora_qstr.length) {
        oraSock.write(ora_qstr.join(CRLF) + CRLF3);
    } else {
        oraSock.write(CRLF2);
    }
}

var UAListener = http.createServer(function(req, res) {
    var n;
    var oraHeaderEnd = false;
    var endMark = '--the end--' + CRLF;
    var oraSock = findFreeOraLink();
    var reqHeaders = req.headers;
    var resHeaders = {
        'x-powered-by': 'PSP.WEB'
    };
    var url = Url.parse(req.url, false);
    var gzip = false;
    var body = '';
    var bytesRead = 0;
    var cLen;
    var fbseq;
    var cssmd5;

    // res.socket.setNoDelay();
    if (url.pathname === '/favicon.ico') {
        res.writeHead(200, {
            'Content-Type': 'image/icon',
            'Content-Length': 3
        });
        res.end('xxx');
        return;
    }

    var rb = ReqBase.parse(req.method, reqHeaders.host.split(':'), url);

    if (rb.prog === 'feedback') {
        fbseq = parseInt(rb.search.split('=')[1]);
        oraSock = fbSock[fbseq];
        if (!oraSock) {
            console.log('if-none-match=' + req.headers['if-none-match']);
            if (req.headers['if-none-match']) {
                res.writeHead(304, {});
                res.end();
            } else {
                res.writeHead(200, {});
                res.end('please donnot refresh feedback page!');
            }
            return;
        }
        delete fbSock[feedback_seq];
        oraSock.write('feedback' + CRLF);
        resHeaders['ETag'] = '"' + fbseq + '"';
        resHeaders['Cache-Control'] = 'max-age=600';
    } else if (rb.prog === 'css') {
        cssmd5 = rb.path;
        console.log('cssmd5='+cssmd5);
        oraSock = cssSocks[cssmd5].pop();
        oraSock.write('csslink' + CRLF);
        resHeaders['ETag'] = '"' + cssmd5 + '"';
        resHeaders['Cache-Control'] = 'max-age=60000';
    } else {
        var oraSock = findFreeOraLink();
        if (!oraSock) {
            console.log('no oracle server connection/process available');
            var errmsg = 'no oracle connection available';
            res.writeHead(503, {
                'Content-Length': errmsg.length,
                'Content-Type': 'text/plain',
                'Retry-After': '3'
            });
            res.end(errmsg);
            return;
        }
        oraSock.busy = true;
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
            reqHeaders.cookie.split(/;\s*/).forEach(function(cookie) {
                var nv = cookie.split('=');
                ora_cookie.push(nv[0], nv[1]);
            });
            oraSock.write(ora_cookie.join(CRLF) + CRLF3);
        }
        else {
            oraSock.write(CRLF2);
        }

        // parameters, for method=get from querystring, for method=post from body
        parse_send_qstr(url.query, oraSock);
        if (req.method === 'POST') {
            if (req.headers['content-type'] === 'application/x-www-form-urlencoded') {
                req.setEncoding('utf8');
                req.on('data',
                function(chunk) {
                    body += chunk;
                });
                req.on('end',
                function() {
                    parse_send_qstr(body, oraSock);
                });
            } else {
                req.on('data',
                function(chunk) {
                    // sent http request body to oracle if oracle can accept
                    // oraSock.write(chunk);
                    });
                req.on('end',
                function() {
                    // signal final of request body or leave it to content-length
                    });
            }
        }
    }
    var rcv_cnt = 0;

    function accept_oracle_data(data) {
        console.log('received count = ' + (++rcv_cnt));
        if (oraHeaderEnd) {
            // console.log('\n-- received following oracle response data');
            if (cLen) {
                writeToLength(data);
            } else {
                writeToMarker(data);
            }
            return;
        }
        var hLen = parseInt(data.slice(0, 5).toString('utf8'), 10);
        console.log("hLen=" + data.slice(0, 5).toString('utf8'));
        var oraResHead = data.slice(5, 5 + hLen - 2).toString('utf8').split(CRLF);
        console.log(oraResHead);
        var bodyChunk = data.slice(5 + hLen, data.length);
        var status = oraResHead[0];
        for (var i = 1; i < oraResHead.length; i++) {
            var nv = oraResHead[i].split(": ");
            if (nv[0] === 'Set-Cookie') {
                if (resHeaders[nv[0]]) resHeaders['Set-Cookie'].push(nv[1]);
                else resHeaders['Set-Cookie'] = [nv[1]];
            } else {
                resHeaders[nv[0]] = nv[1];
            }

        }

        // feedback related logic
        if (resHeaders.Location && resHeaders.Location.substr(0, 12) === 'feedback?id=') {
            resHeaders.Location += (++feedback_seq);
            res.writeHead(status, resHeaders);
            res.end();
            fbSock[feedback_seq] = oraSock;
            oraSock.removeListener('data', accept_oracle_data);
            return;
        } else if (status.toString().substr(0, 1) !== '2') {

            }

        res.writeHead(status, resHeaders);
        oraHeaderEnd = true;
        console.log('\n--- response headers ---');
        console.log(resHeaders);

        if (cLen = resHeaders['Content-Length']) {
            cLen = parseInt(cLen);
        }

        if (cLen === 0) {
            res.end();
            console.log('\n-- end response with zero content length --');
            oraSock.busy = false;
            oraSock.removeListener('data', accept_oracle_data);
            return;
        }

        if (bodyChunk.length) {
            console.warn('\nfirst chunk has http header and parts of http body !');
            console.warn('cupled http body size is %d', bodyChunk.length);
            if (cLen) {
                writeToLength(bodyChunk);
            } else {
                writeToMarker(bodyChunk);
            }
        }
    }
    oraSock.on('data', accept_oracle_data);

    function writeToMarker(data) {
        var bLen = data.length;
        if (data.slice(bLen - endMark.length).toString('utf8') !== endMark) {
            res.write(data);
        } else {
            res.end(data.slice(0, bLen - endMark.length));
            console.log('\n-- end response with marker --');
            oraSock.busy = false;
            oraSock.removeListener('data', accept_oracle_data);
        }
    }

    function writeToLength(data) {
        bytesRead += data.length;
        if (bytesRead < cLen) {
            res.write(data);
        } else if (bytesRead === cLen) {
            res.end(data);
            console.log('\n-- end response with full length --');
            oraSock.removeListener('data', accept_oracle_data);
            var css_md5;
            if (css_md5 = resHeaders['x-css-md5']) {
                if (cssSocks[css_md5])
                cssSocks[css_md5].push(oraSock);
                else
                cssSocks[css_md5] = [oraSock];
                return;
            }
            oraSock.busy = false;
        } else {
            throw new Error('write raw data will have content-length set and no trailing end-marker');
        }
    }

});
UAListener.listen(cfg.client_port);
