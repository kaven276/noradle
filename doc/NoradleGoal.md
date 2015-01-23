<script src="header.js"></script>

<div id="title">  Noradle Goal  </div>

  Full featured PL/SQL servlet architecture, especially for http protocol support and node javascript db access driver.

由来，溯源
========

  Noradle 是 NodeJS 和 Oracle 的互补协作体，目的是将 NodeJS 和 Oracle 进行整合。
它的由来要提到 Oracle 的 PSP(PL/SQL Server Pages) 技术，
PSP 和 JSP 一样，不同的只是使用 PL/SQL 存储过程作为服务器端的语言，
他的最大优势就是无需 SQL Driver，无需连接数据库和管理连接池，无需 OR-Mapping。
但是 Oracle 的 PSP 有两个硬伤：

1. 一是服务器架构完全依靠 apache mod-plsql 模块和数据库内的相关基础 PL/SQL 包支持；
2. 二是基于 Apache 的进程和资源管理架构。

这使得 PSP 想要实现完整的 HTTP 服务器架构非常不方便，
而且运行时性能也比较差。
而 NodeJS 的网络编程能力灵活而强大，
它完全可以替代 PSP 中的 apache + mod-plsql
来实现更加灵活且更容易不断演进和完善的服务器架构，
而 Oracle UTL_TCP 包的支持使得 NodeJS 和 Oracle 进程通讯成为可能，
最终 UTL_TCP 包成为了连接 NodeJS 和 Oracle 的关键纽带。

  NodeJS 的优势在于网络开发能力，
用 NodeJS 可以实现非常好的网络服务器，
能够完整的支持 HTTP 等协议。
而 Oracle 又有着最方便的数据操作手段，
因此把网络协议和网络相关的逻辑在 NodeJS 侧设计，
解放 Oracle，使得 Oracle 只处理和数据操作相关的逻辑，
这就形成了非常完美的分工。


从 PSP 到 psp.web
=================

  Noradle psp.web 就是 Oracle PSP 的下一代版本，
它将原先 PSP 中很多在 Oracle 侧实现的逻辑(和数据库表无关的)都搬到了 NodeJS 侧，
使得 Oracle 侧瘦身，更为精炼和稳定，
那些网络协议处理的部分，还有那些非常复杂和灵活的逻辑都放到了 NodeJS 侧，
利用 NodeJS 的超级灵活的设计支持能力，
实现原生PSP所无法实现的特性。
包括：

* http 请求结构的解析
* 灵活的 url to (db,dbu,procedure) mapping
* 负载均摊(distributed db, primary/standby db)
* 会话的自动生成
* 会话劫持识别和防范
* 会话超时的管理
* 跨 db 的统一会话
* CSS连接组件的临时存储
* 反馈页的临时存储
* 页面(响应体)压缩
* 防止用户不断重复刷新
* 服务器侧的响应(页面)缓存
* 响应 gzip 压缩
* 文件下载


  但是，也不是像一些 nodejs db driver 那样，
将 oracle 只当成是像 SQL Driver 一样，只是提供数据源服务，
Noradle 可以在 oracle 侧，用 PL/SQL 实现 HTTP servlet，
有关 http 请求的解析和预处理(header,cookie,servlet mapping,...)，
还有 http 响应(compression,caching,digesting)的后加工都外移到 NodeJS 侧完成，
oracle 只做简化了的和定制了的 HTTP 协议。
这其中 NodeJS 和 Oracle 的关系是关键的两条设计原则：

1. Oracle PL/SQL servlet 需要能够通过 PL/SQL 请求到获取到应用需要的协议请求数据项，
NodeJS 侧必须先做好协议请求的解析，
并以 Oracle 侧要求的方便的格式(就是按行分割的名值对)传送给 Oracle 侧，
并保存到包变量空间中。
也就是说应用逻辑处理核心是 Oracle 在 oracle 侧实现，
NodeJS 为 Oracle Servlet 服务，
并减轻 Oracle 侧的设计负担、开发负担和运行负担。
2. Oracle 可以通过返回给 NodeJS 响应头来控制 NodeJS 侧如何继续深加工 Oracle 产出的响应体，
包括压缩，缓存，原始响应的格式转化等等。
也就是说 NodeJS 需要提供各种各样的响应后加工服务，
但是控制权在 Oracle 侧，
servlet 的代码告诉 NodeJS 如何使用它们那非凡和强大的能力。

