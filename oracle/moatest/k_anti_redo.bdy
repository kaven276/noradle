create or replace package body k_anti_redo is

	gv_msid varchar2(54);
	gv_set  boolean;

	function test return boolean is
		v_url varchar2(4000);
	begin
		return false;
		gv_msid := r.cookie('msid');
		if gv_msid is null or lengthb(gv_msid) > 30 then
			return false;
		end if;
		v_url  := r.cgi('SCRIPT_NAME') || r.cgi('PATH_INFO') || r.cgi('query_string');
		gv_set := false;
		if sys_context('MCA', gv_msid) = v_url and v_url is not null then
			k_http.set_no_cache;
			p.h('', 'anti repeat');
			case r.cgi('REQUEST_METHOD')
				when 'POST' then
					p.script_text('alert("您进行了重复提交,上一提交正在处理中，请耐心等候，上一请求后台处理完将不会返回结果！");');
				when 'GET' then
					p.script_text('alert("您进行了快速页面刷新,该页面已经在生成中,请耐心等候!");');
				else
					return false;
			end case;
			p.ensure_close;
			return true;
		end if;
		k_gac.set('MCA', gv_msid, v_url);
		return false;
	end;

	procedure clear is
	begin
		if gv_msid is not null then
			k_gac.rm('MCA', gv_msid);
		end if;
	end;

end k_anti_redo;
/

