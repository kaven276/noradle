create or replace type body tool2 is

	overriding member function wrap(str varchar2) return varchar2 is
	begin
		return '<h1>' || str || '</h1>';
	end;

end;
/
