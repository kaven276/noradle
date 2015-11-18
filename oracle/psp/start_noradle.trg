create or replace trigger start_noradle
     after startup on database
begin
	k_pmon.drop_zombie_scheduler_jobs;
	k_pmon.run_job;
end open_all_pdbs;
/
