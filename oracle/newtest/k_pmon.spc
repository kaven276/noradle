create or replace package k_pmon is

	procedure once;

	procedure daemon;

	procedure stop;

	procedure create_deamon_job;

end k_pmon;
/
