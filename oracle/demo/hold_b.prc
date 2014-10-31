create or replace procedure hold_b is
	v_secs pls_integer := r.getn('sec', 10);
begin
	for i in 1 .. v_secs loop
		dbms_lock.sleep(1);
		dbms_application_info.set_session_longops(tmp.i,
																							tmp.j,
																							op_name     => r.url_full,
																							target_desc => 'sleep',
																							sofar       => i,
																							totalwork   => v_secs,
																							units       => 'seconds');
	end loop;
	x.p('<p>', 'over');
end hold_b;
/
