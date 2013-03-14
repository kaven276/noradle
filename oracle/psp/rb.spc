create or replace package rb is

	-- take from req header content-type
	charset_http varchar2(30);
	charset_db   varchar2(30);

	blob_entity  blob;
	clob_entity  clob;
	nclob_entity nclob;

end rb;
/
