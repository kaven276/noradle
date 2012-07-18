create or replace trigger t_user
  after update on user_t  
  for each row
declare
	v mv2bg.event;
begin
	kv.del('user', :old.name);

	v.evt_rowid := :old.rowid;

	-- to manual stream
	v.pipe_name := 'user_change_broker';
	mv2bg.add(v);

	-- for auto stream
	v.pipe_name := 'demo_user_upt';
	mv2bg.add(v);

	-- when commit the transaction, remember to call mv2bg.after_commit to send all pending event to pipe
end t_user;
/
