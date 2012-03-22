<link type="text/css" rel="stylesheet" href="doc.css" />
<style>
div.path{display:inline-block;font-size:smaller;}
</style>

<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title"> Introduction to PSP.WEB   </div>

What's PSP.WEB
===============

  PSP.WEB is the short term of "PL/SQL Stored Procedure for WEB" or "PL/SQL SERVER PAGES for WEB".

  PSP.WEB use PL/SQL programing language to do web development, It's a language of DB stored procedure that is different from most of the other web developing languages and platforms such as J2EE .Net, PHP, RUBY. with PSP.WEB platform, PL/SQL can use PSP.WEB APIs to gain http request info, do nature data processing, and print page to http response. It's the most proper way to develop database(oracle) based web applications. 

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

  PL/SQL has natural advantages, using PL/SQL for developing web site/application is seductive. But naturally, PL/SQL have no touch with http protocol, If we provide a http listener (such as nodeJS based) that can communicate with oracle PL/SQL, we can invert a whole new stored-procedure based web platform that is the most integrated platform taking both application layer and database layer together. That is just the way PSP.WEB do. Now PL/SQL leverage it's power to web development in it's most. All the sections below will tell you the unique features of PSP.WEB that other web-dev techs do not reach.

## avoid database connection related work

  Since all code are stored procedure that run in DB, there is **no sql driver or database client driver need**, and so, there is no any connection configuration work that other web platform need to do. PSP.WEB will launch a set of background worker job for http processing, they are just pool of servers, PSP.WEB will alway select the first free worker process, minimize the process switch work. This is really a kind of **natural connection pool with zero configuration**.

## internal network cost is minimized

  PL/SQL run within DB, they are run directly on database server processes (exactly say on background job processes), there is no traditional DB client-server cross process communication. PL/SQL just use QUERY or DML ** to manipulate data in-process **.

  PSP.WEB use NodeJS as http listener, NodeJS is act as the http gateway for PL/SQL, NodeJS gateway will parse the http request, transform it to a easy to read format and send them to one of the free PSP.WEB worker job process using TCP, PL/SQL will output the response through NodeJS gateway to the final client like browsers. The communication between http listener NodeJS gateway and PSP.WEB worker job processes is simple and low cost, since they communicate with **minimal of roundtrips**, commonly, there is one tcp/id package for request and there is one or several tcp/ip packages for response, And there is just raw binary data stream for response from PL/SQL, there is **no data serialization and parsing** at the two ends as all of the sql driver will do.

## PL/SQL is the best way to process data with embed sql. 

  Use %rowtype to declare variables is much better than xDBC, EMBED-x and OR-Mapping since all other none-store-procedure based application server will declare data structures according to database tables and it' so redundant and need to carefully map the two different data types, use PL/SQL there is **minimal of data structure declaration**. 

  SQL-binding is so good, you have no change to submit string-spelled sql text, all sql is parsed in PL/SQL already, all sql use bound parameter already, no sql-infection attack possible, no repeating sql parsing possible.

## online upgrade is supported

  PL/SQL has auto dependency management, if a object that a PL/SQL unit referred is changed, ORACLE will recompile the PL/SQL unit automatically, so you can **bug-fix or upgrade your code online** without breaking your service. Notice that most of the application server platform do not support on-line update or safe on-line update.

## Has very handy IDE for both PL/SQL coding and data manipulation

  There is a full featured PL/SQL IDE called [** PL/SQL developer **] [PL/SQL Developer], It's as good as the most used IDE such as Eclipse ..., but with data manipulation integrated.

  Traditionally, you use different developing tool and IDEs for application language and database, such as use Eclipse and SQL deveoper both. Now you need only one IDE - "PL/SQL developer".

## In-DB result cache with low design/coding cost

  ORACLE support result-cache, but PSP.WEB provide **row level versioned result_cache**, often used data can be result cached such as user profile, terminal properties. None stored procedure will do hard to provide data cache and it's too complex.


Compare to Oracle's PSP
=================

  Someone will tell me that ORACLE has PL/SQL SERVER PAGES support by [mod_plsql] [mod_plsql] within Apache since 8i. Now I tell you ORACLE's PSP is so limited, and it is unchanged for many years and almost frozen. Below I list some of it's limits.

* Installation of Companion CD for 10G and Web Tier for 11G is tedious, actually only a bit of part is for PSP, but you are force to install all of them.
* Configuration Apache is a burden, most of configuration is not not related to PSP, but you must do it.
* Configuration one dad for one database user or application, can not reuse connection for different DADs
* The HTP and HTF API is not natural and hard to use
* Can not provide exactly every http request header info
* Can not provide http request body info
* Front-end web server can not support well for keep-alive requests
* Do not support streaming of http response
* Every http request will form a dynamic spelled anonymous sql, cause oracle to low hit-rate of shared-pool
* html form parameter must be have corresponding procedure parameter with the same name, it's so rigid, fragile, and can not span across PL/SQL call stack.

  PSP.WEB removed the limited burdened with ORACLE's PSP, PSP.WEB has simple installation and configuration, support almost full http protocol support with easily used API and framework, it's no longer a sugar toy as PSP


Other Docs and references
============

* [deployment.md](deployment.html) : How to install, configure and manage the PSP.WEB server.
* [coding_guide](coding_guide.html) : It's just begin to write.
* [history.md](history/history.html) : a brief description of ancestral versions PSP.WEB that's just extension of ORACLE's PSP.
* run demo with http://your_server/demo/index_b.frame
* [PL/SQL Developer][PL/SQL Developer] "Allround Automations"'s site.
* [Developing PL/SQL Web Applications](http://docs.oracle.com/cd/B28359_01/appdev.111/b28424/adfns_web.htm#g1026380) ORACLE's PSP introduction
* [Oracle® HTTP Server mod_plsql User's Guide][mod_plsql] ORACLE's PSP introduction
* [Competitive products for Oracle](http://www.orafaq.com/tools/competitive)

[PL/SQL Developer]: http://www.allroundautomations.com/ "Allround Automations's site"
[mod_plsql]: http://docs.oracle.com/cd/B19306_01/server.102/b14337/toc.htm
