create or replace package body dcopv is
begin
	dbms_lob.createtemporary(msg, cache => true, dur => dbms_lob.session);
	chksz    := dbms_lob.getchunksize(msg);
	pos_head := 0;
	pos_tail := 12;
	rseq     := 0;
	onway    := 0;
	onbuf    := 0;
	dbms_alert.register('Noradle-DCO-EXTHUB-QUIT');
	if host is not null and port is not null then
		dbms_alert.signal('Noradle-DCO-EXTHUB-QUIT', host || ':' || port);
	end if;
	commit;
end dcopv;
/
