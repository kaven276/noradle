create or replace function hash
(
	sch  varchar2,
	type varchar2,
	key  varchar2
) return varchar2 result_cache is
	v_gkey raw(999);
	v_hash varchar2(30);
begin
	v_gkey := utl_raw.cast_to_raw(sch || '|' || type || '|' || key);
	v_hash := utl_raw.cast_to_varchar2(utl_encode.base64_encode(dbms_crypto.hash(v_gkey, 1)));
	return translate(v_hash, pv.base64_cookie, pv.base64_gac);
end;
/
