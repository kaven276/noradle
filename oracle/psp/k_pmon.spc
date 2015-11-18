create or replace package k_pmon is

	procedure adjust;

	procedure run;

	procedure stop;

	procedure drop_zombie_scheduler_jobs;

	procedure run_job;
	
	procedure rerun_job;

end k_pmon;
/
