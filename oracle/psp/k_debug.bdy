create or replace package body k_debug is

	procedure meter
	(
		info varchar2,
		name varchar2 := 'prof'
	) is
	begin
		if dbms_utility.get_time - pv.elpl < 3 then
			return;
		end if;
		dbms_pipe.pack_message(dbms_utility.get_time - pv.elpl);
		pv.elpl := dbms_utility.get_time;
		dbms_pipe.pack_message(info);
		tmp.i := dbms_pipe.send_message(name, 0);
	exception
		when others then
			dbms_pipe.purge(name);
	end;

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

	procedure set_run_comment(value varchar2) is
	begin
		pv.hp_label := value;
	end;

end k_debug;
/
