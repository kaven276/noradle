<link type="text/css" rel="stylesheet" href="doc.css" />

<div id="title"> Deployment & Configuration & Administration of PSP.WEB  </div>

Install at oracle's side
===

## Install PSP.WEB engine schema objects and demo schema objects.

  Change working directory into oracle, use sqlplus to login into the target oracle database as sysdba, then execute install.sql script file. Example like this:

	sqlplus "sys/password@targetdb as sysdba"
	SQL> @install

  Note that the psp user and demo user should be created beforehand, then you will be prompted to specify the names of the two database users.

## Configure oracle to nodeJS TCP/IP connection

  Oracle DB is able to make TCP/IP connection to outside world by `UTL_TCP` pl/sql API, but by default, oracle forbit network ACL to make connection to any address, you must use `DBMS_NETWORK_ACL_ADMIN` package to create a new ACL to allow access to nodeJS listener. NodeJS http server will manage all the connections made by oracle, and use them as communication path for the http gateway behavior.The configuration script is as the following code:

	exec dbms_network_acl_admin.create_acl('pwgw.xml','oracle2nodejs',principal => 'PSP',is_grant => true,privilege=> 'connect');
	-- dbms_network_acl_admin.add_privilege('pwgw.xml',principal => 'PSP2',is_grant => true,privilege => 'connect')
	exec dbms_network_acl_admin.assign_acl(acl => 'pwgw.xml', host => '192.168.177.1')
	commit;
	
	-- The "principal" parameter in "dbms_network_acl_admin.create_acl" must specify the schema that hold the PSP.WEB engine software, it's case sensitive. use "dbms_network_acl_admin.add_privilege" to grant right to other db user that act as PSP.WEB engine user.
	-- The "host" parameter in "dbms_network_acl_admin.assign_acl" must specify where the nodeJS http gateway is for dns/hostname or ip address.

## Configure core parameter for server_config_t table

	Upon completion of installation, The SERVER_CONTROL_T table is configured by the following insert statement

	insert into SERVER_CONTROL_T (GW_HOST, GW_PORT, MIN_SERVERS, MAX_SERVERS, MAX_REQUESTS, MAX_LIFETIME, STATIC_URL)
	values ('127.0.0.1', 1522, 6, 12, 1000, '+0001 00:00:30','http://127.0.0.1:81');	

  To let PSP.WEB known where the nodeJS http gateway is, You must specify `GW_HOST and GW_PORT columns for SERVER_CONTROL_T`. The nodeJS http server as PL/SQL gateway is listening for oracle connection at tcp address of `GW_HOST:GW_PORT`.


## Make sure there is enough processes/sessions and background job process for PSP.WEB service.

  The value `in SERVER_CONTROL_T.MIN_SERVERS` control how many server processes PSP.WEB use to service the client(through nodeJS gateway), but PSP.WEB server process is just oracle's background processes, the actual number of them is controled under the following oracle init parameters, so ensure it's set big enough to run the amount of PSP.WEB server processes required.

	* JOB_QUEUE_PROCESSES
		specifies the maximum number of processes that can be created for the execution of jobs. It specifies the number of job queue processes per instance (J000, ... J999). 
	* PROCESSES
		specifies the maximum number of operating system user processes that can simultaneously connect to Oracle. Its value should allow for all background processes such as locks, job queue processes, and parallel execution processes.
	* SESSIONS
	specifies the maximum number of database sessions that can be created in the system. Because every login requires a session, this parameter effectively determines the maximum number of concurrent users in the system.

  To know the current value of the parameters above, use "show parameters {parameter-name}"

  To change the setting., use "alter system set {parameter-name}={value}"
	
	

## Start and Stop PSP.WEB server on oracle side

  PSP.WEB server is run as scheduler managed background job processes, They run as the PSP.WEB engine software database user, normally is "PSP". PSP.WEB provide `K_PMON` package to manager the server.

	K_PMON.RUN_JOB : It will run PSP.WEB's pmon as repeating BG job and start all the parallel server job processes
	K_PMON.STOP : It will send signal to PSP.WEB'S pmon and server processes, and then they will quit

  To start/stop PSP.WEB server, just login as PSP.WEB engine user (normally "PSP") in sqlplus, and execute `k_pmon.run_job and k_pmon.stop`.


## Configure for the demo

	insert into ext_url_v(key, prefix) values('myself', 'http://localhost:81/');
	where the url prefix should specify the static server address, so the demo of URL will function
	
	
Install at nodeJS's side
===

## Install nodeJS and npm

## Install static server nodeJS package

  For advanced static server, it can provide services to PSP.WEB's documentation by converting .md files to .html files.

## Start and Stop node gateway server

	 node lib/plsql_gateway.js will start the server