<link type="text/css" rel="stylesheet" href="doc.css" />
<style>
div.path{display:inline-block;font-size:smaller;}
</style>

<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title"> Introduction to Noradle(PSP.WEB)   </div>

What's PSP.WEB
===============

  PSP.WEB is the short term   
of "PL/SQL Stored Procedure for WEB"   
or "PL/SQL SERVER PAGES for WEB"   
or "PAGE of Stored Procedure for WEB".

  PSP.WEB use PL/SQL programing language to do web development, It's a language of DB stored procedure, that is different from most of the other web developing languages and platforms such as J2EE .Net, PHP, RUBY. With PSP.WEB platform, PL/SQL can use PSP.WEB APIs to gain http request info(request line parts, http header info, form submit, fileupload, request body and etc...), do nature data processing (insert,update,delete,select and PL/SQL code), and print page (header info and page body) to http response. It's the most proper way to develop database(oracle) based web applications. 

<div id="graph">
  <button>browser<br/>user agent</button> --- 
<div class="path">http protocol<br/>well keep-alive<br/>high concurrency</div> ---
<button> NodeJS<br/>http gateway</button> ---
<div class="path"> pool of TCP connection by UTL\_TCP
	<br/> established from ORACLE to nodeJS
	<br/>line-by-line request and raw response </div> --- 
<button>ORACLE<br/>DATABASE<br/>engine&dispatcher</button> @
<div class="path">run as background job processes
	<br/>restart after much work or long time by K\_PMON
	<br/>switch to target dbu's right
	<br/>locate the PL/SQL procedure and run</div>
</div>


Why invent PSP.WEB
===============

  I prefer to put all logic that deals with data in PLSQL. There is no more natural language to interact with SQL data then PLSQL, None. PL/SQL has natural advantages, using PL/SQL for developing web site/application is seductive. But naturally, PL/SQL have no touch with http protocol, If we provide a http listener (such as nodeJS based) that can communicate with oracle PL/SQL, we can invent a whole new stored-procedure based web platform that is the most integrated and convenient platform taking both application layer and database layer together. That is just the way PSP.WEB do. Now PL/SQL leverage it's power to web development in it's most. All the sections below will tell you the unique features of PSP.WEB that other web-dev techs do not reach.

## avoid database connection related work

  Since all code are stored procedure that run in DB, there is **no sql driver or database client driver needed**, and, there is no longer any connection configuration work that other web platform need to do. PSP.WEB will launch a set of background worker job for http processing, they are just pool of servers, PSP.WEB will alway select the first free worker process, minimize the process switch overhead. This is really a kind of **natural connection pool with zero configuration**.

## internal network cost is minimized

  PL/SQL run within DB, they are run directly on database server processes (exactly say, on background job processes), there is no traditional DB client-server cross inter-process communication. PL/SQL just use QUERY or DML ** to manipulate data in-process **.

  PSP.WEB use NodeJS as http listener, NodeJS act as the http gateway for PL/SQL, NodeJS gateway will parse the http request, transform it to a easy to read format and send them to one of the free PSP.WEB worker job process using TCP, PL/SQL will output the response through NodeJS gateway to the final client(browser). The communication between http listener NodeJS gateway and PSP.WEB worker job processes is simple and low cost, since they communicate with **minimal of roundtrips**, commonly, there is one tcp/ip packet for one request and there is one or several tcp/ip packet for one response, And there is just raw binary data stream for response from PL/SQL, there is **no data serialization and parsing** at the two ends that all kinds of the sql driver will do.

## PL/SQL is the best way to process data with embed sql. 

  Use %rowtype to declare variables is much better than xDBC, EMBED-x and OR-Mapping since all other none-store-procedure based application server will declare data structures according to database tables and it' so redundant, hard to update or keep sync, and need to carefully map the two different data types, use PL/SQL there is **minimal of data structure declaration**. 

  SQL-binding is so good, you have no change to submit string-spelled sql text, all sql is parsed in PL/SQL already, all sql use bound parameter already, no sql-infection attack possible, no repeating sql parsing possible.

## online upgrade is supported

  PL/SQL has auto dependency management, if a object that a PL/SQL unit referred is changed, ORACLE will recompile the PL/SQL unit automatically, so you can **bug-fix or upgrade your code online** without breaking your service. Notice that most of the application server platform do not support on-line update or safe on-line update.

## Has very handy IDE for both PL/SQL coding and data manipulation

  There is a full featured PL/SQL IDE called [** PL/SQL developer **] [PL/SQL Developer], It's as good as the most used IDE such as Eclipse ..., but with data manipulation integrated.

  Traditionally, you use different developing tool and IDEs for application language and database, such as use Eclipse and SQL deveoper both. Now you need only one IDE - "PL/SQL developer".

## In-DB result cache with low design/coding cost

  ORACLE support result-cache, but PSP.WEB provide **row level versioned result_cache**, often used data can be result cached such as user profile, terminal properties. None stored procedure based platforms will do hard to provide data cache and will be too complex.

