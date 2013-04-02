declare
	ex_exist exception;
	pragma exception_init(ex_exist, -31003);
begin
	-- uncomment this when you want existing ACL "noradle.xml" to be removed first
	-- dbms_network_acl_admin.drop_acl(acl => 'noradle.xml');
	begin
		dbms_network_acl_admin.create_acl(acl         => 'noradle.xml',
																			description => 'oracle2nodejs',
																			principal   => 'PSP',
																			is_grant    => true,
																			privilege   => 'connect');
	exception
		when ex_exist then
			null;
	end;
	-- when acl "noradle.xml" exists, execute .add_privilege is ok,
	-- for example, when you reinstall psp schema
	dbms_network_acl_admin.add_privilege(acl       => 'noradle.xml',
																			 principal => 'PSP',
																			 is_grant  => true,
																			 privilege => 'connect');
	-- for each record in server_control_t, call assign_acl to grant network access right from oracle to nodejs
	dbms_network_acl_admin.assign_acl(acl => 'noradle.xml', host => '127.0.0.1');
	commit;
end;
/
