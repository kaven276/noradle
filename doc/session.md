<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title">  Session  </div>

会话数据都保存什么信息
==========

### 当前登录用户标识

  浏览器会话在服务器端保存的信息类别中，登录用户标识可能是唯一必须放到会话中的信息。这样一个会话才能知道是为哪个用户服务的。一些用户可的标识可能是复合用户标识，由集团用户标识和集团内的用户标识共同组成。

### 登录时间和最后访问时间

  和登录用户标识一起，记录登录时间，登录后每次访问该应用，更新最后访问时间。登录时间可以用于控制一个会话的最大生存时间，而最后访问时间可以用于控制一个会话的最大空闲超时时间。

### 用户 profile

  用户 profile 可能包括如一页显示多少条记录等个人配置信息，这类信息的有效期其实都是持久的，不会因为会话结束而消失，因为他们都是配置到用户profile表中的。因此，这些数据完全可以通过 result cache 机制实现缓存，而完全不必使用会话来保存这些信息。

  对于没有登录和注册的访问，可以针对用户终端浏览器或者针对 MSID cookie 记录用户 profile，和注册用户一样可以将 profile 保存到表中。当该 MSID 代表的终端注册并登录后，可以将绑定到 MSID 的 profile 信息迁移到新用户标识名下。这时不登陆，继续使用绑定到MSID下的 profile，单由于迁移可能已经是空的profile了，这时去系统默认的 profile 来服务。

   这样，profile 表的主键可以是和 MSID 一样的 22 字节 base64 hash 值，如果 profile 是绑定到MSID上，则直接在主键字段填写MSID值，如果是用户标识，则将用户标识进行 base64 hash 的结果保存到主键中即可。然后提供一个类别字段，来区别该记录是针对终端(MSID)还是针对注册用户的。

### 信息填写的中间状态

  除了绑定用户在当前会话的的身份外，会话数据另外应用的一种情况就是当用户在使用过程中不能在一个界面提交中完成一个事物的全部信息，而需要分解成多步界面完成最终提交，这其中各步提交的中间数据可以保存在会话中，待最终提交时完成写表等操作。但是这也不一定要通过会话数据实现，至少有以下几种方式。

1. 可以在下一步表单中使用 hidden field 和 ready only field 包含之前所有已填写表单的信息
2. 可以使用一张大的表单保存全部填写项，各部分填写项可以单独通过 ajax 提交来验证有效性，最后都完成后再一起提交
3. 如果是已知用户或登记的终端填写的这类表单，完全可以将每次提交的部分数据记录到最终生效的表中，只是该表单的状态标记为未最终提交，当用户最终确认后再提交才修改状态为正式提交。考虑到用户在填写表单的付出不应该因为会话结束或超时就清理掉，因此将未最终提交的信息写表也完全是推荐的做法。系统可以扫描未最终提交的信息，将时间较老的记录删除，保留距当前时间较近的记录。

### 总结

  可以看到只有前两种会话信息的生命周期是是和整个会话期相匹配的，用户profile其实是超越会话期的，而表单填写中间状态其实只是会话期间的一个片段。因此我们需要在浏览器会话上绑定的信息其实只有第一第二类信息，也就是当前登录用户标识、登录时间和最后访问时间等信息。

会话数据的保存地点
===============

会话数据可以保存在3个地方，也就是说有3个地方可以保存会话。

1. cookie: 他的核心特点是每次提交的http请求中会将cookie内容传递到服务器端，因此可以认为他是路途中的会话数据
2. 服务端会话，包括应用服务器上或数据库上的会话，作为最终完成数据的一部分，标志为进行中。
3. 客户端的，也就是说在一个隐藏的frame(对于使用frameset的情况)中可以一直持在界面上持有会话数据，也可以使用永久性的 browser database 中(包括 clientStorage 和 sqllite )


现在让我们来分析一下以上三种方式

### 使用cookie维持会话数据。

  使用cookie维持会话数据会增加通讯中http头的数据量，而这经常是不必要的，cookie的设计主要是解决标识浏览器会话来解决http本身无会话的问题，只适合承载会话全局的数据特别是会话ID，而不是关联到会话ID的数据或者某些任务的中间状态。而且cookie的大小本身就有限制，一个网站能保存的数量和数据容量也都很有限。psp.web 要求，只使用cookie跟踪会话标识，和会话标识绑定的具体数据可以存储在服务端或客户端。

