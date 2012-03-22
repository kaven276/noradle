# date format (ok)

* how to determine the current time-zone from oracle
* last modified
* date
* expire
* if app use timestamp series datatype, how to convert it to UTC time for http

# lob(blob) optimization

* create temporary blob as the job start, and fill it to a length to occupy memory space
* extent from above, use dbms_lob.
* before do gzip, erase/trim first, so if memory will be released ?
* (from oracle doc) When data is erased from the middle of a LOB, zero-byte fillers or spaces are written for BLOBs or CLOBs respectively. so erase trailer content of src before do gzip can keep entire temp blob in cache/memory
* the blob to save gzip result do not need to create beforehand. 
* need to auto calculate chunk size / buffer sect size

# file upload (partial)

* can use r.upload(filename) to get blob/blobs
* can use k.save(nodepath) to save upload file to node6

# clob test (giveup)

	http write will output to blob directly, so any charset can be writen to it.

* all http body will write to clob using db charset
* if write some nchar, then nchar must be converted to db charset
* or if db charset can be convert to nchar, it's must can, write to nclob
* but oracle may support nclob for utf16 only
* can clob to pre-allocate
* if write to nchar(utf8), will char automatically do conversion, maybe yes, so we can just use nclob for http body, and append it using varchar2 or nvarchar2, so use utf8 as nchar is ok
* but if you are not using utf8 as nchar ???
* when p write, it'll see what charset is used for output, if utf8 use nclob, if dbcharset use clob, if other charset, use blob.
p.d/p.line will switch between it.


# http header should have default value and set, when header close then output to client/browser (ok)

* multiple set-cookie will keep the last only
* when select charset, PSP.WEB will known if and how to do conversion

# access from mobile net speed test

* iPhone will got all html then start to parse/render, so steaming is not a very good way to do
* maybe PSP.WEB can write to clob as before, and then convert to blob using charset conversion, and then send to node as a whole using content-length header. Suss charset/endmark/error problem can be easily solved
* when we need long job, we can do it only at PC with streaming, but not with mobile phone or other less powered equipment.
* if we need large page, we can use ajax to load parts, and add paralysm, or we can use websocket
* using ajax: more overhead(for filter/request parser), but more parallelism, multiple subpage sources.
* using long-running streamed page will have low overhead,

# k_cookie can set cookie (ok)

# URL API U (ok)

  It's may consider how to determine the url of the uploaded file.

# gateway can use mapping table to map a dad to a dbu [todo]

# gateway can switch between db users (ok)

# character set convertion (difficult/undone)

* support utf8 and db charset
* do convert only when length

  Must use utf8, otherwise query-string will send to node as none-utf8 suss cause problem.
  If use zhs16gbk, qstr will send opaque to node and then to oracle, oracle will accept row and do convert to

# catch PL/SQL exceptions and automatically commit (ok)



# do post and redirect result (ok)

* process post and generate a feedback page
* process post and redirect to another resource

# test for auto gzip

* node doesn't support ZLIB/GZIP with enough control, but only through pipe, we cannot control where to begin pipe and where to end pipe.
* may we can use gzip only for static file or cached entities
* [todo] can use static file chunked gzip response to test

# url parsing to find stored procedure (ok)

* add host internal header to support virtual host
* find base,dad,pack,proc,path,qstr,hash;host prefix,port
* now node can parse all of them and sent them line by line to oracle
	
# be compatible with r

* init r with node2psp
* [todo] realize the new simplified page print API and plan to reform the existing PL/SQL code

# allow PL/SQL to set cache indicator

* MD5 digest required. Node will see not send to browser response, but wait for all response made and compute the MD5 digest, then compare with browser sent "if-none-match", if match, node will send a 304, if not match node will send a full response.
	Thus if the page being accessed is stable enough, this caching mechanism will greatly save network transfer and reduce transfer time
	But if the page often change, then the keep-in-node and then-to-next-step method will cause latency, it will beat response streaming.
	
* node in-middle cache.
 node can cache response from oracle and compute a digest MD5 value, when client request, node will send it's cache's MD5 and ETAG in request to oracle. oracle can make a unique ETAG without making the full page, if the ETAG is same as of node cache's ETAG, oracle consider node's cache is validate. How to compute the ETAG quickly without making the whole page is application logic.This mechanism is the same as ORACLE's modplsql cache method.

# feedback info [ok]

* when a post/_c PL/SQL generate a 302/303 redirect and made a feedback page, the page is streamed to node.
 node will then redirect to a url to the feedback.
* feedback page will be kept for a while, compute a MD5 value and add to feedback page url
* when feedback page url is called, node can recognize it's a feedback url, and using MD5 value to index find out then kept feedback page and response to browser and delete the kept feedback page
* This will prevent from repeat/refresh the post/_c url.

# oracle's "PMON" and process control parameters (ok)
