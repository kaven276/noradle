create or replace package body pc is

	procedure h(target varchar2 := null) is
	begin
		x.t('<!DOCTYPE html>');
		x.o('<html>');
		if target is not null then
			x.o('<head>');
			if target is not null then
				x.s('<base target=:1>', st(target));
			end if;
			x.c('</head>');
		end if;
		x.o('<body>');
	end;

end pc;
/
