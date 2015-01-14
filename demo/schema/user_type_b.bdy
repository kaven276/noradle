create or replace package body user_type_b is

	procedure basic is
		v tool := tool('.');
	begin
		if r.getc('type', '') = '2' then
			v := tool2('.');
		else
			v := tool('.');
		end if;
		h.write(v.wrap('hello world'));
	end;

end user_type_b;
/
