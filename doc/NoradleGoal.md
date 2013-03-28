<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title">  Noradle Goal  </div>


由来，溯源
========

  Noradle 是 NodeJS 和 Oracle 的混合词，目的是将 NodeJS 和 Oracle 进行整合，它的由来要提到 Oracle 的 PSP(PL/SQL Server Pages) 技术，PSP 和 JSP 一样，不同的只是使用 PL/SQL 存储过程作为服务器端的语言，他的最大优势就是无需 SQL Driver，无需连接数据库和管理连接池，无需 OR-Mapping。但是 Oracle 的 PSP 有两个硬伤：一是服务器架构完全依靠 apache mod-plsql 模块和数据库内的相关基础 PL/SQL 包支持；二是基于 Apache 的进程和资源管理架构。这使得 PSP 想要实现完整的 HTTP 服务器架构非常不方便，而且运行时性能也比较差。而 NodeJS 的网络编程能力的灵活而强大的，它完全可以替代 PSP 中的 apache + mod-plsql 来实现更加灵活更容易不断演进和完善的服务器架构，而 Oracle UTL_TCP 的支持使得 NodeJS 和 Oracle 进程通讯成为可能，最终 UTL_TCP 包成为了连接 NodeJS 和 Oracle 的关键纽带。

  NodeJS 的优势在于网络开发能力，用 NodeJS 可以实现非常好的网络服务器，能够完整的支持 HTTP 等协议。而 Oracle 又有着最方便的数据操作手段，因此把网络协议和网络相关的逻辑在 NodeJS 侧设计，解放 Oracle 只处理和数据操作相关的逻辑，就形成了非常完美的分工。


从 PSP 到 psp.web
=========

  Noradle psp.web 就是 Oracle PSP 的下一代版本，它将原先 PSP 中很多在 Oracle 侧实现的逻辑(和数据库表无关的)都搬到了 NodeJS 侧，使得 Oracle 侧瘦身，更为精炼和稳定，哪些网络协议处理部分，还有哪些非常复杂和灵活的逻辑都放到了 NodeJS 侧，利用 NodeJS 的超级灵活的设计支持能力实现。

* http 请求结构的解析
* 会话的自动生成
* 会话劫持识别和防范
* 会话超时的管理
* CSS连接组件的临时存储
* 反馈页的临时存储
* 页面(响应体)压缩
* 防止用户不断重复刷新
* 服务器侧的响应(页面)缓存


  但是，也不是将 oracle 只当成是向 SQL Driver 一样，只是提供数据源的服务，而是可以在 oracle 侧，用 PL/SQL 开发完成的 HTTP servlet，有关 http 请求的解析和预处理，还有 http 响应的后加工都外移到 NodeJS 侧完成，oracle 只做简化了的和定制了的 HTTP 协议。这其中 NodeJS 和 Oracle 的关系是关键的两条设计原则：

1. Oracle PL/SQL servlet 需要更够使用 PL/SQL 请求的获取到任意的协议请求数据项，NodeJS 侧必须先做好协议请求的解析，并以 Oracle 侧要求的方便的格式传送给 Oracle 侧，并保存到包边量中。也就是说处理核心是 Oracle，NodeJS 为 Oracle Servlet 服务，并减轻 Oracle 侧的设计负担、开发负担和运行负担。
2. Oracle 可以通过返回给 NodeJS 响应头来控制 NodeJS 侧如何继续深加工 Oracle 产出的响应体，包括压缩，缓存等等。也就是说 NodeJS 需要提供各种各样的响应后加工服务，但是控制权在 Oracle 侧，servlet 的代码高速 NodeJS 如何使用它们那非凡和强大的能力。

**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>