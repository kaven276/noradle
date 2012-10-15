<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

DCO 的组成部分
=========

Introduction
---------

DCO stand for " direct call out ", it let PL/SQL call external services outside oracle through ext-hub and NodeJS worker proxies.

Oracle process will establish connection to NodeJS ext-hub, send call-out request to ext-hub throuth that connection, ext-hub will route the request to the right NodeJS worker proxy according to the request PDU's header info. Worker proxy use API to send response(if it has) to the sending oracle process through ext-hub.

DCO ext hub 配置
--------

在 exthub\_config\_t 中，可以配置多条的 ext-hub 服务指向记录，系统会对 sts 字段为 Y 的记录逐一尝试，然后找到可用的 ext-hub server.

### Oracle Side

* dcopv 保存 DCO 特性的全部包变量
* `k_ext_call` (dco) 用于向 NodeJS ext-hub 写请求
* pdu 用于分析来自 ext-hub 的回复信息


### NodeJS Side
* StreamSpliter.js 用于对 TCP 连接的流进行 PDU 分割
* dco_proxy.js 使用该module 可以轻松的实现一个 worker proxy server, 只要书写 handler(dcoReq,dcoRsp) 即可
* ext_hub.js 运行该脚本可以启动对外请求代理的枢纽服务


API
------

#### dco.write

向请求体写入(追加)内容，格式为 raw

#### dco.line

向请求体写入(追加)内容，格式为 varchar2

#### dco.send_request

发送请求体，需要指明向那个代号的 proxy 发送请求，可以指定是否仅仅写 buffer，不真正发送出去(写一批请求后再一并发出)

函数版返回一个用于接受回复用的请求号，过程版直接发出不需要看结果。

#### dco.flush

将所有写在 buffer 中个所有请求一起发送到 ext-hub

#### dco.read_request

根据 dco.send_request 返回的请求号，等待对应的 blob 回复，可以通过 PDU API 来解析回复的 blob 内容。

#### dco.call_sync

直接发送(不缓存)请求，然后等待该请求的回复，结果返回到 blob 类型的参数中，同 dco.read_request 一样。


### 内部设计

#### 从 oracle 发往 ext-hub 的消息流

NO.1 int32 字节为消息的长度，大小包括前12字节的固定消息头。
NO.2 int32 字节为目标 proxy_id。
NO.3 int32 字节为发出请求的 oracle 的 audit session id 值

其余部分为透明的消息体。

到了 ext-hub，NO.2 int32 从 proxy_id 改为对应 oracle 会话下的请求流水号，再发送给 worker proxy.
请求流水号 ora_seq 为负代表该请求

#### ext-hub 与 oracle 的连接中断问题

如果 ext-hub 退出，则 oracle 到 ext-hub 的连接就会中断，而此时 oracle 无法收到这一事件，只能在实际发送数据的是否通过捕获异常得知，而且可能发出前面的数据不报错但是实际丢了，而发后面的数据时才报错。因此，为了确保 oracle 向外可靠的发送数据，就要求 ext-hub 在退出前要先通知 oracle 连接要中断。通过发送名为 'Noradle-DCO-EXTHUB-QUIT'，内容为 ext-hub 的 host:port 的 alert 消息，可以在每次 oracle 实际发送数据前有机会重新连接 ext-hub，确保完好可用的连接提前先准备好。

#### 进程退出保护和网络断开保护

ext-hub 在能够连接到 worker proxy 时，直接转发请求；否则排队请求，等待成功连接到 worker proxy 后在将排队请求全部发出。

worker proxy 在向 ext-hub 返回响应PDU时，如果到 ext-hub 连接中断，则进行排队，等待成功连接后，再将队列内容都发出。

为了防止进程退出造成队列数据丢失，队列内容必须要写到文件中。

或者在进程推出前，能够有机会执行一段代码，将内存中的队列存盘。

**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>