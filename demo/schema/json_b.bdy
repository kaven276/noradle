create or replace package body json_b is

	procedure t1 is
		obj json_list;
		l   json_list := json_list();
		o   json;
	begin
		-- p.doc_type('text');
		pc.h;
		x.p('<p>', 'Building the first list');
		obj := json_list(); --an empty structure
		obj.append('a little string');
		obj.append(123456789);
		obj.append(true);
		obj.append(false);
		obj.append(json_value);
		x.p('<p>', obj.to_char);
		x.p('<p>', 'add with position ');
		obj.append('Wow thats great!', 5);
		x.p('<p>', obj.to_char);
		x.p('<p>', 'remove with position');
		obj.remove(4);
		x.p('<p>', obj.to_char);
		x.p('<p>', 'remove first');
		obj.remove_first;
		x.p('<p>', obj.to_char);
		x.p('<p>', 'remove last');
		obj.remove_last;
		x.p('<p>', obj.to_char);
		x.p('<p>', 'you can display the size of an list');
		x.p('<p>', obj.count);
		x.p('<p>', 'you can also add json or json_lists as values:');
		obj := json_list(); --fresh list;
		obj.append(json('{"lazy construction": true}').to_json_value);
		obj.append(json_list('[1,2,3,4,5]'));
		x.p('<p>', obj.to_char);
		x.p('<p>', 'however notice that we had to use the "to_json_value" function on the json object');

		for i in (select * from team_t a) loop
			o := json(); --an empty structure
			o.put('tid', i.tid);
			o.put('tname', i.tname);
			o.put('cdate', json_ext.to_json_value(i.cdate));
			l.append(o.to_json_value);
		end loop;
    -- l := json_dyn.executeList('select * from team_t a');
		p.script_open;
		h.line('var teams =');
		h.line(l.to_char);
		h.line(';
		for(i=0;i<teams.length;i++) document.body.insertAdjacentHTML("beforeEnd","<p>"+teams[i].tname+"</p>");
		');
		p.script_close;
	end;

end json_b;
/
