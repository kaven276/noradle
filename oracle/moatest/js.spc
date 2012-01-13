create or replace package js is
	pragma serially_reusable;

	procedure open_ab(selector varchar2, abname varchar2);

	procedure close_ab;

	procedure add_number(name varchar2, val number);

	procedure add_boolean(name varchar2, val boolean);

	procedure add_string(name varchar2, val varchar2);

	procedure hash_item(name varchar2, value varchar2);

	procedure add_hash(name varchar2);

	procedure ab_tree(selector varchar2 := '.pwb_tree', init_level pls_integer := null, toggle_event varchar2 := null,
										hold boolean := null, unique_path boolean := null, expand_url varchar2 := null,
										effect_range varchar2 := null, content_frame_name varchar2 := null, path_container varchar2 := null);

	procedure ab_tabpage(selector varchar2 := '.pwb_tabpage', toggle_event varchar2 := null);

	---------------------------

	procedure call(name varchar2);

	procedure call(name varchar2, val varchar2);

	procedure call(name varchar2, vals st);

	procedure set(name varchar2, val varchar2);

	procedure set(name varchar2, val number);

	procedure set(name varchar2, vals st);

end js;
/

