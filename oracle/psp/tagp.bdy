create or replace package body tagp is

	procedure a(inner varchar2, attrs varchar2) is
	begin
		if attrs is not null then
			attr.d(attrs);
		end if;
		h.line('<a' || sts.attr || '>' || inner || '</a>');
		sts.attr := '';
	end;

end tagp;
/
