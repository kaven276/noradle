create or replace package body k_file as

  gv_dir_name varchar2(30);

  function get_dir_name return varchar2 is
  begin
    if gv_dir_name is null then
      gv_dir_name := upper(owa_util.get_cgi_env('dad_name')) || '_ULF';
    end if;
    return gv_dir_name;
  end;

  -- public
  function get_next_file_id return number is
    v_file_id number;
  begin
    select s_upload_file_id.nextval into v_file_id from dual;
    return v_file_id;
  end;

  -----------------------------------------------------------------

  -- public
  function id2name(p_file_id number) return varchar2 is
    v_auto_name upload_file_t.name%type;
  begin
    select t.name
      into v_auto_name
      from upload_file_t t
     where t.file_id = p_file_id;
    return v_auto_name;
  exception
    when no_data_found then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
  end;

  -----------------------------------------------------------------

  -- public
  function name2id(p_auto_name varchar2) return number is
    v_file_id upload_file_t.file_id%type;
  begin
    select t.file_id
      into v_file_id
      from upload_file_t t
     where t.name = p_auto_name;
    return v_file_id;
  exception
    when no_data_found then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
  end;

  -----------------------------------------------------------------

  -- public
  function id2fpath(p_file_id number) return varchar2 is
    v_full_path upload_file_t.name%type;
  begin
    select t.full_path
      into v_full_path
      from upload_file_t t
     where t.file_id = p_file_id;
    return v_full_path;
  exception
    when no_data_found then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
  end;

  -----------------------------------------------------------------

  -- public
  function fpath2id(p_full_path varchar2) return number is
    v_file_id upload_file_t.file_id%type;
  begin
    select t.file_id
      into v_file_id
      from upload_file_t t
     where t.dad_name = owa_util.get_cgi_env('dad_name')
       and t.full_path = p_full_path;
    return v_file_id;
  exception
    when no_data_found then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
  end;

  -----------------------------------------------------------------

  procedure one_to_bfile(p_dir_name     varchar2,
                         p_file_name    varchar2,
                         p_blob_content in out nocopy blob) is
    v_bfile sys.utl_file.file_type;
    c_buf_len constant binary_integer := 32767;
    v_raw_buf raw(32767);
    v_amount  binary_integer := c_buf_len;
    v_offset  binary_integer := 1;
  begin
    v_bfile := utl_file.fopen(p_dir_name, p_file_name, 'wb', 32767);
    while v_amount = c_buf_len loop
      dbms_lob.read(p_blob_content, v_amount, v_offset, v_raw_buf);
      utl_file.put_raw(v_bfile, v_raw_buf, autoflush => false);
      v_offset := v_offset + v_amount;
    end loop;
    utl_file.fclose(v_bfile);
  end;

  procedure upload(p_file_id      in out nocopy binary_integer,
                   p_autoname     in out nocopy varchar2,
                   p_blob_content in out nocopy blob,
                   p_dad_name     in out nocopy varchar2,
                   p_db_user      in out nocopy varchar2,
                   p_full_path    in out nocopy varchar2) is
  begin
    p_file_id   := k_file.get_next_file_id;
    p_dad_name  := owa_util.get_cgi_env('dad_name');
		p_db_user := user;
    -- p_db_user   := dbms_epg.get_dad_attribute(p_dad_name,'database-username');
    p_full_path := '/fid/' || p_file_id;
    if k_ccflag.use_bfile then
      one_to_bfile(upper(p_dad_name) || '_ULF',
                   '$' || p_file_id,
                   p_blob_content);
    else
      declare
        v_url    varchar2(500);
        v_result boolean;
        v_pos    pls_integer;
      begin
        /*v_pos    := instrb(p_autoname, '/');
        v_url    := '/psp.web/pspapps/' || p_dad_name || '/upload/autoname' || substrb(p_autoname, 1, v_pos - 1);
        v_result := dbms_xdb.createfolder(v_url);
        v_url    := v_url || substrb(p_autoname, v_pos);*/
        v_url    := '/psp.web/pspapps/' || p_dad_name || '/upload/' ||
                    p_file_id;
        v_result := dbms_xdb.createresource(v_url, p_blob_content);
      end;
    end if;
    p_blob_content := null;
  end;

  procedure all_to_bfile is
    v_bfile sys.utl_file.file_type;
    cursor c is
      select t.*
        from upload_file_t t
       where t.blob_content is not null
         for update;
  begin
    for i in c loop
      one_to_bfile(upper(i.dad_name) || '_ULF',
                   '$' || i.file_id,
                   i.blob_content);
      update upload_file_t t set t.blob_content = null where current of c;
    end loop;
  end;

  -----------------------------------------------------------------

  -- public
  procedure download is
    v              upload_file_t%rowtype;
    v_path_info    upload_file_t.name%type;
    v_disallow_msg varchar2(1000);
    v_blob         blob;
    v_bfile        bfile;
    v_by_name      boolean := false;
  begin

    v_path_info := owa_util.get_cgi_env('PATH_INFO');

    if v_path_info like '/fid/%' then
      select t.*
        into v
        from upload_file_t t
       where t.file_id = substrb(v_path_info, 6);
    elsif v_path_info like '/fname/%' then
      select t.*
        into v
        from upload_file_t t
       where t.name = substrb(v_path_info, 8);
      v_by_name := true;
    else
      begin
        v.full_path := v_path_info;
        select t.*
          into v
          from upload_file_t t
         where t.dad_name = owa_util.get_cgi_env('dad_name')
           and t.full_path = v.full_path;
      exception
        when no_data_found then
          null;
      end;
    end if;

    -- 从文件上传表中取走
    if v.name is not null then
      if false then
        -- v_dummy := k_file_secret.check_right(v_file_name, true);
        execute immediate 'select k_file_secret.check_right(:1) from dual'
          into v_disallow_msg
          using v.full_path;
        if v_disallow_msg is not null then
          k_exception.raise(null, null, v_disallow_msg);
        end if;
      end if;
      if v.blob_content is not null then
        wpg_docload.download_file(v.name);
        return;
      end if;
    end if;

    if k_ccflag.use_bfile then
      v_bfile := bfilename(upper(owa_util.get_cgi_env('dad_name')) ||
                           '_ULF',
                           '$' || v.file_id);

      if dbms_lob.fileexists(v_bfile) = 0 then
        raise_application_error(-20300, 'file is not exist');
      end if;
      owa_util.mime_header(v.mime_type, false, ccharset => null);
      if v_by_name then
        k_http.set_expire(sysdate + 1000);
        htp.p('Content-Length: ' || v.doc_size);
        owa_util.http_header_close;
        wpg_docload.download_file(v_bfile);
      elsif k_http.get_if_modified_since = v.last_updated and false then
        owa_util.status_line(nstatus => 304);
      else
        k_http.set_last_modified(p_date => v.last_updated);
        htp.p('Content-Length: ' || v.doc_size);
        owa_util.http_header_close;
        /*declare
         fexists boolean;
         file_length number;
         blocksize binary_integer;
        begin
          utl_file.fgetattr('DEMO_ULF','$' || v.file_id,fexists ,file_length,blocksize);
          htp.p(upper(owa_util.get_cgi_env('dad_name')) || '_ULF' || ',' ||
              to_char(file_length)  );
          return;
        end;*/
        --htp.p(dbms_lob.getlength(file_loc => v_bfile));return;
        wpg_docload.download_file(v_bfile);
      end if;
    else
      -- 从 xml-db repository 中取
      declare
        v_str              varchar2(500);
        v_url              xdburitype;
        v_res              xmltype;
        v_modificationdate date;
        v_content_type     varchar2(100);
        v_characterset     varchar2(100);
      begin
        v_str := '/psp.web/pspapps/' || owa_util.get_cgi_env('dad_name') ||
                 '/upload/' || v.file_id;
        v_url := xdburitype(v_str);
        --v_res := v_url.getresource(); -- oracle bug : will cause ora-600 error
        select to_date(substrb(extractvalue(v_url.getresource(),
                                            '/Resource/ModificationDate/text()'),
                               1,
                               20),
                       'YYYY-MM-DD"T"HH24:MI:SS.') +
               nvl(owa_custom.dbms_server_gmtdiff, 0) / 24,
               extractvalue(v_url.getresource(),
                            '/Resource/ContentType/text()'),
               extractvalue(v_url.getresource(),
                            '/Resource/CharacterSet/text()')
          into v_modificationdate, v_content_type, v_characterset
          from dual;

        k_http.set_content_type(v.mime_type);
        k_http.set_expire(trunc(sysdate, 'DD') + 1);
        --k_http.set_last_modified(v_modificationdate);
        k_http.set_last_modified(v.last_updated +
                                 nvl(owa_custom.dbms_server_gmtdiff, 0) / 24);
        if k_http.get_if_modified_since = v_modificationdate then
          owa_util.status_line(304, bclose_header => false);
        else
          wpg_docload.v_blob := v_url.getblob();
          htp.p('Content-Length: ' ||
                dbms_lob.getlength(wpg_docload.v_blob));
        end if;
        owa_util.http_header_close;
      end;

    end if;

  end;

  -----------------------------------------------------------------

  procedure set_full_path(p_file_id number, p_full_path varchar2) is
    v_file_id number;
  begin
    update upload_file_t t
       set t.full_path = p_full_path
     where t.file_id = p_file_id;
  end;

  procedure update_content(p_file_id number, p_auto_name varchar2) is
    v upload_file_t%rowtype;
  begin
    delete from upload_file_t t
     where t.file_id = p_file_id
    returning t.full_path, t.refered_count into v.full_path, v.refered_count;
    select t.file_id
      into v.file_id
      from upload_file_t t
     where t.name = p_auto_name;
    update upload_file_t t
       set t.file_id       = p_file_id,
           t.full_path     = v.full_path,
           t.refered_count = v.refered_count
     where t.name = p_auto_name;
    if v.file_id = p_file_id then
      raise_application_error(-20001, 'old/new file is the same');
    end if;
    utl_file.frename(get_dir_name(),
                     '$' || v.file_id,
                     get_dir_name(),
                     '$' || p_file_id,
                     overwrite => true);
  end;

  -- public
  -- 设置指定自动设定文件名的文件完整路径，并返回 file id
  function set_full_path(p_auto_name varchar2,
                         p_file_path varchar2,
                         p_file_name varchar2 := null,
                         p_replace   boolean := false,
                         p_suffix    varchar2 := null) return number is
    v_file_id     upload_file_t.file_id%type;
    v_file_name   upload_file_t.name%type;
    v_full_path   upload_file_t.full_path%type;
    v_pos         pls_integer;
    v_file_id_pre upload_file_t.file_id%type;
  begin
    if p_file_name is null then
      -- 如果不指定新文件名，则文件名和刚上传完的一样
      v_file_name := substr(p_auto_name, instr(p_auto_name, '/', -1) + 1);
    else
      -- 如果指定文件名，使用指定文件名，但是后缀继承刚上传完的文件名的后缀
      v_file_name := substr(p_auto_name, instr(p_auto_name, '/', -1) + 1);
      v_pos       := instr(v_file_name, '.', -1);
      if v_pos > 0 then
        --设置 fullpath 可以指定文件后缀,也会设置小写后缀
        v_file_name := p_file_name ||
                       lower(nvl(p_suffix, substr(v_file_name, v_pos)));
      else
        v_file_name := p_file_name;
      end if;
    end if;
    v_full_path := p_file_path || '/' || v_file_name;

    update upload_file_t t
       set t.full_path = v_full_path
     where t.name = p_auto_name
    returning t.file_id into v_file_id;
    if sql%rowcount = 0 then
      k_exception.raise(null, null, '您指定的文件"&1"的文件不存在');
    end if;

    return v_file_id;

  exception
    when dup_val_on_index then
      if p_replace then
        delete upload_file_t t
         where t.full_path = v_full_path
        returning t.file_id into v_file_id_pre;
        update upload_file_t t
           set t.file_id = v_file_id_pre, t.full_path = v_full_path
         where t.name = p_auto_name;
        return v_file_id_pre;
      else
        k_exception.raise(null,
                          null,
                          '文件路径"&1"已经被使用，请换文件名重试');
      end if;

  end;

  -----------------------------------------------------------------

  -- public
  -- 改变指定文件号的文件名
  procedure chg_name(p_file_id number, p_file_name varchar2) is
    v_full_path_old upload_file_t.full_path%type;
    v_full_path_new upload_file_t.full_path%type;
    v_dot_pos       pls_integer;
    v_slash_pos     pls_integer;
  begin
    select t.full_path
      into v_full_path_old
      from upload_file_t t
     where t.file_id = p_file_id
       for update;

    v_slash_pos := instr(v_full_path_old, '/', -1);
    v_dot_pos   := instr(v_full_path_old, '.', -1);

    v_full_path_new := substr(v_full_path_old, 1, v_slash_pos) ||
                       p_file_name;
    if v_dot_pos > 0 then
      v_full_path_new := v_full_path_new ||
                         substr(v_full_path_old, v_dot_pos);
    end if;

    update upload_file_t t
       set t.full_path = v_full_path_new
     where t.file_id = p_file_id;
  end;

  -----------------------------------------------------------------

  -- public
  -- 改变指定文件号的文件名
  procedure chg_path(p_file_id number, p_file_path varchar2) is
    v_full_path_old upload_file_t.full_path%type;
    v_full_path_new upload_file_t.full_path%type;
    v_slash_pos     pls_integer;
  begin
    select t.full_path
      into v_full_path_old
      from upload_file_t t
     where t.file_id = p_file_id
       for update;

    v_slash_pos := instr(v_full_path_old, '/', -1);

    v_full_path_new := p_file_path || substr(v_full_path_old, v_slash_pos);

    update upload_file_t t
       set t.full_path = v_full_path_new
     where t.file_id = p_file_id;
  end;

  -----------------------------------------------------------------

  -- public
  -- 增加文件引用数
  procedure add_reference(p_file_id number) is
  begin
    update upload_file_t t
       set t.refered_count = nvl(t.refered_count, 0) + 1
     where t.file_id = p_file_id;
    if sql%rowcount = 0 then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
    end if;
  end;

  -----------------------------------------------------------------

  -- public
  -- 减少文件引用数
  procedure del_reference(p_file_id number) is
    v_refered_count upload_file_t.refered_count%type;
    v_blob          blob;
    v_exists        boolean;
    v_dummy         number;
  begin
    update upload_file_t t
       set t.refered_count = t.refered_count - 1
     where t.file_id = p_file_id
    returning t.refered_count into v_refered_count;

    if sql%rowcount = 0 then
      k_exception.raise(null, null, '您指定的文件号的文件不存在');
    end if;

    -- 当引用数降低到0时，删除，
    --但是删除最好由系统任务处理，因为还有上传成功但控制层失败造成的废文件一样需要删除
    if v_refered_count < 1 then
      delete upload_file_t t
       where t.file_id = p_file_id
      returning t.blob_content into v_blob;
      if v_blob is null then
        utl_file.fgetattr(get_dir_name(),
                          '$' || p_file_id,
                          v_exists,
                          v_dummy,
                          v_dummy);
        if v_exists then
          utl_file.fremove(upper(owa_util.get_cgi_env('dad_name')) ||
                           '_ULF',
                           '$' || p_file_id);
        end if;
      end if;
    end if;
  end;

  -- public
  -- 清理过期无引用文件
  procedure purge_expired(p_timeout number) is
    pragma autonomous_transaction;
  begin
    delete from upload_file_t t
     where t.refered_count = 0
       and t.last_updated < sysdate - p_timeout / 24 / 60;
    commit;
  end;

end k_file;
/

