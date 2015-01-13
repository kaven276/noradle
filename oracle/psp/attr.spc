create or replace package attr is

	procedure d(nvs varchar2);

	procedure d(n varchar2, v varchar2);

	procedure d(n varchar2, v boolean);

	procedure checked(v boolean);

	procedure id(v varchar2);

	procedure class(v varchar2);

	procedure href(v varchar2);

	procedure target(v varchar2);

end attr;
/
