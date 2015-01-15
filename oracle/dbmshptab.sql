Rem
Rem $Header: dbmshptab.sql 30-jul-2007.13:07:41 sylin Exp $
Rem
Rem dbmshptab.sql
Rem
Rem Copyright (c) 2005, 2007, Oracle. All rights reserved.  
Rem
Rem    NAME
Rem      dbmshptab.sql - dbms hierarchical profiler table creation
Rem
Rem    DESCRIPTION
Rem       Create tables for the dbms hierarchical profiler
Rem
Rem    NOTES
Rem      The following tables are required to collect data:
Rem        dbmshp_runs
Rem          information on hierarchical profiler runs
Rem
Rem        dbmshp_function_info -
Rem          information on each function profiled
Rem
Rem        dbmshp_parent_child_info -
Rem          parent-child level profiler information
Rem
Rem      The dbmshp_runnumber sequence is used for generating unique
Rem      run numbers.
Rem
Rem      The tables and sequence can be created in the schema for each user
Rem      who wants to gather profiler data. Alternately these tables can be
Rem      created in a central schema. In the latter case the user creating
Rem      these objects is responsible for granting appropriate privileges
Rem      (insert,update on the tables and select on the sequence) to all
Rem      users who want to store data in the tables. Appropriate synonyms
Rem      must also be created so the tables are visible from other user
Rem      schemas.
Rem
Rem      THIS SCRIPT DELETES ALL EXISTING DATA!
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    sylin       07/30/07 - Modify foreign key constraints with on delete
Rem                           cascade clause
Rem    kmuthukk    06/13/06 - fix comments 
Rem    sylin       03/15/05 - Created
Rem

drop table dbmshp_runs                     cascade constraints;
drop table dbmshp_function_info            cascade constraints;
drop table dbmshp_parent_child_info        cascade constraints;

drop sequence dbmshp_runnumber;

create table dbmshp_runs
(
  runid               number primary key,  -- unique run identifier,
  run_timestamp       timestamp,
  total_elapsed_time  integer,
  run_comment         varchar2(2047)    -- user provided comment for this run
);

comment on table dbmshp_runs is
        'Run-specific information for the hierarchical profiler';

create table dbmshp_function_info
(
  runid                  number references dbmshp_runs on delete cascade,
  symbolid               number,               -- unique internally generated
                                               -- symbol id for a run
  owner                  varchar2(32),         -- user who started run
  module                 varchar2(32),         -- module name
  type                   varchar2(32),         -- module type
  function               varchar2(4000),       -- function name
  line#                  number,               -- line number where function
                                               -- defined in the module.
  hash                   raw(32) DEFAULT NULL, -- hash code of the method.
  -- name space/language info (such as PL/SQL, SQL)
  namespace              varchar2(32) DEFAULT NULL,
  -- total elapsed time in this symbol (including descendats)
  subtree_elapsed_time   integer DEFAULT NULL,
  -- self elapsed time in this symbol (not including descendants)
  function_elapsed_time  integer DEFAULT NULL,
  -- number of total calls to this symbol
  calls                  integer DEFAULT NULL,
  --  
  primary key (runid, symbolid)
);

comment on table dbmshp_function_info is
        'Information about each function in a run';

create table dbmshp_parent_child_info
(
  runid                  number,       -- unique (generated) run identifier
  parentsymid            number,       -- unique parent symbol id for a run
  childsymid             number,       -- unique child symbol id for a run
  -- total elapsed time in this symbol (including descendats)
  subtree_elapsed_time   integer DEFAULT NULL,
  -- self elapsed time in this symbol (not including descendants)
  function_elapsed_time  integer DEFAULT NULL,
  -- number of calls from the parent
  calls                  integer DEFAULT NULL,
  --
  foreign key (runid, childsymid)
    references dbmshp_function_info(runid, symbolid) on delete cascade,
  foreign key (runid, parentsymid)
    references dbmshp_function_info(runid, symbolid) on delete cascade
);

comment on table dbmshp_parent_child_info is
        'Parent-child information from a profiler runs';

create sequence dbmshp_runnumber start with 1 nocache;

