-- note: p f v z ns ws is reserved for oracle apex

prompt framework
create or replace public synonym k_gw for k_gw;
create or replace public synonym k_filter for k_filter;

prompt tools
create or replace public synonym st for st;
create or replace public synonym nt for nt;
create or replace public synonym tmp for tmp;
create or replace public synonym t for k_type_tool;

prompt other tools
create or replace public synonym k_debug for k_debug;
create or replace public synonym odb for k_debug;
create or replace public synonym kv for kv;

prompt for input/request
create or replace public synonym r for r;
create or replace public synonym ra for ra;
create or replace public synonym rb for rb;

prompt for output/response
create or replace public synonym ext_url_v for ext_url_v;
create or replace public synonym l for url -- shortcut for link to url;
create or replace public synonym e for e -- tobe removed;
create or replace public synonym g for g;
create or replace public synonym k_http for k_http;
create or replace public synonym h for k_http;
create or replace public synonym rs for rs;

prompt for advance output/response (tag print)
create or replace public synonym style for style;
create or replace public synonym sty for style;
create or replace public synonym c for style;
create or replace public synonym y for style;
create or replace public synonym tag for tag;

create or replace public synonym tag for tag;
create or replace public synonym x for tag -- shortcut for xml/xhtml print;
create or replace public synonym multi for multi;
create or replace public synonym m for multi -- shortcut for multiply with template and array data;

create or replace public synonym list for list;
create or replace public synonym tb for list -- shortcut for table print;
create or replace public synonym tree for tree;
create or replace public synonym tr for tree -- shortcut for tree print;

prompt for call-out request/response
create or replace public synonym msg_pipe for msg_pipe;
create or replace public synonym mp for msg_pipe;
create or replace public synonym mp_h for msg_pipe;

create or replace public synonym cache for cache;