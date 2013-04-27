<script src="header.js"></script>

<style>
div.path{display:inline-block;font-size:smaller;}
blockquote{background-color:#eeeeee;white-space:pre;}
p{text-indent:2em;} li>p:first-child{text-indent:0;}
</style>

<div id="title"> Outstanding of PSP.WEB  </div>

		
PSP.WEB is a very different web framework that run PL/SQL on oracle database.
======================================

* no net traffic overhead between nodeJS http server and oracle PL/SQL

	* one http request sent only one PL/SQL request and got only one page result, the number of network round trip between http server and database is minimal. One http request sent all http header information and parameter to oracle and PL/SQL result will stream back to http server then to client/browser, very smooth.
	* No repeating sql text send to oracle, since they are coded in PL/SQL
	* No sql driver used, avoid sql drivers encoding/decoding or serialization/parsing overhead
	
* good server process management 
	* oracle connect to nodeJS server by tcp, so there is no need for sql driver
	* oracle will startup a number of job processes that will pre-connect to nodeJS
	* nodeJS gateway will manager the oracle connection as pool
	* PSP.WEB server job processes will quit when it processed a large number of request or after it live a long time, so the bad of leak is avoid

* avoid all dynamic work in oracle
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


## issues

### compact output can corrupt element with style display=inline-block

	Solution: keep all line break but cut all indent is well
	
### substitution

  Use ? for substitute , but if we should support named substitution.
The variable should be put into r or t.nv first, then you can use it.
So it has not much use, discard it.
	* all sql are writen in stored plsql that's has compiled form in oracle memory
	* all stored plsql is precompiled in oracle's shared pool memory
	* all sql use binding to execute, there is no sql text manipulation

* full control of sql and database manipulation

	In all the OR-mapping ways, it will generate sql not very effient, They will use all the columns, including the unrelated ones,
	They can not use the high level sql syntax such as analytical sql, sub-query, ...
	You can not use oracle's sql optimization hints...

* PL/SQL coding is so comfortable (with PL/SQL developer)

	* use table%rowtype to declare most of your variables, avoid OR-mapping repeating work and can use select/insert/update/delete with row-type variables, it's very convenient, and it's very exiting for programers.
	* all plsql/table/... oracle object will has coding suggestion
	* auto format with beautifier

* very handy API

	* use p.xxx, attr.xxx, styl.xxx to produce web page
	* use r.xxx to got all the request's information (http headers, cookies, url parts, parameters ...)
	* use t.xxx to do often used function
	* use tmp.xxx to save declaration code to store temporaly used data

* all stage result has a type of cache
	
	* query result cache can cache query result in memory
	* function result cache can cache configuration, logged user profile in memory
	* table scan can be cached in keep data pool and set cache option
	* a dynamic page can be cache in http server's
	
<script src="footer.js"></script>
