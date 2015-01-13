create or replace package body attr is

	procedure d(nvs varchar2) is
	begin
		sts.attr := sts.attr || ' ' || replace(replace(nvs, '=', '="'), ',', '" ') || '"';
	end;

	procedure d(n varchar2, v varchar2) is
	begin
		sts.attr := sts.attr || ' ' || n || '="' || v || '"';
	end;

	procedure d(n varchar2, v boolean) is
	begin
		if v then
			sts.attr := sts.attr || ' ' || n;
		end if;
	end;

	procedure checked(v boolean) is
	begin
		if v then
			sts.attr := sts.attr || ' checked';
		end if;
	end;

	procedure id(v varchar2) is
	begin
		sts.attr := sts.attr || ' id="' || v || '"';
	end;

	procedure class(v varchar2) is
	begin
		sts.attr := sts.attr || ' class="' || v || '"';
	end;

	procedure href(v varchar2) is
	begin
		sts.attr := sts.attr || ' href="' || v || '"';
	end;

	procedure target(v varchar2) is
	begin
		sts.attr := sts.attr || ' target="' || v || '"';
	end;

end attr;
/
