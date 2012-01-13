create or replace package body k_gc is

	procedure css is
		v_date date := sysdate;
	begin
		k_gac.set('CSS', 'clearing', 'T');
		dbms_lock.sleep(10);
		for i in (select *
								from global_context a
							 where a.namespace = 'CSS'
								 and substrb(a.attribute, 30) = '0'
								 and to_date(substrb(a.value, 6), 'yyyy-mm-dd hh24:mi') < v_date - 60 / 24 / 60) loop
			k_gac.rm('CSS', i.attribute);
			for j in 1 .. to_number(substrb(i.value, 4, 1)) loop
				k_gac.rm('CSS', substrb(i.attribute, 1, 29) || to_char(j));
			end loop;
		end loop;
		k_gac.rm('CSS', 'clearing');
	end;

	procedure sfmlt is
	begin
		dbms_session.clear_all_context('SFLMT');
	end;

	procedure xetag is
	begin
		k_gac.rm('AETAG');
		k_gac.rm('UETAG');
	end;

	procedure mca is
	begin
		k_gac.rm('MCA');
	end;

end k_gc;
/

