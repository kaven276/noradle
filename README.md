Noradle is for Node & Oracle integration. Noradle has three large parts.


The work at Now
==========

  To stabilize the runtime, improve oracle connection pool management, avoid idle occupation for busy-marked oraSock, timeout in some cases to release resource, reconnect if needed. Refactor to add wrapper for net.socket, that will have no chance to conflict with the system defined properties, so it'll more safe.

Overview
==========

1. psp.web. NodeJS act as http gateway to convert and pass http request data onto oracle PL/SQL procedure and receive and transfer back what the PL/SQL produce.
2. call in db driver. Provide javascript API to access PL/SQL page and facilities to product result sets and convert them into javascript objects.
3. call out net proxy. NodeJS can use PL/SQL API to send messages to any server through NodeJS router proxy and professional proxy and get the response messages in-process or out-process.

Part 1 : psp.web
==========

please see [Introduction of PSP.WEB](psp.web/blob/master/doc/introduction.md) at doc/introduction.md on github (format will lose)

please see [Introduction of PSP.WEB](http://www.noradle.com:8001/doc/introduction.html) at my site

please see [Deployment of PSP.WEB](http://www.noradle.com:8001/doc/deployment.html) at my site

please see [API demo of PSP.WEB](http://qht.noradle.com:81/demo/index_b.frame) at my demo site

please see [App dialbook developed on PSP.WEB](http://www.noradle.com/tjuc) at production clone site (you can use 18602247741 to login)

please see [License of PSP.WEB](psp.web/blob/master/doc/license.md) at doc/license.md

please see [Call oracle plsql stored procedure with javascript](http://www.noradle.com/doc/js_call_plsql.html) at doc/js_call_plsql.md


Part 2 : call in db driver
======

please see [js_call_plsql of Noradle](http://www.noradle.com/doc/js_call_plsql.html) at my introduction site


Part 3 : call out net proxy
======

please see [call external service from PL/SQL on Noradle](http://www.noradle.com/doc/call_out.html) at my introduction site