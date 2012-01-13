create or replace package body k_cm is

	procedure login
	(
		p_user     varchar2,
		p_password varchar2
	) is
		v_sid v$session.sid%type;
		v     dev_login_t%rowtype;
	begin
		select a.sid into v_sid from v$mystat a where rownum = 1;
		select s.osuser, s.machine, s.terminal, s.program, p_user, sysdate
			into v
			from v$session s
		 where s.sid = v_sid;
		insert into dev_login_t values v;
		commit;
	exception
		when dup_val_on_index then
			update dev_login_t a
				 set row = v
			 where a.osuser = v.osuser
				 and a.machine = v.machine
				 and a.program = a.program;
	end;

end k_cm;
/

