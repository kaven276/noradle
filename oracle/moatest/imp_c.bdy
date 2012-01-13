create or replace package body imp_c is

  procedure bookmark is
  begin
    p.h(n, '页面抓取 ' || r.cgi('http_host'));
    p.a('页面抓取 ' || r.cgi('http_host'),
        'javascript:var s=document.createElement(''script'');s.src=''http://' || r.cgi('http_host') ||
        '/psp/s/loader.js'';document.body.appendChild(s);void 0;');
  end;

  -- private get_js_url
  function get_js_url return varchar2 is
    v_page_url varchar2(1000) := r.getc('page_url');
    v_js_url   grab_cfg_t.js%type;
  begin
    select b.js
      into v_js_url
      from (select a.js from grab_cfg_t a where v_page_url like a.src_url order by lengthb(a.src_url) desc) b
     where rownum = 1;
    return v_js_url;
  exception
    when others then
      return v_page_url;
  end;

  procedure load_js is
  begin
    if false then
      p.init;
      owa_util.mime_header('application/x-javascript', true);
    else
      p.doc_type('js');
    end if;
    p.s   := utl_url.unescape(r.getc('page_url'));
    p.url := get_js_url;
    if p.url not like 'http://%' then
      p.url := lower(r.cgi('REQUEST_PROTOCOL')) || '://' || r.cgi('http_host') || p.url;
    end if;
    -- htp.prn(p.ps('imp.load_js(":1",true);', st(p.url)));
    p.line(p.ps('imp.load_js(":1",true);', st(p.url)));
  end;

  procedure resp_begin is
  begin
    p.h('u:pw/imp_reply.js');
    p.script_open;
  end;

  procedure new_grab(js_url varchar2) is
  begin
    p.ps('new_grab(":1");', st(js_url));
  end;

  procedure add_page(page_url varchar2) is
  begin
    p.ps('add_page(":1");', st(page_url));
  end;

  procedure add_page(page_url varchar2, js_func varchar2) is
  begin
    p.ps('add_page(":1",":2");', st(page_url, js_func));
  end;

  procedure resp_end is
  begin
    p.line('finish();');
    p.script_close;
    p.body_close;
    p.html_close;
  end;

end imp_c;
/

