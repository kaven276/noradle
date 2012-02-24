create or replace trigger t_upload_file
	before insert on upload_file_t
	for each row
	call fs.upload(:new.name, :new.blob_content)
/

