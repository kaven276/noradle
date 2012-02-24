create or replace package body g is

	procedure finish is
	begin
		raise pv.ex_resp_done;
	end;

	procedure filter_pass is
	begin
		raise pv.ex_fltr_done;
	end;

end g;
/