### 服务端会话

  在服务端会话数据会增大服务端压力，但是如果服务端程序要经常访问这些会话数据的话，那么将会话数据保存在服务端就可以供这些程序直接使用，而不是再从前台或cookie中传递。

  服务器端的会话信息由于只需要在oracle侧通过PL/SQL访问，因此需要保存到oracle而不是NodeJS中，保存的地方有GAC和Table两种。

  GAC位于oracle共享内存中大小有限，不适合存储持久性信息，同时由于GAC缺乏数据的结构化支持，不方便存取复杂结构的数据，因此只适合存储绑定到活动会话的信息，典型的就是存储挥动会话的当前登录状态。

  但大部分会话信息都是从会话标识关联出的用户信息(profile)，这些信息往往都是超越会话器而要长期保有的，浏览器会话过后不会删除。因此大部分会话信息是需要持久存储的，也就是说应该放到表里。但是这些信息可能在每个页面请求的处理中都要用到，一定要保证从内存中直接快速得到，因此它们可以使用 result cache function 来实现内存化操作的性能要求。

  对于一些部分填写的表单数据，即使他们的保存期被规定限制在会话周期内，也应该保存到和表单结构一致的表中而不是GAC中，因为他们不像会话用户身份是在会话期间的每个请求都可能会用到的数据，放到内存中是不适当的。而他们是暂态数据，会有变化而且没有使用重复读，因此不适合使用 result cache function。当然对于暂态(不打算绑定到BSID或UID)会话数据，最好还是在客户端或cookie中保存，如果保存到表中，终究还存在产生数据库回滚和日志的负担，存在过期清理的负担。

  可以使用 vpd 对进行中的数据(私人profile)进行隔离，也就是说除非该请求指定查看进行中的情况，其他所有查询只能查到完成使得数据。

  如果将会话信息只是用户登录状态身份等有限信息的化，也可以考虑将会话信息保存到 NodeJS 测，然后对每个 BSID 和每个登录区域保存该BSID对应的登录身份，然后在每个请求中传递给oracle。不过认证过程肯定是在 oracle侧通过PL/SQL存储过程比对用户表数据进行的，其BSID和UID的绑定关系如何告知 NodeJS 也存在问题，还有就是如果 NodeJS 重启(这个比orace重启肯定更频繁)会话信息就会丢失。因此 Noradle 不考虑将会话信息(登录信息)放到NodeJS端。

### 客户端维护会话数据

  如果有客户端的javascript程序需要访问会话数据，那么该数据存储在在客户端了那当然是非常方便的了。特别是客户端程序需要和多个服务器联合作mushup的情况，各个服务器之间的协作只能靠客户端协调，因此一些会话数据保存在客户端就非常有必要。还有一种情况就是客户端的界面上自然保留着上几步的操作界面或结果，用不着每次都从服务器端使用。

   客户端尤其适合保存完全是私人性质的信息，这些私人数据只在客户端供用户使用(如果将它们保存在数据库端，也是和其他人的数据完全不相关的)可以满足界面程序的需要又不将信息泄露到服务器端。

   如果需要换到另外一台终端上使用，那么可以在上一个终端做保存到服务器操作，然后再下一个终端上导入私人数据。这种方式同时还起到了备份个人数据的作用。比如形成一个 json 数据文件的形式保存到服务端。



session identification
==========

Session ID in query string or hidden field is not supported
-----

  Session ID in query string have some drawback as:

1. session id in url is easy saw by others, in logs, so session hijacking is easy
2. If url is copied to others, he will get the same session as the original, no privacy at all.
3. A link without sid in url from other site will cause no session in the request page, but the user indeed have logged in the site

  Session ID in hidden field is better than query string when using http post method, but if use get method, it has the same drawback as using query string.

  So Noradle will use neither of them, and use cookie to denote a session.

例：机票预订应用程序支持URL重写，把会话ID放在URL里：http://example.com/sale/saleitems;jsessionid=2P0OC2JDPXM0OQSNDLPSKHCJUN2JV?dest=Hawaii. 该网站一个经过认证的用户希望让他朋友知道这个机票打折信息。他将上面链接通过邮件发给他朋友们，并不知道自己已经泄漏了自己的会话ID。当他的朋友们使用上面的链接时，他们将会使用他的会话和信用卡。

MSID cookie:
-----

  When a site want to recognize requests from the same client(browser), using IP will get no help, since IP for a give client is dynamic. So using persistent cookie is required. PSP.WEB utilize MSID (machine session ID) cookie for this purpose.

  When a browser first access Noradle site, there is no MSID nor BSID cookie send, upon accept the request, Noradle will send back a refresh-the-same-url response with new unique MSID,BSID cookie.

  When the browser refresh itself, it have the MSID/BSID cookie, if browser forbid permanent cookie, BSID cookie will exist in request at least, so when Noradle find ether of them, it has the client identifier.

  When the browser later start a new browser session and send the first request, MSID will in the request, Noracle will set-cookie for BSID with the normal response together, it's designed not to lag the first response time.

  MSID 可以用于终端识别，在 MSID 上绑定终端浏览器屏幕的宽高等属性信息，然后动态页面可以针对不同的终端属性生成和特定终端适配的页面。系统可以在后台记录每个MSID对应的终端属性信息，也可以对每组不同的终端属性组合进行hash得到终端属性值组合的标识。可以将每个MSID从记录完整的属性，升级到只记录对应的属性组合标识，这样可以大大减少冗余数据。还可以不在库表内记录 MSID 到属性唯一组合标识的关系，而直接将属性唯一组合标识值放到 cookie 中，这样每个请求到来后就可以直接通过 result cache 获取到具体的属性组合。


