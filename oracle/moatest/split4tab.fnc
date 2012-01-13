create or replace function split4tab
(
	p   varchar2,
	sep varchar2 := ','
) return st is

	v_pos pls_integer;

	v_old pls_integer := 0;
	v_cnt pls_integer := 0;
	v_st  st;
begin
	v_st := st();
	loop
		v_pos := instr(p, sep, v_old + 1, 1);
		exit when v_pos = 0 or v_pos is null;
		v_st.extend;
		v_cnt := v_cnt + 1;
		v_st(v_cnt) := trim(substr(p, v_old + 1, v_pos - v_old - 1));
		v_old := v_pos;
	end loop;
	v_st.extend;
	v_st(v_cnt + 1) := trim(substr(p, v_old + 1));
	return v_st;
end;
/

