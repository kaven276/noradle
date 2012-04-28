var fs = require('fs');
module.exports = {
    host_base_parts: 2,
    oracle_port : 1521,
    http_port : 80,
	https_port : 443,
    server_name : 'PSP.WEB',
    accept_count : 10, // accept connection queue limits
    keepalive_timeout : 1200, // default to 20 minutes
    upload_dir : '/Users/cuccpkfs/dev/upload/',
    upload_depth : 4, // can specify 1,2,3,4, to divide the 16 byte random string to parts to avoid too big directory, default/more is 2
    static_root : null, // specify where the static file root directory is at
    favicon_path : '../public/favicon.ico',
    favicon_max_age : 24*60*60,
	ssl_key : fs.readFileSync('server.key'),
	ssl_cert : fs.readFileSync('server.cert'),
	plsql_mount_point : '/', // if mount to nodejs connect's path, it's not empty
	file_mount_point : '/',
    dummy : undefined // just keep it for diff friendly
}
