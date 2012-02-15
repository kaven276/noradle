create or replace package body k_debug is

	procedure trace
	(
		info varchar2,
		name varchar2 := 'node2psp'
	) is
	begin
		dbms_pipe.pack_message(info);
		tmp.i := dbms_pipe.send_message(name, 0);
	exception
		when others then
			dbms_pipe.purge(name);
	end;

	procedure trace
	(
		info st,
		name varchar2 := 'node2psp'
	) is
	begin
		for i in 1 .. info.count loop
			dbms_pipe.pack_message(info(i));
		end loop;
		tmp.i := dbms_pipe.send_message(name, 0);
	exception
		when others then
			dbms_pipe.purge(name);
	end;

end k_debug;
/
