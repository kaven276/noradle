# test for auto gzip

* node doesn't support ZLIB/GZIP with enough control, but only through pipe, we cannot control where to begin pipe and where to end pipe.
* may we can use gzip only for static file or cached entities

# url parsing to find stored procedure

* add host internal header to support virtual host
* find base,dad,pack,proc,path,qstr,hash;host prefix,port
* now node can parse all of them and sent them line by line to oracle
	
# be compatible with r

* todo