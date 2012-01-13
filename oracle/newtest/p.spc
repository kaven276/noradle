create or replace package p is

	procedure "_init"(c in out nocopy utl_tcp.connection, passport pls_integer);

	procedure prepare(mime_type varchar2 := 'text/html', charset varchar2 := 'UTF-8');

	procedure line(str varchar2);

end p;
/

