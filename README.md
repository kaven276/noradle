Want to build solid information system solely on PL/SQL and javascript easily,
no rely on any other programming language or technical stack? develop with NORADLE.

<center>![NORADLE](noradle_span_960.png)</center>

What's NORADLE?
=================

The word NORADLE is combination of node.js and oracle,
It aims at

1. write http servlet in PL/SQL with extremely concise code
2. with node.js as http gateway, give full http protocol support for oracle environment
3. node.js accessibility to oracle, give node.js ecosystem a real thustworthy db backend

take a first glance at pl/sql servlet code
==========================================

### bind data into html

```plsql
procedure bind_data is
  cursor c_packages is
    select *
      from user_objects a
     where a.object_type = 'PACKAGE'
       and rownum <= 5
     order by a.object_name asc;
begin
  b.l('<!DOCTYPE html>');
  o.t('<html>');
  o.t('<body>');
  o.t('<table rules=all cellspacing=0 cellpadding=5 style="border:1px solid silver;">');
  o.t(' <caption>', 'bind sql data to table example');
  o.t(' <thead>', o.t('<tr>', m.w('<th>@</th>', 'package name,created')));
  o.t(' <tbody>');
  for i in c_packages loop
    o.t('<tr>');
    o.t(' <td>', i.object_name);
    o.t(' <td>', t.d2s(i.created));
    o.t('</tr>');
  end loop;
  o.t(' </tbody>');
  o.t('</table>');
  o.t('</body>');
  o.t('</html>');
end;
```

### use json data service to populate chart

```plsql
create or replace package body chart_b is

	procedure common_preface(default_type varchar2) is
		v_chart_type varchar2(30) := r.getc('chart_type', default_type);
	begin
		src_b.header;
		o.u('<link rel=stylesheet/>', '[animate.css]');
		o.u('<script>', '[chart.js]', '');
		o.u('<script>', '[zepto.js]', '');
		o.u('<script>', '[underscore.js]', '');
		o.t('<canvas#cc width=600 height=400>', '');
		o.t('<script>',
				t.ps('
		var ctx = document.getElementById("cc").getContext("2d")
		 , demoChart = new Chart(ctx)
		 , chartType=":1"
		 ;',
						 st(v_chart_type)));
	end;

	procedure salary_min_max_by_job_id is
		cur sys_refcursor;
	begin
		if r.is_xhr then
			open cur for
				select a.job_id, count(*) cnt, avg(a.salary) avg, min(a.salary) min, max(a.salary) max
					from employees a
				 group by a.job_id
				 order by avg asc;
			rs.print(cur);
			return;
		end if;
	
		common_preface('Bar');
		o.t('<div#links>');
		o.u(' <a>', r.prog || '?chart_type=Line', 'Line');
		o.u(' <a>', r.prog || '?chart_type=Bar', 'Bar');
		o.u(' <a>', r.prog || '?chart_type=Radar', 'Rader');
		o.t('</div>');
		b.l('<script>
		$.getJSON(location.pathname+"?data", function(data){
			var salaries = data.$DATA.rows;
			var chartData = {
				labels : _.pluck(salaries, "job_id"),
				datasets : [
					{
						fillColor : "rgba(220,220,220,0.5)",
						strokeColor : "rgba(220,220,220,1)",
						pointColor : "rgba(220,220,220,1)",
						pointStrokeColor : "#fff",
						data : _.pluck(salaries, "min")
					},
					{
						fillColor : "rgba(151,187,205,0.5)",
						strokeColor : "rgba(151,187,205,1)",
						pointColor : "rgba(151,187,205,1)",
						pointStrokeColor : "#fff",
						data : _.pluck(salaries, "max")
					}
				]
			};
			demoChart[chartType](chartData);
		});</script>');
	end;
  
end chart_b;
```

What NORADLE provide?
=====================

* NORADLE support full dynamic(data driving) web development(whether for html page service or json data service),
  but more concise than PHP, J2EE, ...
* NORADLE NDBC make node ecosystem embracing oracle, expand node's realm to serious enterprise information systems
* NORADLE call out feature extend oracle PL/SQL to access external service/resource, break restrictions

Core thinking
==============

* use pl/sql stored procedure to implement application/business logic
  - servlet code that access data should be as close as the data, avoid complexity and develop-time and runtime overhead
  - all SQL should be in PL/SQL stored procedure, no string concat, no network transfer 
  - no triditional templating, print html/json with concise API, just use pl/sql, introduce no excessive templating language
  - give all function that a triditional servlet tech can provide, but be more concise and easier to master
  - be aware of that middle layer JAVA/PHP/.NET/PYTHON/RUBY... is superfluous, except adding comlexity
  - enjoy the good of oracle, advanced SQL, availility, stability, performance, scalability, tunable...
* node.js can access oracle, and vice versa, they can aid each other
  - node.js give oracle a http servlet container environment
  - pl/sql can call out by node.js, extending oracle
  - by node.js, oracle became a full servlet container, integrate code and data seamlessly
  - by connectivity to oracle, node.js ecosysetm will extend to the area of enterprise information system


the resource for NORADLE
========================

### [document site](http://docs.noradle.com/) http://docs.noradle.com
### [demo site](http://demo.noradle.com/) http://demo.noradle.com


about submodules
=================

note: from v0.14.0, noradle is split into several sub projects under <https://github.com/noradle>.

it's for those considerations:
* deploy only the sub-module you require, for example, in one server, you deploy noradle-dispatcher only
* each submodule is focused on one goal, easy to manage
* each submodule will evolve itself, allow contributors to improve just the submodule they are interest in
* each submodule represent a special aspect of noradle, doc/wiki will distributed among them, no longer a mess all in the main project

```text
 {{browser}}  -----------(http)-------------->  {{1.noradle-http}} ---        / {{noradle-console}}
http client                                   /                      \     /
     \--------(http)-> {{proxy(nginx)}} -----/              {{noradle-dispatcher}} <------ {{oracle}}  
                              \----(SCGI)---->  {{2.noradle-scgi}} ----/ /
                               \---(FCGI)---->  {{3.noradle-fcgi}} -----/    
                                   (note: 123 require {{noradle-nodejs-client}} )
```

the submodule list, all under [github noradle](/noradle)
* [noradle-protocol](/noradle/noradle-protocol)
* [noradle-dispatcher](/noradle/noradle-dispatcher)
* [noradle-oracle-server](/noradle/noradle-oracle-server)
* [noradle-nodejs-client](/noradle/noradle-nodejs-client)
* [noradle-http](/noradle/noradle-http)
* [noradle-scgi](/noradle/noradle-scgi)  (planing)
* [noradle-fcgi](/noradle/noradle-fcgi) (planing)
* [noradle-resultsets](/noradle/resultsets)
* [noradle-console](/noradle/noradle-console) (now obsolete when >=v0.14, will redesign )
