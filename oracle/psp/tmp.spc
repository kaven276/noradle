create or replace package tmp is

	dt  date;
	ts  timestamp;
	bi  binary_integer;
	pi  pls_integer;
	i   integer;
	j   integer;
	k   integer;
	n   number;
	scn number;
	b   boolean;
	cnt number;
	rid rowid;
	rw  raw(32767);
	s   varchar2(32767);
	url varchar2(4000);
	stv st;
	ntv nt;
	p   pv.vc_arr;

	rows pls_integer;

end tmp;
/
