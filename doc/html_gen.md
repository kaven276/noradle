<script src="header.js"></script>

<div id="title"> HTML generation </div>

## design goal

* well formatted code
* shortest code
* coding tip to help remember names and prevent input errors
* efficient execution
* a minimum core
* support OOUI well
* support JS call and JS component init

## method 1: use p(k_xhtp) to generate html

## method 2: use upgraded p to generate html

	attr.d('name=value;name=value,..');
	attr.d('#id@name.class1.class2;');
	attr.id(v_id);
	attr.action(v_url);
	p.form_open();
	p.form_open(mand_attr=>..., ext_attr=>..., '#id.class1.class2;name=val;name=val);
	
This way, all attribute will place above the element
So when the p.el finished, it'll put all attr and output like   
`<form name="value" name="value" id="xxx" action="xxx">`

* all static valued attribute can use attr.d('name=val;name=val')
* all dynamic valued attribute can use attr.xxx(variable)
* then use p.some_el to gen the open tag or standalone tag

This way, you can format the source more easy.
And you can use *attr.* to list all available attr names
p.el will support attr that confirm the following rules:

* The attribute is a psp.web extention that has no corresponding attribute in html
* The attribute is considered as mandatory, such as a.href, img.src
* All manadory, url link, special meaning and extention attribute in a p.el API will has a determined order,
	This way you only code the value, but no need to code the name
* All optional attribute will provided by attr API, such as table.cellspacing
* All common attribute such as id,name,lang... will provided by attr API
* ID and Class will be in fixed attrs

p.el can keep a parameter if it meet one of the rules below:

* It's a PSP.WEB extension, for example, p.select(options_ex)
* It's a must used attribute(mandatory parameter), for example all url attributes, img.src, form.action
* It's a often used attribute(optional parameter), for example a.target, a.method, img.alt
  table[rows,cols], a[target,method], form[name,target,method], img[alt]
* It's boolean type or a name only attribute, for example defer, disabled, readonly, selected, checked
* It's often use variable for the value (to avoid string replacement)
* The attribute is not often used but is hard to remember, so we put it in the el's parameter

If a attribute can be used for many/every el, It's excluded out of *p* but add into *attr*,
For example, attr.lang, attr.tabindex, attr.contenteditable, attr.title, attr.accesskey


* p print
* a attribure
* s style

---

	p.attr('static atrs');
	p.styl('static styles');
	attr.d('static attrs);
	attr.d('one substitude?', val1, val2); -- note no st used here
	styl.d('one substitude?', val1, val2); -- note no st used here
	attr.width('dfsdf'); -- if no unit, add px
	style.color('color');
	p.tag_open(...);
	p.tag(...);

	p.div_open('#id.class1.class2;name1=value1;name2=value2;enabled=;name3;name4',st(value3,value4));
	p.form_open('#id;name=f1;method=get;target=xxx', action=>v_url)
	attr.cellspacing(5);  -- named attr with direct value
	attr.font_size('~em', v_fontsize);  -- named attr with replaced value 
	styl.table_layout('fixed');  -- named style with direct value
	attr.d('height=?em', v_height);  -- general attr with one replaced value
	style.d('margin:~px ~px', st(v_marginv, v_marginh));  -- general style with multiple replaced value using st
	attr.d('-myattr=value;-myattr=value');  -- for html5 fixed data-xxx attribute
	attr.d('-myattr',vale);  -- for html5 fixed data-xxx attribute
	attr.otype('classname');  -- for psp.web's ooui's object type
	attr.d('=otype');
	attr.oid(v_id);  -- for psp.web's ooui's object id, produce `data-ooui-id=xxx`
	attr.d('#t1.cls1.cls2;border=1;border:1px solid red;width=?em',v_width);
	p.table_open;
	
	styl.d('width:100px;height:20px;');
	styl.color('red');
	styl.border('1px solid red');
	p.css
	p.lcss
	
	where to place the attr parameter, at the begining or named or last ?
	
* as first para, all p.el will unify the style, but often we'll supply a empty attr


p.el([text],  mandatory_parameter, attributes, extension_parameters)
It's recommended to code a attr above the p.el line
Since writing all attribute/style in one p.el line will not formatted well.
This way, all p.el API can be designed and implemented easier.

'#id@name.class1.class2;attr=value;attr=value;css1:value;css2:value'
'id=id;name=name;class=class1 class2;attr=value;attr=value;css1:value;css2:value'
= ="
; "sp
'id="id" name="name" class="class1 class2" attr="value" attr="value"

## The special APIs for convenience 

### BR
p.br([p_repeat => integer])
So you donnot code p.br repeatly and can use variable to control the repeat count.


## The adjusted attrbute

for -> forp , size -> sizep

## output indent hierachy 

Can be set if keep indent hierachy

## API classification


### in header

	p.script(s), p.link(s)
	p.script_text, p.style_text
	p.style_open, p.style_close;
	p.script_open, p.script_close;
	p.js
	p.css
	p.meta_http_equiv
	p.meta_name
	p.base(base,target)

If p.js is in `<script>`, It is the same as p.line. If p.css is in `<style>`, It is the same as p.css.

### standalone empty content tags

	p.br, p.hr
	p.img, p.input
	p.script(s), p.link(s)
	p.iframe, p.frame(oc)

## element with url link

	link(href, ...)
	script(src, ...)

	form ( name, action, ...)
	frame ( name, src, ...)
	iframe( name, src, ...)
	xml ( id, src, ...)

	a ( text, href , ...)
	img ( src, ... )
	
### form

support left/right formatted layout with div/span wrapper

	p.fieldset_open;
	p.legend;
	p.form_open;
	p.label;
	... (as form input below)
	p.form_close;
	p.fieldset_close;
	
The result may be

	<fieldset>
	<form>
		<dl>
			<dt>xxx</dt>
			<dd><input type="text"/></dd>
		</dl>
		<dl>
			<dt>xxx</dt>
			<dd>
				<label><input type='checkbox|radio' value="xxx" /></label>
				<label><input type='checkbox|radio' value="xxx"" /></label>
				<label><input type='checkbox|radio' value="xxx" /></label>
			</dd>
		</dl>
	</form>
	</fieldset>


<label>this is <input type='checkbox' value='1' /></label>

### form input

	p.in_hidden
	p.in_text
	p.in_password
	p.in_file
	p.in_image (will submit name.x name.y)
	p.in_checkbox
	p.in_radio
	p.in_sumit;
	p.in_reset;
	p.in_button;
	p.button;
	p.select_open, p.select_close;
	p.select;
	p.option(s);
	p.opt_group;

form input name can be alias.colname
so we can auto gen code that's like this:
	
	v.colname1 = r.getn('v.colname1')
	or
	r.getc(v.colname1, 'v.colname1');
	
we can copy the result and paste in control layer package
As you see, all form input element may correspond to a plsql record type varaible,
that record var will used to insert or update the tables.

**[extension]**  
Since all input element type have the same tag *input*, some browser may not support [attr=xxx] css selector,
Such as iOS,Android support it, but Nokia,Microsoft mobile phone may not support it.
So you can tell PSP.WEB to automatically add class=type as well,
So that you can use input.type to select certain type of input elements.
To minimize the html size, PSP.WEB use single character to stand for the types, 
That is 

	t:	text 
	p:	password
	f:	file
	b:	button 
	b:	submit 
	b:	reset (erase)
	r:	radio 
	c:	checkbox
	
You see button/submit/reset have common classname b.
You can use *"p.auto_input_class"* to tell PSP.WEB you want to automatically add the classnames.
You can call it in k_filter or any other spot.

### tables

	p.table_open;
	p.caption;
	p.col;
	p.col_group;
	
	p.thead_open;
	p.tr_open;
	p.th, p.td
	p.tr_close;
	p.thead_close;
	
	p.tbody_open;
	p.tr_open;
	p.th, p.td, ...
	p.tr_close;
	p.tr(p.tds(st(...,...,...)));
	p.tbody_close
	p.table_close;
	
### tables with extention

	-- bulk operation support
	p.ths(st(xxx, xxx, ...));
	p.tds(st(xxx, xxx, ...));

	-- head/cols set
	p.

### list

	p.ul_open, p.ol_open
	p.li
	p.ul_close, p.ol_close
  
	p.dl_open;
	p.dt;
	p.dd;
	p.dl_close;

### text
	p.hn(1-6, text);
	p.p;
	p.div;
	p.span;
	p.a;
	p.b;

### universal 

	p.tag
	p.tag_open;
	p.tag_close;
	
### html5 

	p.section
	p.sidebar
	
	
## issues

### compact output can corrupt element with style display=inline-block

	Solution: keep all line break but cut all indent is well
	
### substitution

  Use ? for substitute , but if we should support named substitution.
The variable should be put into r or t.nv first, then you can use it.
So it has not much use, discard it.


<script src="footer.js"></script>