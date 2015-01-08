create or replace package body kv is

	procedure save_clear_cid is
	begin
		pv.cid := sys_context('user', 'client_identifier', 64);
		dbms_session.clear_identifier;
	end;

	procedure restore_cid is
	begin
		dbms_session.set_identifier(pv.cid);
		pv.cid := null;
	end;

	procedure set
	(
		type varchar2,
		key  varchar2,
		ver  varchar2
	) is
		v_hash varchar2(30) := hash(type, key);
	begin
		dbms_session.set_context('KEY_VER_CTX', v_hash, ver, client_id => null);
		dbms_pipe.pack_message(v_hash);
		if dbms_pipe.send_message('KEY_VER_SET_QUEUE', 0) = 1 then
			-- fetch n pipe items, and clear the key-vel GAC
			for i in 1 .. 5 loop
				if dbms_pipe.receive_message('KEY_VER_SET_QUEUE', 0) = 1 then
					exit;
				end if;
				-- fetch key ok, then clear GAC
				dbms_pipe.unpack_message(v_hash);
				dbms_session.clear_context('KEY_VER_CTX', null, v_hash);
			end loop;
		end if;
	end;

	procedure upd
	(
		type varchar2,
		key  varchar2,
		ver  varchar2
	) is
		v_hash varchar2(30) := hash(type, key);
	begin
		save_clear_cid;
		if sys_context('KEY_VER_CTX', v_hash) is not null then
			-- update local key-ver GAC store, normally caused by trigger
			dbms_session.set_context('KEY_VER_CTX', v_hash, ver, client_id => null);
		end if;
		restore_cid;
	
		-- signal other instances to update version of the key
		-- require a repeat NDBC call to fetch pipe
		-- or the pipe will finally be full filled
		if true then
			dbms_pipe.pack_message(v_hash);
			dbms_pipe.pack_message(ver);
			if dbms_pipe.send_message('SYNC_KEY_VER') = 0 then
				null; -- ok
			end if;
		end if;
	end;

	procedure del
	(
		type varchar2,
		key  varchar2
	) is
		v_cid varchar2(64);
	begin
		dbms_session.clear_context('KEY_VER_CTX', null, hash(type, key));
	end;

	function get
	(
		type varchar2,
		key  varchar2
	) return varchar2 is
	begin
		return sys_context('KEY_VER_CTX', hash(type, key));
	end;

	procedure clear is
	begin
		dbms_session.clear_all_context('KEY_VER_CTX');
	end;

end kv;
/