合理的分布逻辑到 nodejs/oracle
===========================

oracle 存储应用的数据，
也存储和执行将数据绑定到页面和处理数据的存储过程，
因此这部分功能会放到数据库中。
oracle 的多进程并发运行机制，
oracle 的分布式数据库功能，
oracle 的 data-guard 功能，
都使得将数据处理和数据绑定页面的逻辑放到存储过程上来是非常的具有可扩展性的。

nodejs 适合进行 http 解析，压缩，缓存，会话cookie创建，定位和负载均摊路由等工作。
但是它不会结合 oracle 中的数据，基本上只做网络处理，数据上只依赖于非常小的配置，
除了缓存外(其实也完全可以放到外部redis等内存数据库中)，
nodejs 侧应该不持有太大的数据，
因此存在内存限制的 nodejs 来支持互联网规模的超大并发访问应该是没有什么问题的，
至少不会出现内存不够用。
而除了压缩外，
真正消耗CPU的操作就是流的解析和拼装，还有压缩，
这些都不能算是非常消耗CPU的操作，
因此CPU一般也不会是瓶颈。

对于一个node app，
如果要将 oracle 作为数据存储，
那么使用 noradle NDBC 最为方便，
由于SQL已经在数据库存储过程中，
运行效率也会更高。

而对于一个 oracle plsql backend app，
有了 node 的支持，
可以使用 plsql 向 node 发送对外请求消息，
也可以同步接受 node 服务的同步响应，
从而大大扩展的 plsql 对外部世界的可访问性。

我认为组成一个完整的前台HTML5后台ORACLE的信息系统，
在所有设计方案中，只有 noradle 是最为精简的甚至是精简到极致的，
因为只需要学会plsql和javascript就可以完成绝大多数完整的信息系统。

Noradle 架构的设计目标
====================

只用 javascript 和 plsql 就可以简单快速低成本的开发出互联网热访级别的信息系统，具体目标：

* 简单
  - 安装简单：能安装 node，能安装 oracle 的环境下，无需任何额外软件包，无需配置任何环境变量配置文件，库连接就能安装，免 oracle driver
  - 语言简单：只用 plsql 就可以开发后台业务逻辑，javascript 可以开发前台UI和后台辅助性逻辑，无需第三种语言
  - 架构简单：不用管理连接池，不用 *connect then execute* code,  no frequent net round-trip
  - 数据处理简单：sys_refcursor to javascript data, no datatype conversion
* 灵活
  - url-mapping 完全可以自定义
  - 多数据库多实例的选取完全可以自定义策略
  - noradle.handlerHTTP 可以集成到任何 node http server 中，原生 http，express 等都行
  - noradle.handlerFastCGI 可以集成到任何主流的web server中，包括 apache, ngnix, light-httpd 等
  - noradle.NDBC 可以访问任何存储过程
  - noradle.SQL 可以执行任何 SQL
* 内置的高压环境支持
  - 利用 RAC, data-guard readonly physical standby database, distributed database 做负载分担
  - 会话数据可以跨 database instances (RAC, DG, DIST)
  - 会话可以跨多个 node instances, 前置一个按照会话ID值进行负载均衡分配的反向代理
  - all sql in db, dba 非常容易定位性能问题源，也方便采用资源管理分配策略
  - 支持可以及时和源同步的 result cache 机制
  - 支持 cache，客户端和服务器端的，可对 full/paritial response进行服务端缓存，权限检查不影响缓存的利用
* 低成本
  - 通过 data guard 进行负载分担，在保护数据的同时，不多买oracle授权，就可以进行扩容
  - 无需购买 web-logic, web-sphere 等**中间件**
  - 没有由于**中间件**而带来的额外的开发、运行、维护方面的消耗和负担
  - 非常方便DBA进行性能优化，所有引起性能问题的根源都在应用代码上，而都在noradle的pl/sql存储过程中，非常好定位。
  同时，noradle 提供 oracle hprof 对 servlet 执行进行 trace 分析，容易找出性能问题点。
  有了强大的性能优化支持，可以减少服务器、操作系统和数据库授权方面的初始投入和扩容投入。
  - 由于noradle的极致简单性，开发维护成本都相应降低


<script src="footer.js"></script>