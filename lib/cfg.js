module.exports = {
    path_base_parts: 0,
    host_base_parts: 2,
    favicon_path : '',
    oracle_port : 1522,
    client_port : 1523,
    server_name : 'PSP.WEB',
    accept_count : 10, // accept connection queue limits
    keepalive_timeout : 1200, // default to 20 minutes
    upload_dir : '/Users/cuccpkfs/dev/upload/',
    upload_depth : 4, // can specify 1,2,3,4, to divide the 16 byte random string to parts to avoid too big directory, default/more is 2
    static_root : null, // specify where the static file root directory is at
    dummy : undefined
}
