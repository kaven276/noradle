create or replace package body xml_page_b is

	-- private
	procedure show_begin is
	begin
		p.line('<textarea cols="100" rows="20" style="#overflow:visible;">');
	end;

	-- private
	procedure show_end is
	begin
		p.line('</textarea>');
	end;

	procedure xmlgen_str is
		v      dbms_xmlgen.ctxhandle;
		v_clob clob;
	begin
		p.h;
		src_b.link_proc;
		p.br;
	
		v := dbms_xmlgen.newcontext('select t.name as "td",t.pass as "td" from user_t t');
		dbms_xmlgen.setrowsettag(v, 'table');
		dbms_xmlgen.setrowtag(v, 'tr');
	
		show_begin;
		p.d(dbms_xmlgen.getxmltype(v).getclobval());
		show_end;
	end;

	procedure xmlgen_cur is
		c sys_refcursor;
		v dbms_xmlgen.ctxhandle;
	begin
		p.h;
		src_b.link_proc;
		p.br;
	
		open c for
			select * from user_t;
		v := dbms_xmlgen.newcontext(c);
		dbms_xmlgen.setrowsettag(v, 'users');
		dbms_xmlgen.setrowtag(v, 'user');
	
		show_begin;
		p.d(dbms_xmlgen.getxmltype(v).getclobval());
		show_end;
		close c;
	end;

	procedure xmlgen_hier is
		c sys_refcursor;
		v dbms_xmlgen.ctxhandle;
	begin
		p.h;
		src_b.link_proc;
		p.br;
		open c for
			select o.object_name as "name",
						 cursor (select p.procedure_name as "name" from user_procedures p where p.object_name = o.object_name)        "procedures"
				from user_objects o
			 where o.object_type = 'PACKAGE';
		v := dbms_xmlgen.newcontext(c);
		dbms_xmlgen.setrowsettag(v, 'packages');
		dbms_xmlgen.setrowtag(v, 'package');
		-- dbms_xmlgen.setmaxrows(v, 1);
		show_begin;
		p.d(dbms_xmlgen.getxmltype(v).getclobval());
		show_end;
		close c;
	end;

	procedure sql_users is
		v_table xmltype;
	begin
		p.h('user_table.css');
		src_b.link_proc;
		p.br;
	
		select xmlelement("table",
											xmlattributes('all' as "rules"),
											chr(10),
											xmlagg(xmlelement("tr",
																				xmlattributes('black' as "class", 90 as "height", 'green' as "color"),
																				chr(10),
																				xmlforest(t.name as "td", t.pass as "td", (t.ctime) as "td"),
																				chr(10))))
			into v_table
			from user_t t
		 order by t.ctime asc;
		p.d(v_table.getclobval);
	end;

	procedure xml_users_css is
		c sys_refcursor;
		v dbms_xmlgen.ctxhandle;
	begin
		h.content_type('text/xml');
	
		open c for
			select * from user_t;
		v := dbms_xmlgen.newcontext(c);
		dbms_xmlgen.setrowsettag(v, 'users');
		dbms_xmlgen.setrowtag(v, 'user');
		p.ps('<?xml-stylesheet type="text/css" href=":1" media="screen"?>', st(u('users_ol.css')));
		p.d(dbms_xmlgen.getxmltype(v).getclobval);
		close c;
	end;

	procedure xml_users_xsl_cli is
		c     sys_refcursor;
		v     dbms_xmlgen.ctxhandle;
		v_url varchar2(500);
	begin
		h.content_type('text/xml');
	
		open c for
			select * from user_t;
		v := dbms_xmlgen.newcontext(c);
		dbms_xmlgen.setrowsettag(v, 'users');
		dbms_xmlgen.setrowtag(v, 'user');
		p.line('<?xml version="1.0" encoding="UTF-8"?>');
		p.ps('<?xml-stylesheet type="text/xsl" href=":1" media="screen"?>', st(u('users.xsl')));
		p.d(dbms_xmlgen.getxmltype(v).getclobval());
		close c;
	end;

	-- has problem by now
	procedure xml_users_xsl_svr is
		c       sys_refcursor;
		v       dbms_xmlgen.ctxhandle;
		v_bfile bfile;
		v_xml   xmltype;
		v_xsl   xmltype;
		v_str   varchar2(4000);
		v_xhtml xmltype;
	begin
		src_b.link_proc;
		p.br;
	
		open c for
			select * from user_t;
		v := dbms_xmlgen.newcontext(c);
		dbms_xmlgen.setrowsettag(v, 'users');
		dbms_xmlgen.setrowtag(v, 'user');
		v_xml := dbms_xmlgen.getxmltype(v);
		close c;
	
		p.s     := r.dad || '/static/packs/xml_page_b/users.xsl';
		v_bfile := bfilename('PSPDADS', p.s);
		if dbms_lob.fileexists(v_bfile) = 0 then
			raise_application_error(-20001, 'xslt file not exists');
		end if;
		v_xsl := xmltype(v_bfile, 0);
	
		p.http_header_close;
		v_xhtml := v_xml.transform(v_xsl);
		p.d(v_xhtml.getclobval());
	end;

end xml_page_b;
/
