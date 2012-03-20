create or replace package rcpv is

	user_row user_t%rowtype;
	user_ver varchar2(30);
	user_hit boolean;

	msid varchar2(30);

	term_row term_t%rowtype;
	term_ver varchar2(30);
	term_hit boolean;

end rcpv;
/
