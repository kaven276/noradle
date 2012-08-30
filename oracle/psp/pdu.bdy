create or replace package body pdu is

	procedure start_parse(req_seq pls_integer) is
	begin
		dcopv.crseq := req_seq;
		dcopv.crpos := 1;
	end;

	function get_binary_integer return binary_integer is
		v_raw raw(4);
		v_amt pls_integer := 4;
	begin
		dbms_lob.read(dcopv.rsps(dcopv.crseq), v_amt, dcopv.crpos, v_raw);
		dcopv.crpos := dcopv.crpos + v_amt;
		return utl_raw.cast_to_binary_integer(v_raw);
	end;

	function get_binary_float return binary_float is
		v_raw raw(4);
		v_amt pls_integer := 4;
	begin
		dbms_lob.read(dcopv.rsps(dcopv.crseq), v_amt, dcopv.crpos, v_raw);
		dcopv.crpos := dcopv.crpos + v_amt;
		return utl_raw.cast_to_binary_float(v_raw);
	end;

	function get_binary_double return binary_double is
		v_raw raw(8);
		v_amt pls_integer := 8;
	begin
		dbms_lob.read(dcopv.rsps(dcopv.crseq), v_amt, dcopv.crpos, v_raw);
		dcopv.crpos := dcopv.crpos + v_amt;
		return utl_raw.cast_to_binary_double(v_raw);
	end;

	procedure get_raw
	(
		tar   in out nocopy raw,
		bytes pls_integer
	) is
		v_amt pls_integer := bytes;
	begin
		dbms_lob.read(dcopv.rsps(dcopv.crseq), v_amt, dcopv.crpos, tar);
		dcopv.crpos := dcopv.crpos + v_amt;
	end;

	function get_varchar2(bytes pls_integer) return varchar2 is
		v_raw raw(4000);
	begin
		get_raw(v_raw, bytes);
		return utl_i18n.raw_to_char(v_raw, 'AL32UTF8');
	end;

	function get_nvarchar2(bytes pls_integer) return nvarchar2 is
		v_raw raw(4000);
	begin
		get_raw(v_raw, bytes);
		return utl_i18n.raw_to_nchar(v_raw, 'AL32UTF8');
	end;

	function get_char_line return varchar2 is
		v_start integer(8) := dcopv.crpos;
		v_end   integer(8) := dbms_lob.instr(dcopv.rsps(dcopv.crseq), dcopv.nl, dcopv.crpos, 1);
	begin
		return rtrim(get_varchar2(v_end - v_start + 1), chr(10));
	end;

	function get_nchar_line return nvarchar2 is
		v_start integer(8) := dcopv.crpos;
		v_end   integer(8) := dbms_lob.instr(dcopv.rsps(dcopv.crseq), dcopv.nl, dcopv.crpos, 1);
	begin
		return rtrim(get_nvarchar2(v_end - v_start + 1), chr(10));
	end;

	procedure get_name_value(hash in out nocopy name_value_t) is
	begin
		null;
	end;

	procedure clear is
	begin
		dcopv.rsps.delete(dcopv.crseq);
	end;

end pdu;
/
