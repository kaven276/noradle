It's all tough problems here.
=============================

### If output status line 200 ok, but then PL/SQL generate a error, how to deal with it

	Must conpensate it, but how?
	If has set a cache related http header, how to rollback it.
	If it's a cachable resource, you will cache it and compute a digest, then write digest in reponse header, and then begin to transfer the http body, if request has if-none-match, then node must not stream back immediately, it must judge if the new response is the same as the cached version. So, you see, for a cachable resource, it's not a problem.
	If it's not a cachable resoure, if exception occur in the middle of page generation, server can use javascript to end html and document.write to clear the existing page, and then redirect the errorinfo page. because it's not cached, it's ok. Server can use window.confirm to let user to select if show the error message. And server will automatically close all the unpaired tags, and insert a error div tag at the end of body tag.
	The already printed html texts will remain visible, and the error message will show after them. Error information has call stack, error stack, env info. In production env, you can configure not to show detailed debug information.

### ORA-30678: too many open connections 
	Cause: An attempt to open a connection failed because too many are already open by this session. The number of allowed connections 
	varies as some may be in use through other components which share the same pool of allowed connections.
	Action: Retry after closing some other connection. The number of connections supported is currently not adjustable.

### how oracle manage tcp links to node

  Oracle may start a process monitor, who can get the control parameter from table, and find how many PSP.WEB background job process is running, how many additional job process need to start or closed.
  Just like apache, psp2node will use start_servers, min_spared_servers, max_spared_servers,max_clients.
  PSP.WEB pmon will check every 3 seconds and take any action if needed.
	When you configure the schedule for PSP.WEB's PMON, all thing is managed automatically.
	A job process will quit if it has processed *max_request_per_process* requests or run longer than *max_duration*, such every PSP.WEB's background server job process can lease computation resources and prevent memory leak.

### about result cache

  oracle 11.2 may not invalidate function result cache all, maybe it's a bug.
but if PSP.WEB use function result cache to store configuration, when configuration changed,
can PSP.WEB detect it ?

  How oracle managed the query result cache, when it will be purged, 
if it invalidation totally depend on the table as a whole.

### how to judge end of plsql reponse stream （solved, but use fixed marker, not random number)

node can generate a ramdom number as the end of stream mark
oracle plsql will get it
when plsql finished output, it will end with the end mark and do a flush
when node get a chunk, node will check if the chunk end with that end mark


### how to convert oracle database character set to UTF8

node use js, js cann't do character sets convertion, it only support UTF-8 encoding.
so convertion should do at oracle side
when plsql call base output api(p.d) , if p.d find the length and lengthb of the string is different,
then p.d will do a convertion from db charset to UTF8
So it's very efficient, psp.web will not do convertion every output.
If db charset is UTF8 already, psp.web can be configured avoid all convertion at all.

If set charset different than UTF8, then p.line should use utl_tcp.write_raw to write data

nls_charset_id(dad_charset)
dad_charset := nvl(owa_util.get_cgi_env('REQUEST_CHARSET'), 'UTF8');
owa_util.mime_header(mime_type, false, utl_i18n.map_charset(dad_charset));
utl_i18n.escape_reference(str)


### when form submit

form submit data will encoded in UTF-8 or some other.
psp.web will check the request header to known which character set form submit use.
And psp.web will do some convertion if needed.

### url query string
node will


### how to support node cache

when node received full response, and the header indicate the result is cachable.
node will store the response in it's cache, and add a md5 etag.
the md5 etag it's the index/hash of the response content,
and node will add etag http header for that value.
Next time client/browser access the same url, node will check if-none-match header,
if plsql output a new reponse with the same md5 hash, node got that there is no change at all,
for client etag = new response etag.
so node will send a 304 not modified response to browser.

This method, oracle will always send the full response to node, so it just not very efficient.
If oracle can itself do the md5 hash, oracle can tell if etags is the same.
but before oracle finish generating response, node must receive the output stream from oracle.
Because oracle will not save the result itself for efficiency (low mem need and quick response)
So it's not a very good caching method.

So it need to compare the cost of two md5 hashing method

1. oracle write response in itself and do the md5, then output the whole result to node then to browser
2. oracle write response directly to node, node compute the md5 and then send to browser result

what ever method we choose, it will alway has a burden of response cantacation and md5 computation
Node can compute md5 with stream, oracle can not by now.
But using node do the hashing work, oracle will send all response body to net.
It's just a tie
If we have another node in the same machine as oracle database, it's no much network burden, and It's solved at some extend.

Now, when plsql begin to generate response, it must first tell node if the response is cachable,
If yes, oracle will send response to local node for md5 hashing who can save the response temporaly,
if no change, local node will tell front node no change, it can use it's cache.

Finally, front end node will cache all cachable response locally,
If no change occur, there is no network traffic for reponse body between front end and oracle.
And ... , if browser send a etag that is the same as the validated front end node cache,
front end node will response with 304 not modified.

### where to store the file upload
node will save the update file locally, when browser request, node directly get the file back.
node will md5 hash the file content, and use that hash result as the id of file.
the md5 and the filename will pass to plsql, so oracle know the filename and url to access the file.

uploaded file access will provided by by node, but node will check if the file url is referenced by a psp.web page,
if not, node will forbid the access or node will ask oracle if the request is allowed.

Store upload file in node over in db will not generate database log, so gain more performance. 
and you can set file parse/process after the upload work to a js function.
The js has all the http request env, and can upload the result to oracle.

Another advantage is when you use oracle XE, there is only 11G space can store data and 1G memory to use, 
If use oracle to store a large number of upload file, XE may reach that limits.

Upload file store in node locally can provide much quick access, node will use all cache method that's applied already for static files.

If oracle do want to read the upload file, plsql can http request node to privide the file as http response body.
It can occur everytime.
When plsql do the upload process, it will get all the fileinfo, so plsql can use that info to tell node give me the info and then store it in a memory based clob or blob, and can store it in db.


### how to do with component css (css link or not)
Traditionly, psp.web will compute md5 hash for byside css of the page, and link to url with that md5 value.
That way, psp.web can only response to browser at the end of process, I'll have some latency to user.
So we need to change it.
The id of css must be known early so response can take early.
How to generate a id for the byside css.
the css url pattern is pack.proc/css/id
If all case there is only one css content, we can omit the /id part
If the css is related to color theme, cookie value or somewhat value that's affect the css content.
that should be in the id part.
But this way the html head's link line will have many variant, that will prevent caching.
So we may assign the css url just as pack.proc/css
When the browser access the pack.proc, oracle give node css content as well as html content.
PSP.WEB will give the css a partial etag that stand for it's variant factor.
When browser access pack.proc/css again, it will sent a etag that has factor and md5 in it.
Node will search in it's cache to find the cached css content by pack.proc and factor value,
If it found one, node will compare md5, if match, response with 304 not modified, if not match, send whole css content back to the browser.

Maybe byside css will never have true cache in node.
the css request next to pack.proc will always right find the corresponding temporary css cache by msid or sockid.
If md5 etag is same, response 304 not modified is ok. Or else send full css text back.

If byside css use md5, response will take after the full html is finished.
So browser parsing will delay, maybe flink will occur or maybe html body will not show to wait for full css downloading.
So using byside css do has some shortcoming.

#### may be has standalone css is ok
a plsql dynamic css page can take all factor like terminal size and etc ...
that will do the right length computation and terminal adaption.