BSID cookie
----

  BSID is the acronym for "browser session identifier", It last during the entire browser session until the browser closed. We can confidently say that it's in the same browser session if the BSID in request is same.

  If all BSIDs to access all site during the same browser instance life is the same, we got the opportunity to relate different sites/apps to integrate each other.

  It's appeared that all sites/apps will have BSID preset for each browser session, you don't need to generate new BSID and send it to browser using Set-Cookie http response header. BSID is there, at Oracle side, the GAC client identifier is automatically set by Noradle, you can just set/get/rm GAC data, separate by each session with no conflict.

  不同域的 BSID 如何在同一个浏览器会话中确保相同呢？可以设置一个 BSID 生成服务器 site0，过程如下：

1. 当访问 site1 时，Noradle 发现没有 BSID cookie，就会返回一个到 site0 的重定向连接，上面带有随机码.
2. site0 可能发现该会话已经有BSID，那么就使用他，如果没有就新生成一个，并且通过 Set-Cookie 返回浏览器
3. site0 重定向到 site1，上面带有前面接受到的随机码
4. site1 继续使用该随机码在后台访问 site0
5. site0 查找记录，返回 site1 随机码对应的 BSID 给 site1
6. site1 得到统一的 BSID 后，使用 Set-Cookie 在本域设置和site0上相同的 BSID


  如果一个 Noradle 服务对一些自己的域设置了统一会话，那么就会去设置的会话服务器去进行重定向和后台查询关联关系。

  Noradle 提供标准的统一会话标识服务器，所有的 Noradle 服务器都只需通过设置就可以完成统一会话标识。第三方的应用使用标准协议也可以加入到统一会话标识服务中去。

  在统一会话标识的基础上进行统一认证就非常的方便了。比如说 site1 可以在后台去问 site2 指定的 BSID 对应的 site2 用户是谁。根据用户标识的关系可能分为以下三种可能：


1. site1 和 site2 使用同一套统一的用户管理，用户账号保存在其中的一方上，比如 site2 上。这时 site1 可以直接拿从 site2 获取的身份当前自己的身份。
2. site2 上保存自己的用户对应 site1 上用户的关系，将对应到的 site1 用户标识返回给 site1 直接使用
3. site1 是保存 site2 用户和本 site 用户的对照关系，从 site2 查询到的site2用户标识将在本地对照到本地的用户标识


xSID 生成算法
-------

  需要确保在所有的 NodeJS 服务器上生成 xSID 在全部时间内都确保唯一，同时要求已知的和未来的 xSID 值不可预测充分随机。因此引用以下成分：

1. javascript 系统时间值，从1970年以来的毫秒数
2. 当前毫秒内生成的第几次生成，和上面时间一起确保在同一个 NodeJS 服务器上值唯一
3. 当前访问域名。因为一个域名只会在一个 NodeJS 服务器上提供服务，也就确保了各个 NodeJS 上的 xSID 不同
4. NodeJS 服务器的 secret，使用它对上述3个成分进行 hMac，从而无法预测下一直和将来合法的 xSID 值

xSID 的范围
-------

  Noradle 的原则是尽量保证 MSID,BSID 的范围尽量的大(根据cookie协议最多到如 abc.com 的二级域)，因为这样可以帮助同一个域下的不同应用来共享同一个浏览器会话中的信息，比如说风格方案、分页的每页清单个数等等。由于会话信息放到 oracle GAC/Table 中，因此同一个库内的应用可以针对同一个客户端浏览器会话共享这些信息，而不同的库也可以通过dblink共享。

  但是，Noradle 可以保证，不同的浏览器的每次会话一定会使用不同的 BSID，BSID 相同一定是同一客户端浏览器的同一次会话。

会话的持久、可迁移
------
   这要数据库不宕机，GAC 中的数据不会丢失，只要在数据库关闭事件中自动保存 GAC 信息，并在数据库打开事件中恢复 GAC 信息即可。NodeJS 的重启对 GAC 持久行没有影响。而保存在库表中的会话数据就更不会丢失了。

