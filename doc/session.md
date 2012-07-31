<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title">  Session  </div>


Part 1 : session identification
==========

  MSID cookie:

  When a browser first access Noradle site, there is no MSID nor BSID cookie send, upon accept the request, Noradle will send back a refresh the same url response with new unique MSID,BSID cookie.

  When the browser refresh itself, it have the MSID/BSID cookie, if browser forbid permanent cookie, BSID cookie will in request at least, so when Noradle find ether of them, it has the client identifier.

  When the browser later start a new browser session and send the first request, MSID will in the request, Noracle will set-cookie for BSID with the normal response together, so not to lag the first response time.

Part 2 : session cookie security
======


Part 3 : use session agaist DOS attack
=======

  Noradle utilize MSID cookie(if not have, use BSID cookie) to count it's activity, if activity under one xSID cookie value is too high, it's considered it's a DOS attack, so Noradle will pause any malicious income connection, so  the attacker's process will block. And when the attacker's IP have too many connection already, new connection attempt must be refused to prevent a NodeJS or NodeJS like attacker program to utilize huge number of TCP connection to achieve high sending rate.

Part 3 : session data storage
=======



**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>