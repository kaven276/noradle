<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
*****************************************

<div id="title"> Deployment & Configuration & Administration </div>

  PSP.WEB is tested on ORACLE DATABASE 11g（EE & XE) and NodeJS v0.6.2 and v0.8.8.

brief steps guide
===========================

* (in os) install nodejs package (http://nodejs.org)
* (in os) install noradle (`npm -g install noradle`)
* (in oracle) run `sqlplus "/ as sysdba" @install.sql` to install at oracle side
* (in oracle) config `sever_control_t` --optional
* (in oracle) grant network ACL to PSP db user --optional
* (in oracle) check oracle database parameters (ensure enough job process, SGA space, ...)
* (in oracle) start oracle job servers (`k_pmon.run_job`)
* (in oracle) check `user_scheduler_jobs` and `user_scheduler_running_jobs` to see if noradle jobs are running
* (in os) config node gateway ( `npm c set noradle:key value`) --optional
* (in os) run node http gateway ( `npm start / npm start noradle`)
* (in browser) check http://localhost:8008/server-status
* (in browser) learn demo at http://localhost:8080/demo
* (in oracle) check pipe named "node2psp" to see server logs at oracle side

Install at oracle's side
=========================

## Install PSP.WEB engine schema objects and demo schema objects.

  Change working directory into oracle subdir of this project, use sqlplus to login into the target oracle database as sysdba, then execute install.sql script file. Example like this:

```
cd noradle/oracle
sqlplus "sys/password@targetdb as sysdba"
SQL> @install
```
Or if you are on the db server, simply run this.

```
cd noradle/oracle
sqlplus "/ as sysdba" @install.sql
```

  Note that the psp user and demo user should be created beforehand, then you will be prompted to specify the names of the two database users.
  Follow guide of the install scripts please, after it complete, check install.log.

## Grant right for oracle to NodeJS TCP/IP connection

  Oracle DB is able to make TCP/IP connection to outside world by `UTL_TCP` pl/sql API, but by default,
  oracle forbid to make connection to any address by network ACL rules , you must use `DBMS_NETWORK_ACL_ADMIN` package to create a new ACL to allow access to nodeJS listener. NodeJS http server will manage all the connections made by oracle, and use them as communication path for the http gateway behavior.The configuration script is as the following code:

Be sure connect as sys or other privileged db users in SQLPlus or other oracle clients, and execute the code below.

```
begin
	/* uncomment this when you want existing ACL "noradle.xml" to be removed first
	dbms_network_acl_admin.drop_acl(
		acl => 'noradle.xml'
	);
	*/
	dbms_network_acl_admin.create_acl(
		acl            => 'noradle.xml',
		description    => 'oracle2nodejs',
		principal      => 'PSP',
		is_grant       => true,
		privilege      => 'connect'
	);
	/* when ACL "noradle.xml" exists, execute .add_privilege is ok,
		for example, when you reinstall psp schema
	dbms_network_acl_admin.add_privilege(
		acl       => 'noradle.xml',
		principal => 'PSP',
		is_grant  => true,
		privilege => 'connect'
	);
	*/
	-- for each record in server_control_t, call assign_acl to grant network access right from oracle to nodejs
	dbms_network_acl_admin.assign_acl(
		acl => 'noradle.xml',
		host => '127.0.0.1'
	);
	commit;
end;
/
```

Note:

* "install.sql" will setup net ACL by default configuration, you may bypass this step.
* read http://oradoc.noradle.com/appdev.112/e10577/d_networkacl_adm.htm for reference
* "principal" must specify the schema(case sensitive, def to PSP) that hold the PSP.WEB engine software.
* "dbms_network_acl_admin.add_privilege" will grant right to other db user that act as PSP.WEB engine user.
* Notice: normally you will install only one version of Noradle, so ".add_privilege"can be bypassed.
* "host" in "dbms_network_acl_admin.assign_acl" specify where(dns/ip) the nodeJS http gateway is.
* if you have multiple nodejs gateway in multiple address, repeat ".assign_acl" with each of the addresses.

After done, oracle background scheduler processes (as Noradle server processes) have the right to make connection to
all your nodejs http gateways.

## Configure `server_config_t` table for Noradle server processes

After installation script runs, The `server_control_t` table is configured by the following insert statements.
You can modify the default configuration or add additional records to match your NodeJS http gateway reverse
connection listening addresses.

```plsql
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,
STATIC_URL, DBU_FILTER)
values ('runPSP4WEB', '127.0.0.1', 1522, 0, 12, 1000, '+0001 00:00:00', 'http://127.0.0.1:8000','(demo)');

insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,
STATIC_URL, DBU_FILTER)
values ('runCombined', '127.0.0.1', 1522, 6, 12, 1000, '+0001 00:00:00', '/fs','(demo)');

insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME, DBU_FILTER)
values ('db-driver', '127.0.0.1', 1523, 2, 6, 1000, '+0001 00:00:00','(demo)');
```

To let PSP.WEB known where the nodeJS http gateway is, You must specify `gw_host` and `gw_port` columns for `server_control_t`. The nodeJS http server as PL/SQL gateway is listening for oracle connection at tcp address of `gw_host:gw_port`.

* `gw_port` must match ip of the nodejs http gateway.
* `gw_port` must match Noradle.runXXX({oracle_port:xxx})

The above insert will create config records, you can create additional configuration by insert multiple records
 of `server_config_table`, and specify column `cfg_id` as the name of the new configuration. That way, you can allow multiple nodeJS gateways to reverse-connect to one oracle database.

For every records of `server_control_t`, call `dbms_network_acl_admin.assign_acl` for every different `gw_host`(or
add `gw_port`), to allow oracle server process make connection to the paired nodejs http gateway.


## Make sure there is enough processes/sessions and background job process for PSP.WEB service.

  The value `in server_control_t.min_servers` control how many server processes PSP.WEB use to service the client(through nodeJS gateway), but PSP.WEB server process is just oracle's background processes, the actual number of them is controled under the following oracle init parameters, so ensure it's set big enough to run the amount of PSP.WEB server processes required.

<dl>
<dt> `JOB_QUEUE_PROCESSES` </dt>
<dd>specifies the maximum number of processes that can be created for the execution of jobs.
<dd>It specifies the number of job queue processes per instance (J000, ... J999).
<dt> `PROCESSES` </dt>
	<dd>specifies the maximum number of operating system user processes that can simultaneously connect to Oracle.
	<dd>Its value should allow for all background processes such as locks, job queue processes,	and parallel execution processes.
<dt> `SESSIONS` </dt>
<dd>specifies the maximum number of database sessions that can be created in the system. Because every login requires a session,
 <dd> this parameter effectively determines the maximum number of concurrent users in the system.
</dl>

Note:

* To get the current value of the parameters above, use "show parameters {parameter-name}"
* To change the setting., use "alter system set {parameter-name}={value}"
	
	

## Start and Stop PSP.WEB server on oracle side

  PSP.WEB server is run as scheduler managed background job processes, They run as the PSP.WEB engine software database user, normally is "PSP". PSP.WEB provide `K_PMON` package to manager the server.

<dl>
<dt> `K_PMON.RUN_JOB`</dt>
<dd> It will run PSP.WEB's pmon as a deamon and start all the parallel server job processes
<dd> ".run_job" will check server_config_t, for each config record, start up ".min_servers" number of servers.
<dd> if any server quit for the reason of exception, ".max_request" reached, or ".max_lifetime" reached,
the monitor deamon will re-spawn new servers, try keep server quantity to ".min_servers'.
<dt> `K_PMON.STOP`
<dd> It will send signal to PSP.WEB'S pmon and server processes to let them to quit
</dl>

To start/stop PSP.WEB server, just login as PSP.WEB engine user (normally "PSP") in sqlplus, and execute `k_pmon.run_job/k_pmon.stop`. And then check State on the Oracle side.

1. check if oracle background job processes is running by the SQLs below (login as PSP user)
```
select * from user_scheduler_jobs;
select * from user_scheduler_running_jobs;
```
2. Read pipe named "node2psp" for any exception the Noradle servers encounters.
For example, if you use "PL/SQL Developer" IDE, you can go to menu "tools -> event monitor",
set "Event Type" to "pipe", "Event Name" to "node2psp",
press "Start" button to catch all the trace log info in the oracle side.

## Configure for the demo

The installation script will insert like this code below, update the prefix column value to the your real static
server root, so the demo for hwo to write simple shortest url code can be showed correctly.

	insert into ext_url_v(key, prefix) values('myself', 'http://localhost:81/');
	-- where the url prefix should specify the static server address, so the demo of URL will function

Note: It's not critical, and can be ignored.
	
Install at nodeJS's side
=========================

## Install nodeJS and npm

  See [nodeJS official website](http://nodejs.org/#download) for the guide of installation of NodeJS and NPM.

## SSL support (optional)

	# install openssl, and run
	openssl genrsa -out privatekey.pem 1024
	openssl req -new -key privatekey.pem -out certificate.csr
	openssl x509 -req -in certificate.csr -signkey privatekey.pem -out certificate.pem

## Start and Stop node gateway server

  PSP.WEB provide two types of gateway server that will route http requests to oracle plsql store procedures.
One is sole plsql page gateway server at lib/plsql.js, that's rely on NodeJS alone, and need no more other 3rd-party node modules.
The other is combined server at lib/combined.js that will serve both plsql dynamic page and static file. basicly, it rely on 3rd-party module connect.
We suggest to separate static server from main dynamic server, it will get better performance, concurrency, stability,
and more, you can use CDN for the static part.

  The oracle part is for oracle scheduler job processes to reverse connect to NodeJS,
so NodeJS can communicate to oracle, send request and receive reply.

```
var options = {...]

// start dynamic server page server
require('noradle').runPSP4WEB([options]);

// start server that serv both dynamic server page and static files
// This is most suitable to learn the demo
require('noradle').runCombined([options]);
```

or quickly run server with default configuration by this:
```
# cd project root
npm start
npm start noradle
npm run-script runCombined
npm run-script runPSP4WEB
```
Note:

1. `npm start` must run at the path of noradle
2. `npm start noradle` will run globally install noradle, for combined server only
3. all the ways of npm run servers can be set configuration by `npm c set noradle:key value`

Note: If you run plsql dynamic page only, run Noradle.runPSP4WEB, and it rely on pure NodeJS installation only,
no additional node modules are required.

## use server configuration options

All runXXX statements can take options to fine tune the server behavior,
 If no arguments be given, Noradle will run servers with default settings,
which is from 'lib/cfg.js', like this:

```
module.exports = {
  oracle_port : 1522, // accept oracle reversed connection to establish communication path between nodeJS and oracle
  http_port : 8080, // port that accept browser(client) http request
  https_port : 443, // port that accept browser(client) https request
  static_port : 8000, // port that serve static files solely
  static_ssl_port : 8443, // port that serve static files solely
  ssl_key : undefined, // server side ssl key text for https service
  ssl_cert : undefined, // server side ssl certification text for https service
  accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
  check_session_hijack : false, // if enable the browser session hijack detection

  plsql_mount_point : '/', // where to mount all plsql page for combined server
  file_mount_point : '/fs', // where to mount all static file for combined server

  favicon_path : path.join(__dirname, '../public/favicon.ico'), // where is the site's favicon icon at
  favicon_max_age : 24 * 60 * 60, // how long is browser hold the favicon in cache
  static_root : path.join(__dirname, '../static'), // specify where the static file root directory is at
  show_dir : false, // by default, do not expose directory structure for end users
  upload_dir : path.join(__dirname, '../upload'), // specify upload root directory
  upload_depth : 2, // can be 1,2,3,4, to split 16 byte random string to parts to avoid too big directory

  zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
  zip_min_radio : 2 / 3, // if compressed data length is less than the setting, compressed data can be used for cache
  use_gw_cache : true, // if NodeJS http gateway will cache response and serve future request when cache hit

  host_base_parts : 2, // specify the number of suffix parts in host dns name, the remaining head in host is host prefix
  server_name : 'Noradle - PSP.WEB', // specify the value of http response header "x-powered-by“

  DBPoolCheckInterval : 1000, // interval(in milliseconds) db pool monitor checks "executing-but-no-response" timeouts
  ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
  FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request

  NoneBrowserPattern : /^$/, // all user-agent match this will not generate msid/bsid cookies automatically.
};
```

NOTE: "lib/cfg.js" set the default configuration for NodeJS side server, it's under version control and belong to the
product. So do not touch it if you don't want lose your work when update PSP.WEB to new version.
All the setting in lib/cfg.js has remarks and it's easy to understand.

If you run noradle http gateway by `npm start` or `npm run-scripts`, you can configure by `npm c set noradle:key
value`.

## Check if all is well

* browse http://your_test_server:port/**server_status** to see the status of the server
* browse http://your_test_server:port/demo to see the demo app
* run "test/call_plsql_for_result_sets.js" to see if node-to-oracle db driver is ok
* see pipe named "node2psp" for any exception the Noradle servers encounters
* check the following SQLs to see if Noradle server jobs is created and running

```
select * from user_scheduler_jobs;
select * from user_scheduler_running_jobs;
```

## Install/Run static server nodeJS package (optional)

```
// start static file server (for memo app's static files)
require('noradle').runStatic([options]);

// start static file server (include Noradle docs at /doc/index.html)
require('noradle').runStaticAdv([options]);
```

or quickly run static server with default configuration by this:

```
# cd project root
npm run-script runStatic
npm run-script runStaticAdv
```

  You may run static file server with plsql dynamic page server(Noradle.runCombined) or run it separately(Noradle
  .runStatic,Noradle.runStaticAdv). In both case,
you will run static file server we provide that's based on nodeJS and connect module,
you can also run it on any other static http server like Apache, lighttpd, Ngix, IIS, ...
When you deploy static file separately, set `server_control_t.static_url` the value that point to the url of the static
 web server please.

When you run combined server or run my static server, you need to install connect module.
If you want to serve psp.web documentation, you need to install module marked, so that the .md docs can be converted to html.
If you want some of pre-translation function like markdown2html, stylus2css, you can add them as well. Use the following command to install them, they are all in the [NPM registry](http://search.npmjs.org/).

	npm install

  For normal use, static.js is enough, For advanced static server, it can provide services to PSP.WEB's documentation by converting .md files to .html files, So you can read PSP.WEB documentation at http://your-static-server/doc/index.html.

Noradle as a data source
==========================

## as a nodejs to oracle database access driver

* Configure `server_config_t` to match "test/call_plsql_for_result_sets.js" listening address.
*	run "test/call_plsql_for_result_sets.js" to see if node-to-oracle db driver is ok

## as json source

- [ ] wait please
- [x] wait please

**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>
