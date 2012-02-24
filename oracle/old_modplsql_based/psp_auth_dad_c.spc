create or replace package psp_auth_dad_c authid current_user is

	procedure auth;

	procedure deauth;

end psp_auth_dad_c;
/

