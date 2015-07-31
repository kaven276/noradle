<script src="header.js"></script>

<div id="title"> Deployment & Configuration & Administration </div>

  Noradle is tested on ORACLE DATABASE 11g（EE & XE) and NodeJS on v0.11.2.

  Few code should be tuned for adapting to ORACLE 10G,
But I'm just lack of time to make it work on 10G.

brief steps guide
===========================

* (in os) install [nodejs](http://nodejs.org) package (http://nodejs.org)
* (in os) install noradle `npm -g install noradle`, it will be installed where `npm -g root` print
* (in oracle) `cd ` \``npm -g root`\``/noradle/oracle` and run `sqlplus "/ as sysdba" @install.sql` 
 to install supporting objects in oracle
* (in oracle) config `sever_control_t` table, --optional, set where to connect to dispatchers
* (in oracle) grant network ACL to PSP db user to access dispatcher addresses specified in `server_control_t` --optional 
* (in oracle) check oracle database parameters (ensure enough job process, SGA space, ...)
* (in oracle) start oracle job servers (`exec k_pmon.run_job`)
* (in oracle) check `user_scheduler_jobs`, `user_scheduler_running_jobs` or `v$session` to see if noradle jobs are running
* (in os) start noradle dispatcher
* (in browser) start dispatcher monitor and check http://localhost:port/getOraSessions to see if dispatcher got oracle connections
* (in os) install [demo](https://github.com/kaven276/noradle-demo) `npm -g install noradle-demo`
* (in oracle) in noradle-demo, run `sqlplus "/ as sysdba" @install.sql` to install noradle demo schema objects
* (in browser) check http://localhost:8888/server-status (obsolete)
* (in browser) check dispatcher monitor http://localhost:port/getClients to see if demo connected to dispatcher
* (in browser) learn demo at http://localhost:8888/demo
* (in oracle) check oracle pipe named "node2psp" to see server logs at oracle side

Note: host, port should be changed for your own deploy environment.

Install at oracle's side
=========================

## Install NORADLE engine schema objects and demo schema objects.

  Change working directory into oracle subdir of this project,
use sqlplus to login into the target oracle database as sysdba,
then execute install.sql script file. Example like this:

```
cd `npm -g root`
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

Note: noradle core objects will be installed into schema named 'PSP' by default.  
**PSP** is abbreviation for "PL/SQL Server Page", just like PHP, JSP does.  
"psp user" stand for noradle core schema name in noradle document.

install [noradle-demo](https://www.npmjs.com/package/noradle-demo) afterward the same way.

  Note that the psp user and demo user should be created beforehand,
then you will be prompted to specify the names of the two database users.
Follow the guide in the install scripts please, after it complete, check install.log.

## Grant right for oracle to NodeJS TCP/IP connection

  Oracle DB is able to make TCP/IP connection to outside world by `UTL_TCP` pl/sql API,
but by default,
oracle(11g and up) forbid to make connection to any address by network ACL rules,
you must use `DBMS_NETWORK_ACL_ADMIN` package to create a new ACL to allow access to nodejs(noradle listener).
NodeJS dispatcher server will manage all the connections made by oracle,
and use them as communication path for the nodejs clients.
The configuration script is as the following code:

Be sure to connect as sys or other privileged db users in SQLPlus(or other oracle clients), and execute the code below.

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
* "dbms_network_acl_admin.add_privilege" will grant right to other db user that act as NORADLE engine user.
* Notice: normally you will install only one version of NORADLE, so ".add_privilege"can be bypassed.
* "host" in "dbms_network_acl_admin.assign_acl" specify where(dns/ip) the NORADLE dispatcher is.
* if you have multiple NORADLE dispatcher in multiple address, repeat ".assign_acl" with each of the addresses.

After done, oracle background scheduler processes (as Noradle server processes) have the right to make connection to
all your nodejs NORADLE dispatcher sever process who listen for oracle connection.

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

```sql
insert into SERVER_CONTROL_T (CFG_ID, GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME,IDLE_TIMEOUT)
values ('demo', '127.0.0.1', 1522, 4, 12, 1000, '+0001 00:00:00', 300);
```

To let NORADLE known where the dispatcher is, You must specify `gw_host` and `gw_port` columns for `server_control_t`.  
The dispatcher is listening for oracle connection at tcp address of `gw_host:gw_port`.

* `cfg_id` configuration name
* `gw_host` must match ip of the NORADLE dispatcher listening address.
* `gw_port` must match `noradle.DBDriver.connect([port, host],option)`, the dispatcher listening port
* `min_servers` keep this amount of oracle background server processes for this config record
* `max_servers` not used yet
* `max_requests` when a job process handle this amount of servlet request, process will quit and restart to release resource.
* `max_lifetime` when a job process live over this amount of time, process  will quit and restart to release resource.
* `idle_timeout` when a job process can not receive any incoming request data over this amount of time,
job process will treat it as connection lost, so disconnect and reconnect to nodejs.
For nodejs and oracle behind NAT, this setting should be set to avoid endless waiting on a lost NAT state connection.
* `disabled` when not null or set to 'Y', this config is ignored by K_PMON

The above insert will create configuration records,
you can create additional configuration by insert multiple records of `server_config_table`,
and specify column `cfg_id` as the name of the new configuration.
That way, you can allow multiple dispatchers as pathways to access one oracle database.

For every records of `server_control_t`, call `dbms_network_acl_admin.assign_acl` for every different `gw_host`(or
add `gw_port`), to allow oracle server process make connection to the corresponding dispatcher.


## Make sure there is enough processes/sessions and background job process for PSP.WEB service.

  The value in `server_control_t.min_servers` control how many server processes 
a NORADLE dispatcher use it to service its clients, 
but NORADLE server process is just oracle's background processes,
the actual number of them is limited under the following oracle init parameters,
so ensure it's set big enough to run the amount of oracle server processes required.

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
	

## Configure for the demo

The installation script will insert data like this code below, 
update the prefix column value to the your real static server root, 
so the demo for hwo to write simple shortest url code can be showed correctly.

	insert into ext_url_v(key, prefix) values('myself', '/f');
	-- where the url prefix should specify the static server address, so the demo of URL will function

Note: It's not critical, and can be ignored.
	
Start all servers
=========================

## start OSPs

Start and Stop NORADLE OSPs on oracle side

  NORADLE OSPs is just a bunch of background job processes managed by oracle dbms_scheduler , 
They run as the NORADLE engine software database user, normally is "PSP".
NORADLE provide `K_PMON` package to manager the server processes.

<dl>
<dt> `K_PMON.RUN_JOB`</dt>
<dd> It will run NORADLE's pmon as a deamon and start all the parallel server job processes
<dd> ".run_job" will check server_config_t, for each config record,  
start up ".min_servers" number of servers.
<dd> if any server quit for the reason of exception, ".max_requests" reached, or ".max_lifetime" reached,  
the monitor deamon will re-spawn new servers,  
try keep server quantity to ".min_servers'.
<dt> `K_PMON.STOP`
<dd> It will send signal to NORADLE'S pmon and all server processes to tell them to quit
</dl>

To start/stop NORADLE OSPs, just login as NORADLE engine user (normally "PSP") in sqlplus,  
and execute `k_pmon.run_job/k_pmon.stop`.  
Then check State on the Oracle side.

check if oracle background job processes is running by the SQLs below (login as PSP user)

```
select * from user_scheduler_jobs a where a.job_name like 'Noradle-%';
select * from user_scheduler_running_jobs a where a.job_name like 'Noradle-%';

select a.client_info, a.module, a.action, a.*
  from v$session a
 where a.status = 'ACTIVE'
   and a.client_info like 'Noradle-%'
 order by a.client_info asc;
```

Read pipe named "node2psp" for any exception the Noradle servers encounters.  
For example, if you use "PL/SQL Developer" IDE, you can go to menu "tools -> event monitor",  
set "Event Type" to "pipe", "Event Name" to "node2psp",  
press "Start" button to catch all the trace log info in the oracle side.  

## start noradle dispatcher

run `noradle-dispatcher [listen_port:=1522] [client_config]`

* listen_port: where dispatcher will listen at, default to 1522
* client_config: file path where client configuration file is at, no default value,  
 if not specified, `{cid:"demo",passwd:"demo"}` is used as client configuration.

note: set environment variable listen_port/client_config have the same effect as cmd arguments,
but have lower priority

## start noradle monitor

run `noradle-monitor [dispatcher_addr:=1522] [http_listen_addr:=1520]`

* dispatcher_addr: where to connect to dispatcher, format as `port` or `port:ip`, default to 1522
* http_listen_addr: the http listening port for monitor, default to 1520

note: set environment variable dispatcher_addr/http_listen_addr have the same effect as cmd arguments,
but have lower priority

access the monitor web url to see the run-time info of the target dispatcher

* http://localhost:1520/getOraSessions
* http://localhost:1520/getClientConfig
* http://localhost:1520/getClients

note: localhost:1520 should be replaced by monitor_host:monitor_port

## start noradle demo server

run `noradle-demo [dispatcher_addr:=1522] [http_listen_addr:=8888]`

* dispatcher_addr: where to connect to dispatcher, format as `port` or `port:ip`, default to 1522
* http_listen_addr: the http listening port for demo web server, default to 8888

browse <http://localhost:8888/demo/> to see the demo app

note: localhost:888 should be replaced by demo_host:demo_port

## Check if all is well other ways

* run "test/NDBC/call_plsql_for_result_sets.js" to see if node-to-oracle db driver is ok
* run "test/NDBC/monitor_xxx.js", and access msg_b.xxx page to see if oracle can send call-out message to node
* see pipe named "node2psp" for any exception the Noradle servers encounters

<script src="footer.js"></script>