What is Noradle
================

use cases:

1. psp.web: nodejs as http reverse proxy, oracle implement the http server
2. DBCall : nodejs db access driver, get sql result sets
3. Ajax/WS data src : browser can feed sql results sets and JSON for ajax or websocket request
3. DCO: oracle can call nodejs worker proxy through ext-hub, extending oracle's capability

Compare to other platforms
=================

Compare to Oracle's PSP
-----------------

  Someone will tell me that ORACLE has PL/SQL SERVER PAGES support by [mod_plsql] [mod_plsql] within Apache since 8i. Now I tell you ORACLE's PSP is so limited, and it is unchanged for many years and almost frozen. Below I list some of it's limits.

* Installation of Companion CD for 10G and Web Tier for 11G is tedious, actually only a bit of part is for PSP, but you are forced to install all of them.
* Configuration Apache is a burden, most of configuration is not related to PSP, but you must do configure work.
* Configuration one dad for one database user or application, it's so tedious and can not reuse database connection for different DADs
* The HTP and HTF API is not natural and hard to use
* Can not provide exactly every http request header info
* Can not provide http request body info
* Support very limited http response header (only status line, content-type, location is supported)
* Do not well support charset, since owa's page buffer is array of varchar2, not nvarchar2 or raw data
* Front-end web server can not support well for keep-alive requests
* Do not support streaming of http response
* Every http request will form a dynamic spelled anonymous sql, hit-rate of oracle shared-pool is low
* html form parameters must have corresponding procedure parameters with the same name, it's so rigid, fragile, and can not span across PL/SQL call stack.
* No support for streaming. PSP will store all staging page content in array of varchar2, then the last byte made, it will transfer to mod-plsql. But you may need the page head and some of content to return to browser more quickly.


  PSP.WEB removed the limitation or burden from ORACLE's ancient PSP, PSP.WEB has simple installation and configuration, support almost full http protocol specification with easily used API and framework, it's no longer a sugar toy as PSP.

Compare to Oracle's APEX
------------------

  APEX support common dynamic website design (authentication, page flow control, ...), It's a high level platform, so it's convenient, but because its lack of low level API/framework support, it limit the freedom of design. It can be used in some none official and common cases, but if your organization need a serious information system, you'd better not to use it. It's fixed bound to its UI/app design, but real requirement is much more flexible and versatile.

  APEX is design after Microsoft's Access and Oracle's forms. We known the limits of access like RAD, it' not for real programmers, and it is not for serious applications.

  The good to use PL/SQL for web is for write data processing ode in IDE like "PL/SQL Developer", intelligent code assistant is there, but when you use APEX, all the goods are lost. I's difficult to write a simple sql or pl/sql. Apex just throw away the only real valuable feature (stuck to easy data process coding) of oracle development, and trade it for the self pleased so limited wizard, predefined design patterns. 

Compare to J2EE (and other platforms that a language different than PL/SQL to do logic and connect to db for data processing)
------------------

  For J2EE, I never felt I need anything beyond tomcat and JDBC connection to the database. All these
Enterprise Beans, OR-Mapping, eXtremely Messy Language, SOAP, etc are for SQL challenged developers only.

  My view -- I'm lazy.  I want to admin as few things as possible.  I'm easily confused as well -- 
I'd rather have as few moving pieces as possible.  Do I really need a browser to talk http to a servlet that will do some EJB thing to a bean that was built using CMP for persistence to update a row in a table?

  I find when I build an app against the database -- guess what?  its all about the data.  How can that middle tier app work out a repayment schedule in the middle tier *without sucking all of the data out of the database and pretending to be a database itself*?

  We really need a better integration between a host language and the relational model, only PL/SQL is fit, java,c/c++,c-sharp,php all of them is uncomfortable for it.

  An app server includes a web server and other modules to host an a web application. Usually you need one when you generate dynamic content out of database. The code deployed in app server is just execute app logic, and the app logic is almost equal to data processing in database. So rather than you code with xDBC/OR-mapping to code your app logic, you should code PL/SQL directly and far more conveniently to achieve the same goal.

  So, if you choose ORACLE as your backend database, your dynamic site should prefer PSP.WEB as the technical platform over all the others.

Main Design Considerations
============

Complete independent of the ORACLE' PSP
------------

  The new PSP.WEB have it own API's, that is not rely on any of the ORACLE'S owa prefixed packages and htp,htf packages. PSP.WEB do not need Apache and mod-plsql to deploy, nor need XDB http server running. Application of both PSP and PSP.WEB can be deployed both in one oracle database with no conflict.