会话、应用和数据库用户之间的关系
-------

  有可能一个数据库内的各个应用组成一个应用套件，其中一个应用就是统一认证应用，各个应用登录都是到该应用上进行，并且可以在后台看到同一个GAC会话登录状态。也可能一个用户管理应用可以对账号进行各种设置，而其他应用可以直接看到该设置。这时，需要统一的 BSID 跨越所有这些应用的网址。这时，该 BSID 一旦超时，就需要对该库内的所有应用用到的所有 GAC 进行清理。

  也可能一个数据库用户上面开发了两个应用，分别位于两个网址或路径，BSID 可能相同，这时清理会话数据时，就需要针对该用户的GAC进行清理，但是

  还有一种设计。就是所有的同一会话相关的app和dbu都使用同一个 GAC 存储会话信息，不同的会话相关的 app和dbu都使用不同的GAC存储会话信息。那么只要访问到一个会话覆盖的应用页面，就会更新它的GAC的LAT。


Session ID effect range and security consideration
-------


### 使用统一的二级域名范围的 BSID cookie 也可以增加措施保证安全

  如果会话cookie BSID 跨越整个二级域，那么该二级域下的子域名中的恶意站点就有机会得到二级域级别的 BSID cookie 值，然后攻击者可以用这些合法的存在的 BSID 去访问该二级域下的其他子站点，从而完成会话劫持。因此，BSID 最好确保只在可互信的站点间同步(相同)，当然，如果一个二级域名下的全部子站点都是统一管理可以确保互信的，那么可以将 BSID 设置到二级域名的级别。

  从上面的分析来看，似乎不应该在二级域名级别设置 BSID 会话cookie。但是对于在二级域名级别设置统一 BSID 的安全问题，可能通过设置额外的保护码来解决，保护码是每个独立子站点范围的 cookie，其他同二级域的子站点无法得知，就就防止了内部恶意子站劫持会话的问题。每个独立子站点都通过自己的 secret 合成 BSID 和站点前缀进行 hash 得到保护码，攻击者不知道特定子站点的 secret 就无法预测到保护码。这就确保了安全。各个互信子站的 secret 相同也没有关系，因为恶意子站看到自己子站点得到的保护码，并且知道自己站点的 secret，也无法得知其他子站的保护码和 secret. 最后得出的结论就是，互信站点间，特别是由同一个 Noradle 同时提供多个子站服务的情况下，完全可以使用相同的 secret 来设置保护码。

   为了保护 secret 不必破解和窃取，就需要定期改变 secret，为了能够验证超时到来前任意历史保护码，需要保持超过整个超时时长的历史 secret 记录。每个子站点服务器维护自己的一份 secret 历史记录，各个子站点间的 secret 没有关系且不必同步，一个子站点服务器上的多个子域名间可以使用一份共享的 secret 历史记录。

   secret版本号 + hash(secret + site_prefix + BSID) =  保护码，想要反推 secret 需要一定的时间暴力破解。如果在超时时限内完成破解，那么就可以使用还在有效期的 secret 推算出保护码，从而完成会话胁持，胁持后攻击者和原用户就无法从 cookie 上区分了。因此超时时间不能太长。这个超时只是保护码的超时时间，各个应用的超时时间必须要小于这个值，否则会被会话保护机制在应用自己超时前就被认定为会话劫持操作。比如说系统设置一小时前的 secret 作废，那么应用自己的超时时间就必须设置在这个之前。应用在超时时，会清理绑定的会话数据或者要求用户重新登录。

   变更保护码使得用户在长时间空闲后，必然要被安全机制拒绝访问。用户只能重启浏览器开启新的会话然后重新生成新的BSID和初始的保护码，或者也可以由 Noradle 新开一个会话，重新生成新的 BSID 和新的保护码，原先绑定到老BSID的会话信息就作废了，从而保证了安全。上述做法都会对正常访问的用户造成困扰，因此可以考虑如果用户发送的保护码是老的，就要额外采用其他手段来判断是否发生了会话劫持，如果全部检测手段都通过，则认为是正常访问，有一项检测失败都认为是会话劫持，从而重启新会话替代老的。

   判断会话劫持的其他手段包括：

