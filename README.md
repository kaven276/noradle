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
  pc.h;
  src_b.header;
  x.o('<table rules=all,cellspacing=0,cellpadding=5,style=border:1px solid silver;>');
  x.p(' <caption>', 'bind sql data to table example');
  x.p(' <thead>', x.p('<tr>', m.w('<th>@</th>', 'package name,created')));
  x.o(' <tbody>');
  for i in c_packages loop
    x.o('<tr>');
    x.p(' <td>', i.object_name);
    x.p(' <td>', t.d2s(i.created));
    x.c('</tr>');
  end loop;
  x.c(' </tbody>');
  x.c('</table>');
end;
```

### use json data service to populate chart

```plsql
procedure salary_share_by_job_id is
  cur sys_refcursor;
begin
  if r.is_xhr then
    open cur for
      select a.job_id, sum(a.salary) total from employees a group by a.job_id order by total asc;
    rs.print(cur);
    return;
  end if;

  common_preface('Pie');
  x.o('<div#links>');
  x.a(' <a>', 'Pie', r.prog || '?chart_type=Pie');
  x.a(' <a>', 'PolarArea', r.prog || '?chart_type=PolarArea');
  x.a(' <a>', 'Doughnut', r.prog || '?chart_type=Doughnut');
  x.c('</div>');
  x.t('<script>
  $.getJSON(location.pathname+"?data", function(data){
    var chartData = data.$DATA.rows.map(function(v,i){
      return {
        value : v.total,
        color : "#"+Math.floor(Math.random() * 256*256*256).toString(16).toUpperCase()
      };
    });
    demoChart[chartType](chartData);
  });</script>');
end;
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


