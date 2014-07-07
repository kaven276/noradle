create or replace package body layout_b is

	procedure form is
		v_dir varchar2(1) := r.getc('dir', 'H');
		procedure pad(pos pls_integer) is
		begin
			case v_dir
				when 'H' then
					case pos
						when 1 then
							x.t('<tr><th>');
						when 2 then
							x.t('</th><td>');
						when 3 then
							x.t('</td></tr>');
					end case;
				when 'V' then
					case pos
						when 1 then
							x.t('<tr><th>');
						when 2 then
							x.t('</th></tr><tr><td>');
						when 3 then
							x.t('</td></tr>');
					end case;
			end case;
		end;
	begin
		x.o('<html>');
		x.o('<head>');
		x.p('<style>', 'table{border:1px solid}td,th{padding:5px;}');
		x.c('</head>');
		x.o('<body>');
		src_b.link_proc;
		if v_dir = 'H' then
			x.a('<a>', 'change to vertical layout', '@b.form?dir=V');
		else
			x.a('<a>', 'change to horizonal layout', '@b.form?dir=H');
		end if;
		x.o('<form>');
		x.o('<table rules=all>');
		for i in 1 .. 5 loop
			pad(1);
			x.p('<label>', 'name');
			pad(2);
			x.s('<input type=text>');
			pad(3);
		end loop;
		x.c('</table>');
		x.c('</form>');
	end;

end layout_b;
/
