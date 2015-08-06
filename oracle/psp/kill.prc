create or replace procedure kill
(
	cfg  varchar2 := null,
	slot pls_integer := null,
	keep integer := 0
) is
	v_clinfo varchar2(48);
	v_return integer;
begin
	if cfg is null then
		v_clinfo := 'Noradle-%:%';
	elsif slot is null then
		v_clinfo := 'Noradle-' || cfg || ':%';
	else
		v_clinfo := 'Noradle-' || cfg || ':' || ltrim(to_char(slot, '0000'));
	end if;
	for i in (select a.client_info, a.module, a.action, a.sid, a.serial#
							from v$session a
						 where a.client_info like v_clinfo
							 and to_number(substrb(a.client_info, -4)) > keep) loop
		dbms_pipe.pack_message('SIGKILL');
		v_return := dbms_pipe.send_message(i.client_info);
	end loop;
end kill;
/
