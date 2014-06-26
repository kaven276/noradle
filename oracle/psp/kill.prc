create or replace procedure kill
(
	cfg  varchar2 := null,
	slot pls_integer := null
) is
	v_module varchar2(48);
	v_return integer;
begin
	if cfg is null then
		v_module := 'Noradle-%#%';
	elsif slot is null then
		v_module := 'Noradle-' || cfg || '#%';
	else
		v_module := 'Noradle-' || cfg || '#' || slot;
	end if;
	for i in (select a.module from v$session a where a.module like v_module) loop
		dbms_pipe.pack_message('SIGKILL');
		v_return := dbms_pipe.send_message(i.module);
	end loop;
end kill;
/
