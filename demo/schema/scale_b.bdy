create or replace package body scale_b is

	procedure d is
		v_width varchar2(30) := r.getc('w');
	begin
		p.gv_scale := false;
		-- ;initial-scale=1.0;minimum-scale=1.0,maximum-scale=1.0
		tmp.s := 'initial-scale=1,user-scalable=no,width=?,height=device-height';
		p.meta_name('viewport', replace(tmp.s, '?', nvl('60', 'device-width')));
		p.comp_css_link(false);
		p.h(title => 'scale test');
		p.css('html,body{margin:0;padding:0;width:432;font-size:032px;overflow:hidden;}');
		p.css('div#c{width:320px;background-color:silver;font-size:48px;overflow:hidden;white-space:wrap;}');
		p.css('div>a{display:block;line-height:3em;}');
		p.div_open(id => 'c');
		p.div_close;
		p.line('<div style="font-size:20px;">hello</div>');
		p.p('width=' || v_width);
		p.p(r.ua);
		p.div_open;
		p.a('device-width', 'scale_b.d?w=device-width');
		p.a('320', 'scale_b.d?w=320');
		p.a('360', 'scale_b.d?w=360');
		p.a('480', 'scale_b.d?w=480');
		p.a('720', 'scale_b.d?w=720');
		p.div_close;
		p.tag_open('script');
		p.print('var v_from="' || r.getc('from', '..') || '";');
		p.print('<!--
		var ua,w,h;
		if (window.navigator)
			ua = window.navigator.userAgent;
		else if (window.clientInformation)
			ua = window.clientInformation.userAgent;
		//alert(ua);
		var c=document.getElementById("c");
		var show=ua;
		
		if (window.screen) {
				var w = window.screen.availableWidth || window.screen.width;
				var h = window.screen.availableHeight || window.screen.height;
				
				//alert(w+"*"+h);
		} else w = h = "";
		if (window.location) {
			var l = "./mp_detect_b.save_set?w="+w+"&h="+h+"&ua="+encodeURIComponent(ua)+"&from="+v_from;
			// alert(l);
			// window.location = l;
		}
		c.innerHTML = [ua,
		,"---"
		, "window.screen.availableWidth"
		, window.screen.availableWidth || "null"
		, "window.screen.width"
		, window.screen.width || "null"
		, "document.documentElement.clientWidth"
		, document.documentElement.clientWidth
		, "window.innerWidth"
		, window.innerWidth || "null"
		, "document.documentElement.offsetWidth"
		, document.documentElement.offsetWidth
		].join("<br/>");
		-->');
		p.tag_close('script');
	end;

end scale_b;
/