1. 比对该请求的IP地址是否和最近上一次使用的IP地址一致，如果一致，就允许通过并且更能保护码。否则拒绝。当然用户也可能在上一次访问后不用并且移动到其他地点使用不同的IP再次访问，这时会被系统提示原先的会话空闲时间太长了，系统已经自动为用户启用新的空会话，可能需要重新登录认证的过程。
2. 检查会话开始时的 hash(accept*+user-agent)值是否变化，如果变化则是会话劫持。

  现在 BSID 会话标识可以在二级域范围进行设置，使得二级域内的各个子站点之间可以更容易的进行协作。比如说统一认证，可以在后台去统一认证服务按自己的 BSID 去请求对应的用户标识，如果没有获取则指示浏览器重定向到认证页面，认证完后再返回本站。如果不使用相同的 BSID，则要经过更为复杂的过程才能完成统一认证。

   当 Noradle 自己不会去管理绑定到 BSID 的信息什么时候超时，什么时候需要清理。那个是应用自己的事情。应该自己可以记录该 BSID 代表的会话的最后访问时间，并用它去进行超时清理。

   如果在服务器端保存每个 BSID 对应的最新保护码或者保护码的版本，

### 各个主机域名单独设置 BSID cookie 的分析

  对于不考虑虚拟主机的情况下，一个二级域名下统一管理的独立子站点数其实是非常的有限的，即使对没有独立子站点设置 BSID，也不会造成太大的负担。对于是虚拟主机的情况下，一个客户端一般只关心他自己使用的一个虚拟主机，而不会访问其他虚拟主机，因此针对独立子站点设置 BSID cookie 是可行的。

  对各个独立的子域名单独设置 BSID 后，就可以防止个别子站点轻松的恶意盗取其他子站点的会话，也无需额外的保护码机制来防范。

  使用站点独立的BSID后，一些无需BSID的静态网站就不会在每次请求中携带BSID cookie，从而减少了流量。

  独立子站点之间如果需要进行BSID同步，也可以通过BSID生成服务子站点来实现。对每个无BSID的访问，重定向到BSID生成服务子站，该子站确保针对该站本身有BSID存在，然后用随机码绑定该BSID，然后将重定向到源站点，url 中含有上述随机码，源站点使用该随机码在后台访问BSID生成服务子站从而得到相同的BSID值，然后使用它作为会话标识。

  当然上述精确控制的统一 BSID 在当用户的 BSID 泄露后可能发生会话胁持，对抗机制就上前面提到的保护码，但是保护码可能造成重新生成新会话标识并替代老的，这时就需要各个接入统一 BSID的子站点单独去

session cookie security
======

Prevention of Session hijacking
-------

### importand values

#### LAT

  保存最后访问时间，如果浏览器中送的 LAT(broswer) 比 LAT(server) 老较多(默认一分钟)则认为发生了会话劫持。
  同时，如果 LAT(server) 比当前时间较老，就需要更新 LAT(server) 和 LAT(browser). 这样只要看 LAT(server) 距离当前时间如果超过会话超时设置，就可以执行后台的会话数据清理。
  因为攻击者会发送较新的 LAT 模拟正常的访问，因此需要用 GUARD 保护 LAT。

#### GUARD

  Noradle 用 hash(secret,BSID,LAT) 来计算和 LAT 匹配的 GUARD. 会话劫持这使用老的 GUARD 只会和老的 LAT 匹配，而发送了老的 LAT 会被识别为会话胁持，发送新的 LAT 就需要重新获取新 LAT 对应的新 GUARD，因为不知到 secret，劫持者无法预测到新 LAT对应的 GUARD，从而实现了安全。只要 secret 安全，即使攻击这知道 GUARD 算法和其中的 BSID 和 LAT 也没有用，因为他不知到 secret.

  LAT 可以帮助 Noradle 知道用那个版本的 secret 来计算 GUARD 用于和请求中的 GUARD 进行比较。但是后台的 secret 不必和 LAT 的变化周期一样。因为即使后台的 secret

#### system secret

  系统密钥为随机生成，每个时间周期随机生成一个。需要保护的 LAT 可以准确的对应到一个 secret 周期，并使用该周期的 secret 来进行加密生成 guard。因为 secret 随时间变化，因此先要在一个周期内按以下方程式破解 secret 几乎是不可能的。

	hash(?secret?, BSID, LAT) = GUARD

### 通过和会话标识 BSID 绑定的经常变化的保护码 guard 来保护

  系统在一个浏览器会话期间会使用一个固定的 BSID，但是会伴随有一个每分钟变化的保护码，该保护码附加到 BSID后，作为 BSID cookie 的值返回给浏览器，服务器端在生成新保护码的过程中记录了每个BSID对应的保护码，因此能够知道浏览器发送的该保护码是否是合法的，如果 BSID 和保护码被窃取了，那么攻击者只能在该保护码的有效期内可能绑架会话，保护码一旦过期，攻击者必须重新窃取新的保护码才能保持绑架会话，进一步说，攻击者必须在有效期内赶快完成非法操作，这就对最终窃取信息或者篡改信息增加了难度。保护码是随机生成的，没有任何规律，因此攻击者无法猜到指定BSID的当前保护码是什么。

  用户浏览器会话第一次访问系统时，在生成新的BSID的时候，首先生成 22 位的随机会话号 cid ，该会话号在 oracle 会将被 dbms_session.set_identifier 设置成 GAC 的 cid。另外 BSID cookie 还包含 8 位的保护码 cid-guard，该保护码随机生成，和前面的 22 位 CID 连接成 30 位的 BSID cookie，并用 Set-Cookie 返回给浏览器做会话cookie。同时在 NodeJS 服务器端，记录 cid -> cid-guard 的关系。

  服务器端必须在设定的会话超时时间内的每个分钟都记录当时的系统 secret，这样如果一直空闲的会话在超时前再次访问，系统能够调出

  一个系统 secret 的有效期必须要超过一个超时时间，这样当将要超时前会话再次发出请求时，只要最近的两个时间段落的 secret 值去计算保护码即可，这就免去了保存和计算更多的保护码的开销。

  保护码必须要包含 LAT (last modified time) 最后访问时间的成分，它有两个作用：

