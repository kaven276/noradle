<script src="header.js"></script>

<div id="title"> Deployment & Configuration & Administration </div>

  Noradle is tested on ORACLE DATABASE 11g（EE & XE) and NodeJS and v0.10.x.

  Few code should be tuned to adapted to ORACLE 10G,
I'm just lack of time to make it work on 10G.

brief steps guide
===========================

* (in os) install [nodejs](http://nodejs.org) package (http://nodejs.org)
* (in os) install noradle `npm -g install noradle`
* (in oracle) run `sqlplus "/ as sysdba" @install.sql` to install core oracle schema objects
* (in oracle) config `sever_control_t` --optional
* (in oracle) grant network ACL to PSP db user --optional
* (in oracle) check oracle database parameters (ensure enough job process, SGA space, ...)
* (in oracle) start oracle job servers (`k_pmon.run_job`)
* (in oracle) check `user_scheduler_jobs`, `user_scheduler_running_jobs` or `v$session` to see if noradle jobs are running
* (in os) install [demo](https://github.com/kaven276/noradle-demo) `npm -g install noradle-demo`
* (in oracle) in noradle-demo, run `sqlplus "/ as sysdba" @install.sql` to install noradle demo schema objects
* (in browser) check http://localhost:8888/server-status
* (in browser) learn demo at http://localhost:8888/demo
* (in oracle) check oracle pipe named "node2psp" to see server logs at oracle side

Note: host, port should be changed for your own deploy environment.

Install at oracle's side
=========================

## Install PSP.WEB engine schema objects and demo schema objects.

  Change working directory into oracle subdir of this project,
use sqlplus to login into the target oracle database as sysdba,
then execute install.sql script file. Example like this:

```
cd noradle/oracle
sqlplus "sys/password@targetdb as sysdba"
start install
```

Or if you are on the db server, simply run this.

```
cd noradle/oracle
sqlplus "/ as sysdba" @install.sql
```

or all-in-one way

```
cd noradle/oracle && sqlplus "sys/password@targetdb as sysdba" @install
```

  Similar as installation of noradle core schema,
install [noradle-demo](https://www.npmjs.com/package/noradle-demo) afterward.

  Note that the psp user and demo user should be created beforehand,
then you will be prompted to specify the names of the two database users.
Follow guide of the install scripts please, after it complete, check install.log.

## Grant right for oracle to NodeJS TCP/IP connection

  Oracle DB is able to make TCP/IP connection to outside world by `UTL_TCP` pl/sql API,
but by default,
oracle(11g and up) forbid to make connection to any address by network ACL rules,
you must use `DBMS_NETWORK_ACL_ADMIN` package to create a new ACL to allow access to nodeJS listener.
NodeJS http server will manage all the connections made by oracle,
and use them as communication path for the http gateway behavior.
The configuration script is as the following code:

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
	-- or call assign_acl to grant network access to all ip address
	dbms_network_acl_admin.assign_acl(
		acl => 'noradle.xml',
		host => '*'
	);
	commit;
end;
/
```

Note:

* "install.sql" will setup net ACL by default configuration, you may bypass this step.
* read http://oradoc.noradle.com/appdev.112/e10577/d_networkacl_adm.htm for reference
* "principal" must specify the schema(case sensitive, def to PSP) that hold the noradle core schema.
* "dbms_network_acl_admin.add_privilege" will grant right to other db user that act as PSP.WEB engine user.
* Notice: normally you will install only one version of Noradle, so ".add_privilege"can be bypassed.
* "host" in "dbms_network_acl_admin.assign_acl" specify where(dns/ip) the nodeJS http gateway is.
* if you have multiple nodejs gateway in multiple address, repeat ".assign_acl" with each of the addresses.

After done, oracle background scheduler processes (as Noradle server processes) have the right to make connection to
all your nodejs sever process who listen for oracle connection.

Note: you must be sure that oracle XML-DB is installed, see rem code in install.sql if XML-DB is not installed,

```
prompt xmldb must be installed already
prompt see and run $ORACLE_HOME/rdbms/admin/catqm.sql
Rem    NAME
Rem      catqm.sql - CAtalog script for sQl xMl management
Rem
Rem    DESCRIPTION
Rem      Creates the tables and views needed to run the XDB system
Rem      Run this script like this:
Rem        catqm.sql <XDB_PASSWD> <TABLESPACE> <TEMP_TABLESPACE> <SECURE_FILES_REPO>
Rem          -- XDB_PASSWD: password for XDB user
Rem          -- TABLESPACE: tablespace for XDB
Rem          -- TEMP_TABLESPACE: temporary tablespace for XDB
Rem          -- SECURE_FILES_REPO: if YES and compatibility is at least 11.2,
Rem               then XDB repository will be stored as secure files;
Rem               otherwise, old LOBS are used. There is no default value for
Rem               this parameter, the caller must pass either YES or NO.
@@grant_network.sql
```

reference:

* [DBMS_NETWORK_ACL_ADMIN](http://oradoc.noradle.com/appdev.112/e10577/d_networkacl_adm.htm)
* [Managing Fine-Grained Access in PL/SQL Network Utility Packages](http://oradoc.noradle.com/network.112/e10574/authorization.htm#DBSEG40012)

## Configure `server_config_t` table for Noradle server processes

After installation script runs, The `server_control_t` table is configured by the following insert statements.
You can modify the default configuration or add additional records to match your NodeJS http gateway reverse
connection listening addresses.

```sql
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,IDLE_TIMEOUT)
values ('demo', '127.0.0.1', 1522, 4, 12, 1000, '+0001 00:00:00', 300);
```

To let PSP.WEB known where the nodeJS client is, You must specify `gw_host` and `gw_port` columns for `server_control_t`. The nodeJS http server as PL/SQL gateway is listening for oracle connection at tcp address of `gw_host:gw_port`.

* `gw_port` must match ip of the nodejs listening address.
* `gw_port` must match `new noradle.DBPool(port,option)`
* `min_servers` keep this amount of oracle background server processes for this config record
* `max_servers` not used yet
* `max_requests` when a job process handle this amount of servlet request, process will quit and restart to release resource.
* `max_lifetime` when a job process live over this amount of time, process  will quit and restart to release resource.
* `idle_timeout` when a job process can not receive any incoming request data over this amount of time,
job process will treat it as connection lost, so disconnect an reconnect to nodejs.
For nodejs and oracle behind NAT, this setting should be set to avoid endless waiting on a lost NAT state connection.

The above insert will create configuration records,
you can create additional configuration by insert multiple records of `server_config_table`,
and specify column `cfg_id` as the name of the new configuration.
That way, you can allow multiple nodeJS gateways to reverse-connect to one oracle database.

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

	insert into ext_url_v(key, prefix) values('myself', '/f');
	-- where the url prefix should specify the static server address, so the demo of URL will function

Note: It's not critical, and can be ignored.
	
Install at nodeJS's side
=========================

## Install nodeJS and npm

  See [nodeJS official website](http://nodejs.org/download/) for the guide of installation of NodeJS and NPM.

## any access to oracle require a DBPool instance

`new noradle.DBPool(port, options)`

port : default to 1522,  accept oracle reversed connection to establish communication path between nodeJS and oracle

options

* DBPoolCheckInterval : 1000, // interval(in milliseconds) db pool monitor checks "executing-but-no-response" timeouts
* ExecTimeout : 3000, // over this threshold(in milliseconds), if execution got no response, timeout it for RC recycling
* FreeConnTimeout : 3000, // over this threshold(in milliseconds), if no free db connection to use, timeout the request
```

## configure noradle HTTP service handle into a node http server

 Example as below, `plsqlServletHandler` is standard connect/express compliant http handler,
specification as `function handler(request, response, next)`.
It can be put in `http.createServer(*)` or `connect.use(*)`, `express.use(*)`,
so you can integrate noradle servlet handler in a complex node app,
but noradle doesn't support a direct use to run a http server.

`noradle.handlerHTTP(dbPool, options)`

options (most use in handlerHTTP plugins)

* server_name : 'Noradle - PSP.WEB', // specify the value of http response header "x-powered-by“
* favicon_path : path.join(__dirname, '../public/favicon.ico'), // where is the site's favicon icon at
* upload_dir : path.join(__dirname, '../upload'), // specify upload root directory
* upload_depth : 2, // can be 1,2,3,4, to split 16 byte random string to parts to avoid too big directory
* host_base_parts : 2, // specify the number of suffix parts in host dns name, the remaining head in host is host prefix
* zip_threshold : 1024, // if a Content-Length > this, Noradle psp.web will try to compress the response to client
* zip_min_radio : 2 / 3, // if compressed data length is less than the setting, compressed data can be used for cache
* accept_count : 10, // accept connection queue limits, when all oracle socket is in use, requests will go to queue.
* check_session_hijack : false, // if enable the browser session hijack detection
* use_gw_cache : true, // if NodeJS http gateway will cache response and serve future request when cache hit
* NoneBrowserPattern : /^$/, // all user-agent match this will not generate msid/bsid cookies automatically.

NOTE: "lib/cfg.js" set the default configuration for NodeJS side server, it's under version control and belong to the
product. So do not touch it if you don't want lose your work when update PSP.WEB to new version.
All the setting in lib/cfg.js has remarks and it's easy to understand.

```javascript
var cfg = require('./cfg.js')
  , http = require('http')
  , noradle = require('noradle')
  ;

var dbPool = new noradle.DBPool(cfg.oracle_port);

var plsqlServletHandler = noradle.handlerHTTP(dbPool);

var server = http.createServer(plsqlServletHandler).listen(cfg.http_port, function(){
  console.log('http server is listening at ' + cfg.http_port);
});
```

  [noradle-demo](https://github.com/kaven276/noradle-demo)

## use noradle NDBC to access oracle

`var dbc = new Noradle.NDBC(dbPool, defaultParams)`

`dbc.call(procedureName, parameters)`

internal control parameters

* __parse : if parse response according to **Content-type**
* __repeat : if repeat the call to the same procedure with same parameter

```javascript
var Noradle = require('noradle')
  , dbPool = new Noradle.DBPool(listen_oracle_port)
  , dbc = new Noradle.NDBC(dbPool, {
    x$dbu : dbUser
  })
  ;
dbc.call('adm_export_schema_h.unit_list', {
  __parse : true,
  z$filter : '%',
  after : after
}, function(status, headers, units){
  if (status !== 200) {
    console.error(units);
    process.exit(status);
    return;
  }
  ...
});
```



## Check if all is well

* browse http://your_test_server:port/server_status to see the status of the server
* browse http://your_test_server:port/demo to see the demo app
* run "test/NDBC/call_plsql_for_result_sets.js" to see if node-to-oracle db driver is ok
* run "test/NDBC/monitor_xxx.js", and access msg_b.xxx page to see if oracle can send call-out message to node
* see pipe named "node2psp" for any exception the Noradle servers encounters
* check the following SQLs to see if Noradle server jobs is created and running

```sql
select * from user_scheduler_jobs;
select * from user_scheduler_running_jobs;
select * from v$session a where a.client_info like 'Noradle-%' order by a.client_info asc;
```

<script src="footer.js"></script>
