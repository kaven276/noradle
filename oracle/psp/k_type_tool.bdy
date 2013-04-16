create or replace package body k_type_tool is

	fmt  constant varchar2(100) := 'Dy, DD Mon YYYY HH24:MI:SS "GMT"';
	lang constant varchar2(100) := 'NLS_DATE_LANGUAGE = American';

	function d2s(p_date date) return varchar2 is
	begin
		return to_char(p_date, 'yyyy-mm-dd');
	end;

	function dt2s(p_date date) return varchar2 is
	begin
		return to_char(p_date, 'yyyy-mm-dd hh24:mi:ss');
	end;

	function s2d(p_date varchar2) return date is
	begin
		return to_date(trim(p_date), 'yyyy-mm-dd');
	end;

	function s2dt(p_date varchar2) return date is
	begin
		return to_date(trim(p_date), 'yyyy-mm-dd hh24:mi:ss');
	end;

	function hdt2s(p_date date := sysdate) return varchar2 is
	begin
		return to_char(p_date - pv.tz_offset / 24, fmt, lang);
	end;

	function s2hdt(p_date varchar2) return date is
	begin
		return pv.tz_offset / 24 + to_date(p_date, fmt, lang);
	end;

	procedure half
	(
		p_str   varchar2 character set any_cs,
		p_left  in out nocopy varchar2 character set p_str%charset,
		p_right in out nocopy varchar2 character set p_str%charset
	) is
		v_pos pls_integer;
	begin
		v_pos := instr(p_str, ',');
		if v_pos > 0 then
			p_left  := substr(p_str, 1, v_pos - 1);
			p_right := substr(p_str, v_pos + 1);
		else
			p_left  := p_str;
			p_right := '';
		end if;
	end;

	function gen_token(p_algorithm binary_integer := 0) return varchar2 is
		v_seed        varchar2(80) := '12345678901234567890123456789012345678901234567890123456789012345678901234567890';
		v_algorithm   binary_integer := 2; -- 16 bytes key
		v_time        char(6);
		v_token       varchar2(100);
		v_ip_str      varchar2(200);
		v_ip_arry     st;
		v_start_place number;
		v_end_place   number;
	begin
		v_ip_str      := r.client_addr;
		v_start_place := 0;
		v_end_place   := instr(v_ip_str, '.');
		for i in 1 .. 3 loop
			v_ip_arry(i) := substr(v_ip_str, v_start_place + 1, v_end_place - v_start_place - 1);
			v_start_place := v_end_place;
			v_end_place := instr(v_ip_str, '.', v_start_place + 1);
		end loop;
		v_ip_arry(4) := substr(v_ip_str, v_start_place + 1);
		v_ip_str := '';
		for i in 1 .. 4 loop
			v_ip_str := substrb(rawtohex(utl_raw.cast_from_binary_integer(v_ip_arry(i))), 7) || v_ip_str;
		end loop;
		v_time  := to_char(sysdate, 'mmhhss');
		v_token := sys.dbms_obfuscation_toolkit_ffi.getkey(algorithm => v_algorithm, seed => utl_raw.cast_to_raw(v_seed));
		return v_token || v_time || v_ip_str;
	end;

	function ps
	(
		tpl  varchar2 character set any_cs,
		subs varchar2 character set any_cs,
		ch   char := ':'
	) return varchar2 character set tpl%charset is
		v_pos1 pls_integer := 0;
		v_pos2 pls_integer;
		v_cnt  pls_integer := 0;
		v_rtn  varchar2(2000) character set tpl%charset;
		v_str  varchar2(1000) character set subs%charset;
	begin
		if subs is null then
			return tpl;
		end if;
		loop
			v_pos2 := instr(subs, ',', v_pos1 + 1);
			if v_pos1 = 0 then
				if v_pos2 = 0 then
					return replace(tpl, ch || '1', subs);
				else
					v_rtn := tpl;
				end if;
			elsif v_pos2 = 0 then
				v_str := substr(subs, v_pos1 + 1);
				return replace(v_rtn, ch || (v_cnt + 1), v_str);
			end if;
			v_cnt  := v_cnt + 1;
			v_str  := substr(subs, v_pos1 + 1, v_pos2 - v_pos1 - 1);
			v_rtn  := replace(v_rtn, ch || v_cnt, v_str);
			v_pos1 := v_pos2;
		end loop;
	end;

	function ps
	(
		pat  varchar2 character set any_cs,
		vals st,
		ch   char := ':'
	) return varchar2 character set pat%charset is
		v_str varchar2(32000) character set pat%charset := pat;
		v_chr char(1) := chr(0);
	begin
		for i in 1 .. vals.count loop
			v_str := replace(v_str, ch || i, v_chr || vals(i));
		end loop;
		return replace(v_str, v_chr, '');
	end;

	-- like c's printf, use ~ for replacement by default
	function pf
	(
		pat  varchar2 character set any_cs,
		subs st,
		ch   char := '~'
	) return varchar2 character set pat%charset is
		v_rtn varchar2(32000);
	begin
		v_rtn := regexp_replace(pat, ch, subs(1), 1);
		for i in 2 .. subs.count loop
			v_rtn := regexp_replace(v_rtn, ch, subs(i), 1);
		end loop;
		return v_rtn;
	end;

	function tf
	(
		cond boolean,
		t    varchar2 character set any_cs,
		f    varchar2 character set t%charset := ''
	) return varchar2 character set t%charset is
	begin
		if cond then
			return t;
		else
			return f;
		end if;
	end;

	function nnpre
	(
		pre varchar2 character set any_cs,
		str varchar2 character set any_cs
	) return varchar2 character set str%charset is
	begin
		if str is null then
			return null;
		end if;
		return pre || str;
	end;

	function nvl2
	(
		cond varchar2 character set any_cs,
		nn   varchar2 character set cond%charset,
		n    varchar2 character set cond%charset := ''
	) return varchar2 character set cond%charset is
	begin
		if cond is not null then
			return nn;
		else
			return n;
		end if;
	end;

	procedure split
	(
		stv in out nocopy st,
		p   varchar2,
		sep varchar2 := ',',
		trm boolean := true
	) is
		v_pos pls_integer;
		v_old pls_integer := 0;
		v_cnt pls_integer := 0;
	begin
		stv := st();
		if p is not null then
			stv.extend(regexp_count(p, sep) + 1);
			loop
				v_pos := instr(p, sep, v_old + 1, 1);
				exit when v_pos = 0 or v_pos is null;
				v_cnt := v_cnt + 1;
				if trm then
					stv(v_cnt) := trim(substr(p, v_old + 1, v_pos - v_old - 1));
				else
					stv(v_cnt) := substr(p, v_old + 1, v_pos - v_old - 1);
				end if;
				v_old := v_pos;
			end loop;
			if trm then
				stv(v_cnt + 1) := trim(substr(p, v_old + 1));
			else
				stv(v_cnt + 1) := substr(p, v_old + 1);
			end if;
		end if;
	end;

	function join
	(
		stv in out nocopy st,
		sep varchar2 := ','
	) return varchar2 is
		s varchar2(32000);
	begin
		if stv is null or stv.count = 0 then
			return '';
		end if;
		s := stv(1);
		for i in 2 .. stv.count loop
			s := s || sep || stv(i);
		end loop;
		return s;
	end;

	function joinc
	(
		stv st,
		sep varchar2 := ','
	) return varchar2 is
		s varchar2(32000);
	begin
		if stv is null or stv.count = 0 then
			return '';
		end if;
		s := stv(1);
		for i in 2 .. stv.count loop
			s := s || sep || stv(i);
		end loop;
		return s;
	end;

	procedure gen_seq_list
	(
		amount pls_integer,
		ntv    in out nocopy nt
	) is
	begin
		select rownum bulk collect into ntv from dual a connect by rownum <= amount;
	end;

	procedure loop_init is
	begin
		tmp.cnt := 0;
	end;

	function loop_first return boolean is
	begin
		tmp.cnt := tmp.cnt + 1;
		if tmp.cnt = 1 then
			return true;
		else
			return false;
		end if;
	end;

	procedure loop_count is
	begin
		tmp.cnt := tmp.cnt + 1;
	end;

	function loop_count return pls_integer is
	begin
		return tmp.cnt;
	end;

	function loop_empty return boolean is
	begin
		return tmp.cnt = 0;
	end;

end k_type_tool;
/
