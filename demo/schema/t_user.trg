create or replace trigger t_user
  after update on user_t  
  for each row
begin
	r.del('s$user_rctime');
	insert into passwd_his_t values (:old.name, :old.pass, sysdate);
	k_debug.trace('user change ' || :old.name);
end t_user;
/