low level support for http protocol
------------

  ORACLE's ancient PSP can not handle some of the http features, there is no API to gain arbitrary http request header info, there is no API to get the whole request body lob. Upload file is force to save in upload table no matter of wether the main handler is willing to save it. You are forced to print http header lines (status-line, mime-type, redirect-url in owa-util) before page body printing. It doesn't support page response streaming and compression. The http basic/digest authentication is configured but do not support API for flexible use cased. Expire and validation cache model for browser is not supported at API level.

  But in PSP.WEB, we support almost every aspect features of http protocol is supported well that is sensible for dynamic page app. All request info (include parts of status line, http headers, query string, http form submit parameters(all enctype), file upload, request body itself, cookies) can be got with ease to use API. For response, streaming, compression, 304 caching, attachment download, mime-type, any charset is supported. Http authentication is supported at http header API. You can give the right response status with API.

  The API h is stand for http, that can specify any http response header, and PSP.WEB will do according to the response header, for example, it you set compress:gzip in response header, PSP.WEB will automatically do gzip compression for the output page; if you set content-type's charset is gbk, then PSP.WEB will automatically convert the page from db charset to gbk charset. The PSP.WEB API is just follow http protocol, so it's low level enough, it provide a good foundation for later high level features.

API based html print over templating
------------

  Templating has many shortcut, it's so limiting :

* It reduced the features of the PL/SQL IDE, tags and PL/SQL messed together, the IDE can no longer do auto-format and well display, it can not compile directly (must firstly be pre-compiled to a standalone procedure)
* Templating can not support high level features of dynamic page generating, for example: array output for select options,checkboxes,radios,tr-tds.
* The dynamic page's half work is app logic process work over the html making work, while templating support html making work, it lowered the support for app logic process
* Templating can only convert PL/SQL server pages to plsql stored procedure and no packages, but package is just the best choice to implement application logic over standalone procedures.


  So PSP.WEB will not focus on PL/SQL html page templating. 

  For the cases when the dynamic page is mainly static html with little PL/SQL, I'll consider support some kind of templating. But I will not use "loadpsp" like method, you just deploy the .psp file in filesystem, nodeJS will monitor the change and automatically compile it to a hash-named standalone procedure.

### bonus feather for API html print

* array output for TDS, SELECT-OPTIONS, CHECKBOXES, RADIOS
* table print for select result set
* tree print for hierachical sql result set with level column
* very short code to specify a url
* relocatable url reference
* component css
* component css with external link
* css scalable for all length unit

separation of files out of db
-------------------------------

  Every site including dynamic site need static files. For uploaded files, usually there is no need to process them using pl/sql, they are just accessed as a whole lob. If we store the static files and uploaded files in oracle db, it has many shortcuts. as :

* files will occupy storage space, if you are using ORACLE XE, the space is limited, it will just compete space quota with table data.
* the files is just deployment copies from source, putting them in db will not gain the benefit of backup/restore of DB
* the creation/deletion/modification of the files will cause unnessary undo logs and redo logs suss raise the running overhead of DB
* ORACLE do not support any pre-compiler as for sass, less, stylus, coffee-script ..., to support it, files must be put outside of DB
* files is candidate for caching, so it's better to deploy them in front servers instead of the most backend DB servers.
* static file should use different host:port, so the browser can achieve higher concurrent requests, the static server can leverage CDN, and the dynamic server (PSP.WEB) can dedicated for dynamic content with maximum performance.


  When your PSP.WEB code print a,link,form,script,iframe,frame..., the url of the linked file is re-allocable by just configuration, and PSP.WEB let you use shortest string to specify the url by convention.


Leverage result cache
-----------------------

  No-in-db platform or app server can cache data from database, but integrity is not ensured. With ORACLE, we can take the feature of result-cache, so often used data can just cache in database, the PL/SQL will got fresh data surely.

  But ORACLE's result cache will invalidate after the table change, if one row changed, all result cache related to the table will invalidate, so it's too limiting. 

  So we invent a version based cache, we place result cache data onto package variables, every result cache data will have a version parameter and it will never invalided for its version, if the cache changed, the version store in GAC (global application context) that's identified by key is change.

Other Docs and references
============

* [License](license.html)
* [deployment](deployment.html) : How to install, configure and manage the PSP.WEB server.
* [coding_guide](coding_guide.html) : It's just begin to write.
* [history](history/history.html) : a brief description of ancestral versions PSP.WEB that's just extension of ORACLE's PSP.
* run demo with http://your_server/demo/index_b.frame
* [PL/SQL Developer][PL/SQL Developer] "Allround Automations"'s site.
* [Developing PL/SQL Web Applications](http://docs.oracle.com/cd/B28359_01/appdev.111/b28424/adfns_web.htm#g1026380) ORACLE's PSP introduction (for comparison only)
* [Oracle® HTTP Server mod_plsql User's Guide][mod_plsql] ORACLE's PSP introduction (for comparison only)
* [Competitive products for Oracle](http://www.orafaq.com/tools/competitive) (for comparison only)


**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>

[PL/SQL Developer]: http://www.allroundautomations.com/ "Allround Automations's site"
[mod_plsql]: http://docs.oracle.com/cd/B19306_01/server.102/b14337/toc.htm
