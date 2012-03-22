<link type="text/css" rel="stylesheet" href="../doc.css" />

<div id="title"> PSP.WEB History Breaf </div>

# PSP.WEB v0 ( Original Oracle PSP )

  Oracle support mod_plsql apache module in Companion CD for 10G and Web Tier for 11G. The oracle's PSP has many shortcuts, including:

* The HTP and HTF API is not natural and hard to use
* Can not provide exactly every http request header info
* Can not provide http request body info
* Front-end web server can not support well for keep-alive requests
* Configuration Apache is a burdden
* Configuration one dad for one database user or application
* Do not support streaming of http response


# PSP.WEB v1 (2006)

## support another page writing,

* use `p.tag, p.tag_open, p.tag_close` series API
* support procedure and function version of the same API, function version just return the string of output but do not print to the http output
* support bulk API such as `p.ths, p.tds, p.options, p.input_checkboxes ...`
* provide UI HTC js component for tab-page, tree, menu, folder, pop-up input, form check ...


## PSP.WEB v2

  This version is toward a enterprise cluster server with high security level.

* Native SSO support, across multiple apache and multiple oracle.
* support layers control, including Boundary(print page),Control(process data),Hidden(for ajax...),Entity layers(for data DML)
* Native authentication mechanism support additional check such as SMS, support more security
* Can balance among the apache servers
* provide configuration of page group, role, right, menu, page parameter

# PSP.WEB v3

## use blob for every response produced by PSP.WEB

* Support set http header after http body has ready write something
* Allow for gzip compression
* Allow for md5 digest computation

## support filter mechanism

  You can code `k_gw.cancel_page` to

# PSP.WEB v4 (2011)

## Unified DAD

* transfer gateway logic from modplsql into internal pl/sql servlet/k_gw
* k_gw can switch to the target db user's identity and privilege
	
## Simplified and unified url reference
	
  can move all static files into any server that can be any server(apache/node/...)
	
## Unified request info package R

  R has http headers, cookies, parameters, url parts all in it
	
# PSP.WEB v5 (current) concentrate on fundamental function

  The new version 5 PSP.WEB is based on nodeJS http gateway, it's no longer based on Apache's mod_plsql module.

  A nodeJS http gateway will accept all http request from clients, parse the request and send them to oracle. Oracle use `UTL_TCP` to establish TCP connections to nodeJS gateway, so oracle can accept all parsed http request info and print back the http response to nodeJS gateway. The NodeJS gateway is to act as the front-end http server to listen and keep-alive http connection, the main work is done at ORACLE's side by PL/SQL.

  This version of PSP.WEB will provide full http protocol support, http request line, header lines, form-sumit info, file-upload, entity body info can all be got with API R, and response can be full control, you can stream output, gzip, computed etag and content-md5, use of last-modified, etag, if-modified-since, if-none-match to generate 304 response, support any charset output, can take varchar2 or nvarchar2 both, support page as file download. It can response with all types of http error status.

  Beside above, This version of PSP.WEB have it's own unique feathers:

* component css (in html head or link to)
* scalable css
* post to control lay unit and generate(when process is successful) page as a feedback page to avoid repeating post

  For oracle side's process, you can 

* leverage the power of result-cache at row level using versioned result-cache
* proper use of browser session info to store login user-id, and other info.
