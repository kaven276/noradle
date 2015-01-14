create or replace package body media_b is

	procedure file_image is
	begin
		x.t('<doctype html>');
		x.o('<html>');
		x.o('<body>');
		x.s('<input type=file,accept=:1>', st('image/*;capture=camera'));
	end;

end media_b;
/
