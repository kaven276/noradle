create or replace type body tool is

	-- Member procedures and functions
	member function wrap(str varchar2) return varchar2 is
	begin
		return '<p>' || str || '</p>';
	end;

end;
/