1. LAT 在服务器端被绑定到 BSID 上，如果更老的 LAT 被发送(不是和 BSID 绑定的上一个和当前的)，则认定发生会话劫持。
2. LAT 可以用于判断会话超时，当收到的 LAT 太老，则可以报告会话超时错误
3. 当清理程序发现一些 BSID 绑定的 LAT 过老，则执行对该 BSID 会话的清理

### 超时cookie和保护码cookie的有效范围必须是当前 host

  LAT 需要单独的 cookie，有效范围为当前的 host，这样可以确保 LAT 的更新在浏览器和服务器同步。如果 LAT cookie 的有效范围到了整个二级域，那么该域下的其他 NodeJS 服务器上保存的 BSID->LAT 映射关系就不同不了。

  BSID 的有效范围是整个的二级域，而保护码只能是单个域，因为单个域的请求都会到同一个 NodeJS 服务器上，并且保存 BSID 对应的保护码对照关系。

  当该浏览器会话再此发出新请求时，Noradle 从 BSID cookie 中取出 cid 和 cid-guard 和自己记录的对照表比对，如果找到匹配则通过检查，没有找到则认定为发生了会话劫持操作。但是还要考虑一下两种特殊情况。

  情况一：如果前面请求已经造成更新对照表为新的 cid-guard，但是还没有通过 Set-Cookie 返回浏览器，而这时后面的请求携带这原先的 cid-guard 发送到 Noradle 服务器上，这时必须认定最近一次的老的对照关系依然有效，这样可以帮助顺利完成保护码的平滑切换。Noradle 如果发现 BSID cookie 中的保护码不和当前的最新绑定保护码匹配，但是和上一次的保护码匹配，那么也允许通过检查，但是不会因为原先的保护码时间过期而重新生成新的并通过发送cookie更新浏览器，因为前面的请求已经进行过保护码更新并且通过 Set-Cookie 更新了浏览器。

  情况二：如果 NodeJS 端重启了，那么全部 BSID 的保护码绑定关系就可能会丢失(如果退出前没能保存的话)，这时原先的浏览器会话提交的请求依然包括之前的 BSID cookie 和 GRD cookie，但是在 NodeJS 端发现没有该 BSID 的匹配项，这就说明匹配项在服务器端丢失了，这时认定保护吗有效，并且重新计算保护码并且记录 BSID 到新保护码的对应关系。

  本策略也存在一定不足，因为如果正常用户的浏览器会话一段时间内不用，保护码就一直得不到更新，这时如果攻击者使用窃取到的保护码访问系统，就实现了会话劫持。

### 通过客户端 IP 地址变化和固定请求头来检测会话劫持

  当系统生成新 BSID 值的同时，也会记录当时的 IP 地址，并且计算 (accept* + user-agent) 组合值的 digest，然后将 IP,digest 绑定到 BSID 上。当通过保护码没能发现会话劫持的情况下，继续查看请求的来源IP地址是否和绑定到 BSID 上的相同，如果不同，可能是用户移动中经常切换IP地址，也可能是发生了会话劫持。这时，重新计算 digest 看看是否和绑定到 BSID 的 digest相同，如果相同，Noradle 认为是发生了 IP 切换，同时更新绑定的IP为新IP；如果不同，则认为是发生了会话劫持，这时 Noradle 首先会对该请求的连接进行 pause 操作防止其发出更多的请求，同时会定时到一段时间后返回错误信息(这会让攻击方一直等待响应)，错误信息显示系统认为这是一个恶意会话，如果不是，则请用户关闭浏览器重新访问本系统。

use session against DOS attack
=======

  Noradle utilize MSID cookie(if not have, use BSID cookie) to count it's activity, if activity under one xSID cookie value is too high, it's considered it's a DOS attack, so Noradle will pause any malicious income connection, so  the attacker's process will block. And when the attacker's IP have too many connection already, new connection attempt must be refused to prevent a NodeJS or NodeJS like attacker program to utilize huge number of TCP connection to achieve high sending rate.


