create or replace type tool as object
(
-- Author  : ADMINISTRATOR
-- Created : 2014-7-28 15:08:08
-- Purpose : 

-- Attributes
	class varchar2(30),

-- Member functions and procedures
	member function wrap(str varchar2) return varchar2
)
not final
/
