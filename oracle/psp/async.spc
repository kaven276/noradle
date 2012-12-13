create or replace package async authid current_user is

	procedure listen(p_pipe_name varchar2);

end async;
/