session data storage
=======

Session Data is stored in Oracle, not in NodeJS
-----

  Because Noradle psp.web will handle real logic in Oracle Database with PL/SQL. So all session data should be in Oracle that PL/SQL can easy access to.

Session Data is bound to BSID cookie value
------

  All session data should be bound to BSID cookie value, but it's indirect, because browser BSID cookie will update for a while(default to one minute) to improve security, so a browser session will have a series of BSID values, each of them represent a fraction of the browser session. But session data is bound to browser session, not a fraction of the browser session, So Noradle introduce internal BSID value that has the same value of the first BSID cookie value of the browser session. At oracle side, the GAC named BSID_MAP store the BSID cookie to interval fixed BSID value mapping, it use attribute as the browser cookie value, use value as the interval BSID value(fixed).

1. NodeJS find the browser have not BSID cookie yet, so make a new one and send (null,BSID) to oracle, oracle store BSID->BSID1 in gac as a mapping.
2. NodeJS find the BSID cookie is due to change, so make a new one and send (BSID(old), BSID(new)) to oracle, oracle delete or mark it to be delete for the old map, and add the new mapping.
3. NodeJS send the BSID cookie value to oracle, oracle use the map to convert cookie BSID to interval fixed BSID value, then use dbms_session.set_identifier(BSID1) to mark that the GAC data operation is all about this BSID1.


   If a req1 made a BSID upgrade, a req2 at the same time use the older BSID value, then NodeJS will find that the BSID is due to change, and it will make a new one and send (old,new) to oracle, oracle find the old value have point to the already changed BSID1, and will use the already exist GAC mapping to get the BSID1 value. The new value is too have effect


	req1 (null,BSID1) GAC (BSID1->BSID1)
	req2 (BSID1,BSID2) GAC (BSID1->BSID1 old) (BSID2-BSID1) save recent old BSID1 in GAC for cid=BSID2
	req3 (BSID2,BSID3) GAC (BSID1->BSID1 del) (BSID2->BSID1 old) (BSID3->BSID1)
	req4 (BSID2,BSID4) GAC (BSID1->BSID1 old) (BSID2->BSID1 old) find BSID2 is old, so cancel the Set-Cookie for BSID4

Session Data can be stored in GAC
-----

  Noradle will use BSID cookie value


  different apps should define their respective GAC namespaces to store their respective session data.

Session data should be simple
-----

  if it has complex structure, the data should be stored in session table instead of GAC. Session Table all will be defined with BSID as the key or first column of the key.

Session data can be saved in universal session object table(in experiment)
------

  bsid,key,value 组成，其中 value 为 session_bag type 的子类型，其中必然有 key 字段。

What info should be saved in session
-------

  Only info that's in effect during the whole browser session should be stored in GAC session. Logged in user id and timeout related info is this type. All other info that take only part of browser session should not be save in session.

One GAC context or multiple GAC context by different app
-------

  Because session in GAC store simple value only, so different app can use different GAC attribute name to store their respective values. Unless the same attribute name is used for different app or use, it'll not have conflict.


