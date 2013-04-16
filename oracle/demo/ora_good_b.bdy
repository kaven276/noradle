create or replace package body ora_good_b is

	procedure entry is
	begin
		p.h;
		p.style_open;
		p.line('dt{margin:0.5em;}');
		p.line('dt:before{content:"【 "}');
		p.line('dt:after{content:" 】"}');
		p.line('dd{line-height:1.5em;}');
		p.line('h3,h4{text-align:center;}');
		p.style_close;
		p.hn(3, 'Using oracle pl/sql as application layer language has many goods');
		p.hn(4, 'That can not be obtained for other none stored procesure languanges');
		p.hn(4, 'And plsql developer is a very good IDE of PL/SQL and PSP.WEB compare to other IDE of other lang ');
		p.dl_open;
		p.dt('TABLE%ROWTYPE');
		p.dd('You can use table%rowtype to easily define your local and package variables,' ||
				 ' and use rowtype variables in sql binding, and not need to redefine your data structure when row structure changed ' ||
				 ' for example ' || p.a('user_c.register', '=src_b.proc/user_c.register', '_blank'));

		p.dt('PACKAGED CURSUR');
		p.dd('packaged cursur just like a function, but can used direct in for-loop.');
		p.dd('I''t a good way to support incapsulation to query sql code.');

		p.dt('REF CURSUR');
		p.dd('You can design API that accept ref-cursor to reuse the procesing of result set generated from different code.');
		p.dd('I''t a good way to support incapsulation to result-set processing.');

		p.dt('TABLE FUNCTION');
		p.dd('So you can generate a result set from any data source and any way.');
		p.dd('And you can pipeline the table function and use them in sql as a table do.');

		p.dt('TRIGGER');
		p.dd('So you can detect table data change and invoke your pl/sql.');
		p.dd('If you use java or some of the many none store procedure languages, how could you react to data change.');

		p.dt('PACKAGE VARIABLE');
		p.dd('With a request processing, You can set your data in PV(package variable) and access them at all line of codewhen processing the request .');
		p.dd('So you avoid to transfer the data through parameters, you treat them as a environment variables for the request.');
		p.dd('If you use java or some of the many none store procedure languages, how could you react to data change.');

		p.dt('RESULT CACHE FUNCTION');
		p.dd('You can result cache function to cache result-set in memory, and avoid frequent table read.');
		p.dd('One step futher, you can use versioned row rc func with kv, so you can detect row change well using rc func.');
		p.dd('see ' || p.a('term_b.setting_form', '=src_b.proc/term_b.setting_form', '_blank') || ' and ' ||
				 p.a('term_b.setting_save', '=src_b.proc/term_b.setting_save', '_blank') || ' and ' ||
				 p.a('rc.set_term_info', '=src_b.proc/rc.set_term_info', '_blank'));
		p.dl_close;
	end;

end ora_good_b;
/
