create or replace package body ora_good_b is

	procedure entry is
	begin
		x.t('<DOCTYPE html>');
		x.o('<html>');
		x.o('<head>');
		x.o(' <style>');
		h.line('dt{margin:0.5em;}');
		h.line('dt:before{content:"[ "}');
		h.line('dt:after{content:" ]"}');
		h.line('dd{line-height:1.5em;}');
		h.line('h3,h4{text-align:center;}');
		x.c(' </style>');
		x.c('</head>');
		x.o('<body>');
		x.p('<h3>', 'Using oracle pl/sql as application layer language has many goods');
		x.p('<h4>', 'That can not be obtained for other none stored procesure languanges');
		x.p('<h4>', 'And plsql developer is a very good IDE of PL/SQL and PSP.WEB compare to other IDE of other lang ');
		x.o('<dl>');
		x.p('<dt>', 'TABLE%ROWTYPE');
		x.p('<dd>',
				'You can use table%rowtype to easily define your local and package variables,' ||
				' and use rowtype variables in sql binding, and not need to redefine your data structure when row structure changed ' ||
				' for example ' || x.a('<a target=_blank>', 'user_c.register', 'src_b.proc?p=user_c.register'));
	
		x.p('<dt>', 'PACKAGED CURSUR');
		x.p('<dd>', 'packaged cursur just like a function, but can used direct in for-loop.');
		x.p('<dd>', 'I''t a good way to support incapsulation to query sql code.');
	
		x.p('<dt>', 'REF CURSUR');
		x.p('<dd>',
				'You can design API that accept ref-cursor to reuse the procesing of result set generated from different code.');
		x.p('<dd>', 'I''t a good way to support incapsulation to result-set processing.');
	
		x.p('<dt>', 'TABLE FUNCTION');
		x.p('<dd>', 'So you can generate a result set from any data source and any way.');
		x.p('<dd>', 'And you can pipeline the table function and use them in sql as a table do.');
	
		x.p('<dt>', 'TRIGGER');
		x.p('<dd>', 'So you can detect table data change and invoke your pl/sql.');
		x.p('<dd>',
				'If you use java or some of the many none store procedure languages, how could you react to data change.');
	
		x.p('<dt>', 'PACKAGE VARIABLE');
		x.p('<dd>',
				'With a request processing, You can set your data in PV(package variable) and access them at all line of codewhen processing the request .');
		x.p('<dd>',
				'So you avoid to transfer the data through parameters, you treat them as a environment variables for the request.');
		x.p('<dd>',
				'If you use java or some of the many none store procedure languages, how could you react to data change.');
	
		x.p('<dt>', 'RESULT CACHE FUNCTION');
		x.p('<dd>', 'You can result cache function to cache result-set in memory, and avoid frequent table read.');
		x.p('<dd>',
				'One step futher, you can use versioned row rc func with kv, so you can detect row change well using rc func.');
		x.p('<dd>',
				'see ' || x.a('<a target=_blank>', 'term_b.setting_form', 'src_b.proc?p=term_b.setting_form') || ' and ' ||
				x.a('<a target=_blank>', 'term_b.setting_save', 'src_b.proc?p=term_b.setting_save') || ' and ' ||
				x.a('<a target=_blank>', 'rc.set_term_info', 'src_b.proc?p=rc.set_term_info'));
		x.c('</dl>');
		x.c('</body>');
		x.c('</html>');
	end;

end ora_good_b;
/