Clean up when session timeout
--------

  当会话长时间没有活动，那么就判断该会话超时。因为 LAT 在一定分钟内一定会改变，它可以被用来判断会话是否超时。当超时后，Noradle 直接生成新的 BSID cookie 取代老的值。这样绑定到原先 BSID 的会话数据就再也访问不到了，然后会由 Oracle 端后台进程进行清理。

  对用户来说，会话标识变更了原先的会话状态就丢失了，他可能需要重新登录各个应用，但是只要原先的操作是针对用户标识存储的，那么原先的操作结果都不会丢失。只有哪些只针对会话标识的状态和保存的数据会丢弃。在一般操作结果针对BSID或UID保存情况下，清理针对BSID的会话数据也不会产生什么问题。

  如果不同域的会话在同一个数据库下存储的化，可能相同值的BSID在两个域中重复出现，如果BSID生成算法可以确保不同的其中包含有域名成分，就可以保证所有域下生成的 BSID 都是唯一的。这样每个数据库对 BSID 在每个请求中记录其最后访问时间到GAC中，这样后台清理进程就可以查看所有超时的进程然后进行会话数据的清理。

   为了进行超时后会话数据的清理，Noradle 必须知道有哪些 GAC namespace 和会话表需要在超时后自动清理。如果一个DB内的每个应用想在自己的范围内进行登录，那么就需要建立多个 GAC namespace，然后分别管理他们的超时。所有的 Login GAC 都命名为 S#xxx 或 A#xxx，并且最终都使用 Noradle 提供的标准 API 进行访问，这样系统查询数据字典就可以知道有多少个用于登录的 GAC，在做超时管理的时候就有的放矢了。同样，当会话表的主键第一个字段是 BSID(varchar2(22))时，就认定该表为会话表，当超时到来时，就会自动清理该表数据。

   Noradle 后台每隔一段时间(默认1小时)进行一次超时会话的清理，他会查看所有的需要做超时管理的GAC，检查他们的 LAT 字段。为了能够得到当前全部 BSID 的清单，就必须先要知道系统中到底有哪些BSID存在，然后才能对他们的GAC数据进行清理。除非做登记，oracle 目前没有手段能够查看到系统中都存在哪些BSID。这就需要各个 GAC 在初次使用进行登记。每个BSID都在哪些GAC中有数据都必须被跟踪。或者说 (cid=gac,attr=bsid,value=lat) 的特殊 GAC 必须用于跟踪各个 context. 每个 GAC 的空闲周期参数也必被配置。

   每个用于会话信息的 GAC 都必须在 session_gac_t 中登记，包括 global context name，idle timeout threshold for LAT(last access time), max life time threshold for LGT(login time)。

   因为 BSID 都是在 NodeJS 侧生成的，因此 NodeJS 很好的掌握着全部 BSID 的生成时间和最后访问时间。但是当该 BSID 空闲超时后，该如果清理位于各个 Oracle 侧的 GAC，却是非常难办的。最效率地低下的办法就是调用每个和本 NodeJS 服务器相关的 oracle, oracle 按照 cid=超时BSID 对所有 GAC 进行清理。这回造成很多其实无关的 GAC 也要被清理。所以，如果能够知道每个 BSID 都对应哪些 GAC 就好了。



   或者后台GAC清理进程可以通过读PIPE来获得各个BSID的最后访问时间，从而更新自己的包变量哈希表最后访问时间。而且他完全可以通过

  Noradle 在二级域的范围提供统一的超时清理机制，当浏览器会话在整个域内的 Noradle 所有应用中都没有访问，到了超时门限后，Noradle 会自动的清理该域内全部 Noradle psp.web 应用的会话绑定数据，包括 GAC 和会话表。但是，如果单个应用希望自己的应用浏览器会话一段时间没访问就要清理会话，该应用可以自己记录会话对本应用的最后访问时间，当浏览器超时后在访问该应用，该应用可以自己先删除超时的会话数据，并提示用户需要重新登录系统。应用自己的超时时间如果设置比系统的短才有意义，如果更长的化，系统超时到了的时候，也会被应用的会话数据清理掉。也就是说应用可以比系统超时提前超时，但不可能比系统超时延后超时。

  BSID 保护码每分钟更新，可以从

GAC conflict problem
--------

  如果每个数据库用户的 GAC 即使 namespace 相同，也能通过 user 区分，那么就最好了，这样可以防止不同用户使用相同的 namespace 时的冲突。


Session and Authentication
==============

  会话只是提供会话标识和向 GAC 存取会话信息的服务，具体会话信息怎么用会千差万别，但是最需要可能也是在显示应用中唯一需要的应用场景就是身份认证。当会话通过用户名密码等方式的身份认证会，会将当前会话的用户身份保存到会话中，一般包含的信息项包括：

1. 用户标识
2. 登录时间
3. 最后访问时间
4. 登录是否使用密码
5. 登录是否使用手机号识别
6. 登录是否使用手机密码短信
7. 登录是否使用 ...

等等信息，其中针对每种登录方式都可能会有一个信息项记录是否采用了该方式登录，因此针对各个应用都要用到的会话登录状态管理，Noradle 提供了现成的支持，通过标准 API 帮助应用更为简单的实现会话身份管理。


和其他平台的比较
=======

php
-----

  php 的会话数据可以保存到内存、文件、SQLITE数据库中。但是 sqlite 不具备并行能力，而文件操作性能极差。基本上可用只有保存在内存中。但是当 apache 重启，php 会话信息也就丢失了。

.net
-----

  .net 可以将会话数据保存到内存，独立的进程空间或 sqlserver 中，但是性能较差。因为需要访问会话数据的进程要使用IPC甚至网络IPC进行通信才能读写会话数据。对于每个请求都要用到的会话身份等数据，这个性能损耗是不可接受的。

  .net 的 inProc 模式使得后台服务进程并捆绑死在对应的客户端浏览器会话上，完全没有扩展性，对单个用户也没有并发支持，基本上是不可能投入实用的特性。

Noradle psp.web
-----

  会话状态放到 GAC 中，直接由服务进程读写，保存在能够长期稳定运行不重启的 oracle database 中。

**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>