create or replace package pvevk is

	pendings mv2bg.events := mv2bg.events();

	stream_name varchar2(30);

	current_event mv2bg.event;

end pvevk;
/
