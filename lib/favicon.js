var cfg = require('./cfg.js');
var favicon;
var favicon_path = cfg.favicon_path || '../public/favicon.ico';
var favicon_update_interval = cfg.favicon_max_age || 24 * 60 * 60;

function load_favicon() {
    require('fs').readFile(favicon_path,
    function(err, buf) {
        if (err) {
            var errinfo = 'favicon is not found!';
            favicon = {
                status: 404,
                headers: {
                    'Content-Type': 'text/plain',
                    'Content-Length': errinfo.length
                },
                body: errinfo
            }
        } else {
            favicon = {
                status: 200,
                headers: {
                    'Content-Type': 'image/x-icon',
                    'Content-Length': buf.length,
                    'Cache-Control': 'public, max-age=' + favicon_update_interval
                },
                body: buf
            };
        }
        setTimeout(load_favicon, favicon_update_interval * 1000);
    });
}
load_favicon();

module.exports = function() {
    return favicon;
}
