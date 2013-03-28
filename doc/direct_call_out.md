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

#### dco.read_response

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


PDU ( oracle to ext-hub )
-------------------------
1. PDU length ( Int32BE, negative 代表单向无需回复 )
2. proxy id or conn id (Int32BE, positive for preset proxy id, negative for dynamic connection)
3. in session id(sequence) (Int32BE)

PDU ( ext-hub to worker proxy )
---------------------------------
1. PDU length ( Int32 )
2. oracle sid
3. in session id(sequence) (Int32BE)

PDU ( worker proxy to ext-hub)
---------------------------------
1. PDU length ( Int32 )
2. oracle sid
3. in session id(sequence) (Int32BE)

PDU ( ext-hub to worker proxy)
---------------------------------
1. PDU length ( Int32 )
2. oracle sid
3. in session id(sequence) (Int32BE)


其中
* 第一个参数都是 length(UInt32BE)
* 第三个参数都是 in session id
* 第二个参数在 oracle 发送时是 proxy id，之后都转换为 oracle sid，用于找回发出DCO请求的oracle连接。


#### ext-hub 与 oracle 的连接中断问题

如果 ext-hub 退出，则 oracle 到 ext-hub 的连接就会中断，而此时 oracle 无法收到这一事件，只能在实际发送数据的是否通过捕获异常得知，而且可能发出前面的数据不报错但是实际丢了，而发后面的数据时才报错。因此，为了确保 oracle 向外可靠的发送数据，就要求 ext-hub 在退出前要先通知 oracle 连接要中断。通过发送名为 'Noradle-DCO-EXTHUB-QUIT'，内容为 ext-hub 的 host:port 的 alert 消息，可以在每次 oracle 实际发送数据前有机会重新连接 ext-hub，确保完好可用的连接提前先准备好。

#### 进程退出保护和网络断开保护

ext-hub 在能够连接到 worker proxy 时，直接转发请求；否则排队请求，等待成功连接到 worker proxy 后在将排队请求全部发出。

worker proxy 在向 ext-hub 返回响应PDU时，如果到 ext-hub 连接中断，则进行排队，等待成功连接后，再将队列内容都发出。

为了防止进程退出造成队列数据丢失，队列内容必须要写到文件中。

或者在进程推出前，能够有机会执行一段代码，将内存中的队列存盘。

Direct Call Out 应用场景
=========================

应用场景有两大类

1. 将数据库事件实时同步到外部
2. 数据库存储过程调用外部服务完成自己本身的功能
3. 定时器
4. DCO 用于向 websocket 服务器发送更新信息

将数据库事件实时同步到外部
--------------------------

### 作为数据库事件源向外传播的应用场景

  1. 短信表插入事件，导致对短信代理程序的调用
  2. 企号通群组成员变化的事件，导致到 IM Server 的数据更新，进而导致到全部属于该群组的在线用户界面的更新
  3. 新用户的加入自动同步到新浪微博等等合作伙伴的系统中
  4. 写工单表操作结束后，通知该事件到 pipe，由后台自动调用短信等手段通知到相关人员
  5. 有企号通新人注册，可以在 nodejs 监控界面实时看到

### 对数据库数据变化的事件的捕获和处理

  表上的 trigger 监听表的变化，将其 rowid [, table name, handler name, operation(update,insert,detete 等等)] 发往 pipe 中，然后由后台程序使用 DCO 向外调用。这样对前台的影响最小，而且可以将变化事件传播到外部。


  数据库事件监听后，往往就是根据线索 rowid 生成完整的对外请求 PDU。那么，可以设计一个特殊的 pipe PDU,该PDU标识为动态执行指定的存储过程，并带入线索号参数（一般线索号为 rowid）这样对外请求 PDU 总是可以根据需要生成合适的格式。

### 对数据库内各种操作的捕获和处理

比如登录数据库，各种异常，实时性能统计等等
这部分不是通过 trigger 完成，而主要是在现有代码上增加 DCO 调用


作为客户端实现访问
----------------

可以实现的协议包有

1. soap client. 但是是将 json 或 json/yaml 格式的数据，其实生成 yaml 格式的数据相对还是比较简单的，而且也容易找到现成的解析器
2. SGIP PDU
3. SMPP PDU
4. GET Email
5. Send Email
6. Get FTP
7. 获取当前登录用户的手机号

* 调用外部 http 服务* 调用外部 web service 服务
* 存取外部 ftp 服务器上的文件
* 存取外部 pop3 服务器上的邮件，可以定期看有没有自己的邮件，有的化将邮件当成是异步请求
* 存取文件系统上的文件



利用 oracle 定时器定时执行 NodeJS 任务
-----------------------------------

Oracle 有着非常完善的定时调度系统，这恰恰是各种后台应用平台所欠缺的，特别是 NodeJS.
这时，可以通过 Oracle Scheduler 系统定时调用存储过程来将启动信号发往 ext-hub，
ext-hub 将把信号发往目标 worker proxy, worker proxy 收到启动信号后，则执行相应的定时任务。

范例包括，oracle 指定每天让 NodeJS worker proxy 采集每个网站新的新闻和图片，然后上传到 oracle 数据库中。

甚至 javascript 可以调用 oracle 生成定时任务，然后发送给自己触发信号。
Noradle 可以提供


DCO 用于向 websocket 服务器发送更新信息
------------------------------------
对于 IM 应用来说，当各个群组成员维护出现数据变化时，可以通过 DCO(或 message stream) 直接向 websocket server 发送更能数据。
这样 websocket server 的基础数据或相对静态的数据总是可以实时更新的。
而 websocket server 的静态数据更新还可以同步到所有的客户端浏览器中。
对于更新 PDU 到 javascript object 的转换可以在客户端和服务端共享同一个解析包。
PDU2JSO(pdu) return js object。


设计考虑
==========

借鉴 WebSocket 的设计
--------------------

一、WebSocket协议看上去是 http 协议
WebSocket 协议的目标是任意两个节点的无阻碍双向通信，并且可以借助标准的 http proxy/gateway/tunnel 进行中转，这个功能对 BS 模式通信非常重要，可以利用现有的网络中转服务。
但是对于 Noradle psp2node 功能来说，确不重要，因为 NodeJS proxy router 总是要放在和 oracle 一起的内网。
而该 NodeJS ext-hub 总是可以使用类似于 websocket 协议和 worker proxy 通信，甚至可以采用 ssl 进行加密通信。
因此关于利用 http upgrade 的设计其实对 Noradle psp2node 功能是不需要的。

二、WebSocket支持 framing
参考 WebSocket 协议，它支持 framing，主要是为了避免 buffer 完整的大消息，和使用 multiplex 防止一个大消息占用完整的通道。
对于 Noradle 来说，不同的 oracle 进程可以同时各自建立到 ext-hub的链接，并且同时监听和处理 DCO 消息，因此不存在大消息占用完整通道的问题。
同时，对于单一 oracle process 要同时发送多个消息的情况，Noradle 使用内存 blob 缓存任意大小的消息，然后依次发送完整的消息，内存占用大小根本就不是问题，因此完全可以不采用 framing 的复杂设计。

三、WebSocket分为 text 和 binary frame
Noradle 的 PDU 的内部结构完全可以包含文本和二进制内容，因此无需区分 text/binary PDU

四、WebSocket 支持 mask (只要求从浏览器客户端到服务器的通讯加密)
因为从用户终端发往服务器的数据可能带有私人敏感数据(如用户名密码等等)，而服务端的返回结果往往相对不太私密。所以 WebSocket 要求单向做 mask.
但是考虑到 Noradle 中，oracle 向 NodeJS proxy router 的数据流都在内网，而且都是服务器之间的通信，因此完全不需要做任何安全措施。
这不光不需要进行 mask ，也不许要 ssl。如果增加安全措施，反而会浪费处理资源，白白增加无谓的消耗。

五、WebSocket  支持灵活紧缩的 PDU 长度标识
Noradle 认为都使用 UInt32BE 写下 PDU 长度也不过占用4个字节，因此没有必要做太细的设计。因为虽然可以节省两三个字节，但是接收端的处理更为复杂，给开发和运行带来负担，最终并不划算。

六、WebSocket 支持 ping/pong frame
只要 oracle 进程在，其持有的到 ext-hub 的连接都不会断，一旦断了就会重试，如果连接不上就会是下一个 ext-hub server。
oracle 发起的 TCP 不会超时自动端掉，而 NodeJS 也不会超时自动断掉 socket server，而且 oracle 无 buffer TCP 发送如果遇到问题一定会报错，
也就是发送 PDU length 的时候一定会报错，因此完成可以重新连接并且重发。
因此 ping/pong 所起的检查连接可用和保持连接(防止超时自动断开)的功能根本就无需使用。

七、WebSocket close control frame
在 Noradle 中，oracle 到 NodeJS proxy router 的连接永远都不应该关闭，因此根本就无需 close frame.

结论：Noradle 中 oracle 向 NodeJS proxy router 发送对外请求 PDU 的协议，不用向 WebSocket 那么复杂，可以非常的简单。


PLSQL API with nodejs support
--------------------------------------
分为基于消息的和面向连接的2类，一般只需要使用基于消息的。
目标是最简单的 plsql API 对外调用接口和实现代码，oracle 只负责将请求参数提供，其余实现部分尽量放到 worker proxy 去完成。

* 对各种网络协议服务端的访问，只需根据具体需要，设计中最小和最简单的 plsql API 即可，其他方面都在 worker proxy 中实现
* plsql API 只管考虑怎么容易被调用，自己怎么容易实现即可，麻烦的细节都交给 worker proxy 去实现好了
* 从 oracle 到 worker proxy 的消息格式更适合于 oracle 生成和 javascript 解析即可，对于同步回复要适合于 oracle 解析，javascript 生成。
* 我们的设计并不是为了实现固有的网络应用协议，真正的目标还是能够使用 PL/SQL API 调用网络协议，这才是真正的目的。
* worker proxy 是对外调用协议的实现，plsql API 是对外调用的编程接口，他们通过 ext-hub 进行远程调用。
* 需要什么功能就设计什么 plsql API，该功能的实现放到 worker proxy 去，配对使用。

ext-hub 存在的必要行
----------------

如果使用 NodeJS router API，可以：
1. 不必设置专门的 daemon 进程向外发送消息，而是直接向 router proxy NodeJS server 发送消息即可。
2. 全部消息可以进行 multiplex，不同的 oracle 进程的对外访问，通过 router proxy 全部通过一条链路转发到 worker proxy 中
3. 可以实现会话。

标准的 NodeJS router proxy server 是必须的，因为：
1. 全部来自 oracle 的连接和请求发送可以统一连接到此处，简化了 oracle 端的配置和运行负担
2. 可以有效的转发到各种各样的专业 proxy，支持动态配置，支持 SSL 向外部 worker proxy 连接

当有了统一的标准 NodeJS router proxy server 后，在 oracle 端也就没有必要通过 pipe2tcp daemon 中转对外请求了。


Multiplex
---------------

能够实现 multiplex，也就是每个 oracle 进程只需要连接一个 NodeJS 代理服务器 ext-hub，就可以间接的实现到全部外部服务的连接。原先一个 oracle 进程需要向多个服务器的连接多路复用到一个 NodeJS 连接上，需要在每个发往 ext-hub 的消息头上都追加路由代号，也就是ext-hub 再向外连接时使用的 worker proxy ID。这样，oracle 就可以按照 Noradle DCO PDU 发送消息，消息都会转发到最终的真实的目的地这样，每个 oracle 进程的每个对外连接请求都会转换为 ext-hub 到 worker proxy 再到最终外部服务的连接，这就带来了一个问题。对于像 SGIP 这样的协议，其实一个 oracle 库中的哪个进程访问 NodeJS SP 代理服务都只需要 NodeJS proxy router 建立一个到 SP 代理服务的连接就够用了。当 oracle 需要对外同步请求时，发出请求后会等待回复，这时 oracle 可以同时发出多个目标地址的请求，然后等待其中的任意一个返回结果。还可以发出请求后，先做写别的事情，完了再接受结果。这样 oracle 的对外网络调用就会更加灵活。特别是可以等待并发请求的同步回复，这将大大提高 Noradle 进程的 CPU 利用率，在需要结果返回的时候才等待结果返回真是太棒了。这样每个 psp.web 页面请求可以将发出全部外部调用，然后在生成页面的过程中，需要哪个响应就等待哪个响应好了。


PDU format
-------------

  This include request and response PDU format both.


  1. 包长度 UInt16BE，最大 PDU 支持 64K；负数代表需要同步返回结果
  2. header(fixed) 包括路由目的地
  3. 固定部分属性，每行一个参数，对应于 function call 的固定参数部分
  4. 可选部分，一些可选参数可能有也可能没有，采用每行 name:value 格式设置，相当于 function call 的 option 参数
  5. TLV （可能有压缩标志一个字节、消息协议类型号 1 个字节共支持 256 种）为了节约传输量，对每个命名可选参数都使用压缩的 type length

考虑匹配 javascript typed array 发送数组数据，使用一些可以直接用 general binary parser 解析成 json 数据的模块的格式。

### PDU 格式需要同时满足 PL/SQL 读写和 Javascript 读写

	PL/SQL 需要写请求 PDU 给 Javascript 读，同时 Javascript 需要写回复并且给 PL/SQL 读取。

	PL/SQL 需要利用 dbms_lob, utl_raw 中的 API 来完成读写 API 设计，

	但是同时需要 Javascript 方便的读 PL/SQL API 写的内容，也方便的写 PL/SQL API 需要读取回复的内容。

	Javascript 是 buffer based API，建立在 nodejs buffer 读写 API 的基础上。

	javascript 的 buffer 读写最好可以利用一个好的 nodejs binary parse 库

PL/SQL raw 支持的类型有 float(4), double(8), binary_integer(4), varchar2, nvarchar2

  一般 oracle 向 nodejs 写请求，来自数据库的信息都可以统一按照分行写即可，不必使用专门的数字和日期类型。
  因为 javascript 的数字类型是 64-bit 数，和 oracle 中的 float,double,binary_integer 都不一致，
不如就直接当成字符串写出。
  同时 javascript 的日期类型其实就是从某时开始的秒数，应该就是数字类型，依然不是 oracle 直接支持的类型，
因此不如直接将 oracle 的 date 类型已 javascript 的 new Date(string) 格式输出即可。
  当然，也可能 nodejs proxy 也就是将请求透传到下游服务上，那么 PL/SQL 直接输出下游服务需要的 binary 格式可能就比较合适。



### 页面输出，DBCall 响应输出，DCO 请求输出等三个输出场景应该尽量统一输出 API。

对于 direct call out 来说，统一到使用 pv.entity 来输出内容存在以下问题：
1. 输出字符集问题，页面输出需要使用某一个字符集，而对外发送消息需要使用标准的 utf8 字符集或其他字符集
2. 多消息必须依次生成和发出，不能重叠。同时写页面过程和消息生成发送也不能有重叠

以后可以考虑设置多个 pv.blobs ，可以在会话中指定当前写那个 pv.blobs(i)，然后响应的 API 写这个 blob。
甚至可以考虑使用 write class 比如 html, xml 等等，它们都可以绑定指定索引的 pv.blobs(i)，然后通过 API 对其进行输出。
这样，可以同时写多个 blob，一个用于页面输出，一个用于动态的 css，多个用于对外请求PDU。


如何确保 DCO 消息可靠的发出
----------------------------------------

DCO 的可靠性受到以下方面的威胁

1. ext-hub , worker proxy 进程退出，重启，网络连接中断
2. tcp socket 中的消息出现窜位
3. DCO 请求和回复不对应
4. 请求量太大，超出 worker proxy , ext-hub 的可缓存量和处理能力

因此可以看到，最终还是应该使用 direct-call-out 方式发送对外消息。
这样，一旦写 socket 失败，就可以立即尝试其他的 ext-hub 发送，
如果都不能发送成功，就可以等待一会再重试，直到有 ext-hub 启动正常运行为止。

ext-hub 若不能将消息转发到 worker proxy，就应该将消息自动追加到队列日志文件中，这样可以确保发送到 ext-hub 的消息都不会丢。
上述确认回复过程其实在 TCP/IP 协议里已经做到了，因为每次发送都使用 flush 方式，如果不报错，就已经代表成功发出了。


这时 oracle 进程才能继续向下执行。否则，oracle PL/SQL 将按间隔不断重试，直到最终成功为止。
缺点在于需要 在 oracle 侧启动一个或者多个 oracle broker 进程。
当然可以使用 NodeJS 来启动 oracle 后台 job。
如果 worker proxy 长时间不能正常工作。

要知道 oracle 启动后，就可以通过 scheduler 调用操作系统命令启动本机上的 ext-hub。

emit 改成使用 any output API 输出，但是最终要输出到 ext-hub 中去。

..............


### 防止 DCO 丢失请求和回复 PDU，支持 rolling restart and rolling update

worker proxy 关闭前，一定通知 ext-hub 不要发送新的请求，ext-hub 将新请求缓存到队列等到 worker proxy 可用时再发出。
在 ext-hub 中有排队请求时，不能退出，必须等到所有等待队列都清空后，而且所有回复都接受到后才能退出。
ext-hub 在等待退出期间，可以关闭 oracle 连接并且停止接受 oracle 连接，防止更多的请求发来。
oracle 侧则会将请求发往备份的 ext-hub。
如果全部 ext-hub 都处于等待停止或停止状态，则 oracle 做 DCO 操作时会报错。

Noradle DCO 体系可以确保可以人工的 graceful 停止各个 worker proxy 和 ext-hub，而不丢失任何请求响应 PDU.

* 如果 ext-hub 刚刚接受到了来自 oracle 的请求 PDU，但是还没有发送给 worker proxy 就接受到中断信号，那么也必须先将该 PDU 处理完才行。

### 多个 ext-hub 的配置与运维管理

For between oracle and ext-hub
* 如何配置多个 ext-hub
* ext-hub 如何设计成支持 cluster
* oracle 如何选择可用的 ext-hub

每个进程都可以尝试任意一个状态为可用的 ext-hub 作为向外输出的通道。
当关闭某一个 ext-hub 时（比如说主机调整或 ext-hub 本身升级等原因），先要通过 k_dco_adm 安全退出 ext-hub，
可选参数包括可以同时标记该 ext-hub 不再使用。
所有实际使用该 ext-hub 的连接就要先断开再重连后才能发送新信息，其他使用其他 ext-hub 的进程不受影响。

过于复杂，配置也比较麻烦。因为一个 ext-hub 出现问题，往往其他的 ext-hub 接管后一段时间后也会出现同样的问题。
只有当是 ext-hub 运行的主机出现问题等环境问题，用另外一台机器上的 ext-hub 接管对外服务才有意义。
而如果配置


### 安全关闭 ext-hub

  ext-hub 退出后，oracle tcp connection 不能立即知道，并且还可以写大概两回 no buffered write，并且不报错，但是 ext-hub 根本就没有接受到。这时，一些 dco.send 看似成功，其实根本就没有发送出去。

  解决办法如下。ext-hub 退出前通过 server.close 防止建立新的连接，同时通过 alert 阻止全部新的请求被 flush 出来(在此时向buffer读取全部在途的回复，然后主动关闭连接并且每间隔几秒后尝试看看 ext-hub 是否重启)。当 ext-hub 发现全部在途回复都完成后，直接安全(没有新请求,已接受的请求全部都回复完毕)的退出。


可以考虑使用 ext-hub-pmon 来监控 pmon，ext-hub 会主动向监控进程发送心跳信息，一旦心跳停止，监控进程认为 ext-hub 意外退出，马上发出 quit alert 。
如果 ext-hub 主动退出，奖项监控进程发送将要退出的消息，监控进程直接发送 quit alert.

但是这个设计会浪费一个 oracle 后台进程专门用于监听 ext-hub 的状态，不是特别的好。
考虑和 psp.web pmon 合用一个后台进程。
psp.web pmon 不再间隔一段时间去看进程情况，而是等待 ext-hub 的网络事件，如果 3s 钟收不到 ext-hub 的心跳信息，就主动发送请求看看报不报错。
如果报错就证明 ext-hub 不在了，这时可以发出 quit alert.

速率控制
--------------






DCO 同步回复
-----------------

### 确保请求回复一一正确对应

为了能够接受到返回，需要
1. 每个到 worker proxy 的 PDU 都要附带 oracle sid,serial 用于跟踪一个 oracle 会话，帮助找到对应的 oraSock 来返回响应给 oracle
2. 每个请求，在一个 oracle session 范围内，都需要分配唯一的一个请求号到 oracle 发给  ext-hub 的 PDU 中，和 sid,serial 一起确保全部的请求号都全局唯一。

如果无需回复，那么就不用在 PDU 中写会话内请求序列号。

为了支持并发DCO，同步回复内容必须先接受到对应的 blob 中，然后在分析其中的内容。
这也是为了保障 socket 字节流不错位，是 multiplex 可靠。

### PDU 格式
1. PDU length ( 4 bytes int ) negative for error message
2. Bit Setting ( 1 byte UInt) 包括是否需要同步，可以把错误标志放到这里
3. Session-Scoped unique request seq ( 4 bytes int)
如果无需同步就不用传

DCO 异步状态更新
------------------

它本质上讲就是是单向到 oracle 的请求，对 oracle reverse 连接池的适用比较特殊。
可以 pipeline 向 oracle 发送请求。


扩展 DCO 思路
=========================

扩展一：支持对外连接的
-------------

直接设计 API，支持全部 TCP/UDP 原语即可。
con := dco.connect(host,port)
con.write(raw)
dco.read(raw)dco.disconnect(con);

发送的每个 PDU 中都带有一个 con id，而不再带有  reqid

对于 dco.send(proxy_id=>0) 的情况
ext-hub 认为是特殊的 PDU,
包括新建一个 proxy，PDU 中包含 ip,port 信息，包括关闭一个动态连接。

然后发送连接中的数据包时，直接使用 len(4bytes) + conn(4bytes) + 内容，而 ext-hub 看见这样的请求直接将内容部分发往

..................

【使用范例】
conn := dco.open_tcp
if dco.read_response(conn) then
  pdu.readXXX = 1 success.
end if;dco.send_request(conn)
...
dco.close_tcp(conn)


API form
------
TCP.connect_sync blocking but allow other DCO reply to read into PV buffer
TCP.send(conn,content)
TCP.receive(conn)

TCP.close(conn)
TCP.closed(conn) -- check if peer is closed (send close and will not send any more data)

OO form
----
tcp := new TCP(host,port)
tcp.send(content)
tcp.receive(content)
tcp.closed()

当 ext-hub 接受到 open_tcp 包(proxy_id=0)时，就会代理连接到指定的服务器，并且为之动态分配一个 proxy_id(>256)并返回给 oracle.
oracle 在接受到 ext-hub 连接到目的服务器的通知后


【用途】
比如用作 telnet.
可以基于这个封装各种协议的客户端库，包括类库。如 email pop3 client, ftp client, http client.
这些库和类库根本就不依赖 worker proxy 就可以独立使用。

但是实际上单独用 pl/sql 来解析 tcp stream 是非常的不方便的，比如说解析 http 响应，光是查找响应头结束标志就比较麻烦了。
而其实我们值关系回复体本身。最终使用 worker proxy 是更为方便的。

比如说设计 http client 支持
client = new http.request(url)
http.set_header(...)
http.set_cookie(...)
http.write_body
http.send()
...
http.get_reply(header is after body)
http.res_header
http.res_cookie(name)
http.res_body

UDP 可以用于向系统监控界面程序发送数据库性能信息。

【和 Noradle 的原则相冲突】
Noradle 需要 NodeJS 和 Oracle 取长补短的结合，要求网络能力部分通过 NodeJS worker proxy 来完成，数据处理部分通过 Oracle 来完成。
如果要求 DCO 支持直接的到外部服务的 TCP 连接，那么就必然要求 Oracle 侧实现相关应用层协议客户端部分的功能，这个显然不是 PL/SQL 所擅长的。
因此应该通过 worker proxy 来帮助 PL/SQL 来完成最终的目标，使得 PL/SQL 部分只需要发出最简化的请求并且接受嘴简化的响应即可。
如果一定要使用保持状态的一连串的对外请求，那么完全可以在请求体内增加一个状态标识字段，就像 http cookie 一样，并以此来标识一个系列的请求。
一般来讲系列请求的第一个 PDU 来申请状态号，该号由 worder proxy 负责分配唯一数字并且可能绑定到一个对外的 tcp 连接上或对外的 http cookie 上。
然后后面的请求都要将这个状态号携带。一般一个 16bit 或 32bit 的无符号整数就可以了。

...............

然是如果遇到了 oracle 要访问外部的一个有状态服务器，比如说根据不同登录会话的身份继续发出相同的请求，但是响应结果不相同。
这就需要 oracle 发往外部的 PDU 要包含一个流标识，该标识只需要在进程内唯一即可，
这样 router proxy 和专业 proxy 就知道 dbid+pid+streamid 相同值时，是一个有状态的流，这时该专业 proxy 可能会为该流单独建立一个到目标外部服务器的连接。
这个会话标识可以就是 tcp handle id，或者是 cookie 等等。
为了代表是同一个会话发送的请求，需要在每个 DCO 请求中都带有会话标识。

对于访问连续的 tcp 服务来说，会话和 socket 连接一对一。
todoconnect(host,port,dblevel) 然后返回一个连接句柄(其实是 NodeJS 实际对外连接用的端口号或对外 socket 号)，然后 oracle 可以 write_xxx 向该连接 中写入内容，然后调用 send(连接句柄) 将缓冲发出，这时 ext-hub 将其发送到相应的目标服务上。这时，表面上看 oracle 同时连接了多个外部服务，但是其实只连接了一个 ext-hub 服务。从而实现了 ext-hub 到外部 TCP 连接的代理，当然也可以实现 named pipe, udp, ssl 等各种协议的无 worker proxy 输出。

扩展二：可以获取外部流数据源
-------------------------

目前的设计主要都是为了向外部发送信息，而不是获取信息。
对于需要从外部获取信息到 oracle 的情况，需要和现有 DCO 不同的设计。
必须创建新的连接到 worker-proxy，然后使用该连接发出请求，
而回复是一个流，全部读完回复数据后，关闭该连接。
这样可以使得 oracle plsql 可以访问外部数据，然后结合自己的内部数据，做相应的处理。

扩展三：cross db pipe
--------------------

【应用场景】
原先部署在一个数据库中的多个应用之间通过 pipe 通信的化，现在部署到多个库中也不会有太大问题。

使用 pipe-hub 监听各个库的各个 pipe,
每个 oracle 的 n 个要向外发送的 pipe ，那么就要其 n 个连接到 pipe-hub.
pipe-hub 根据配置文件，对每个 db 的每个 pipe 执行标准的 read_pipe 存储过程，参数为 pipe name.
这样，oracle pipe 消息就会被 NodeJS pipe-hub 都读出来。
然后根据配置，将某个 db 的 pipe 消息在重新发往另外一个 db，默认目标 db pipe name 和 source db pipe name 一样，但是也可以不一样。
向一个 db 转发 PIPE 只需要一个到该库的连接。
连接总数为：一个 db 需要一个向其写的 Noradle 连接，和每个读 pipe 一个读 Noradle 连接。
这样，数据库就可以简单的使用数据库已有的 dbms_pipe API 来实现跨数据库的消息通讯。

DCO 问题
=========================

基本原则：访问 DCO 如果遇到问题，不能挂死 PL/SQL 线程，而要报错让 PL/SQL 处理错误然后继续执行。
否则，如果是后台 job 执行 DCO 然后被挂死，就会造成相关资源一直得不到释放，从而连锁锁死整个服务器。

所以必须有超时机制，
1、发出请求，等待回复的超时时间
2、发出请求本身的超时时间
`
1. 连接 ext-hub 不上，一轮失败，等待ns钟重试第二轮，若还不能连上，则报错 ext-hub 不存在。
若超时设置成 0 (默认)，那么连不上 ext-hub 一轮不能通过就直接报错。
2. 连接 proxy_id 不存在，直接报错，没有超时问题存在。
对于单向的对外发送，oracle 侧不接受任何回复，包括报错信息。因此写错 proxy_id 就意味着消息的丢失。
对于非单向的对外发送，ext-hub 发现 proxy_id 不存在后，直接回复系统错误信息，PL/SQL API 执行报错即可。
错误信息包括不存在 xxx 号的 DCO 代理配置。
3. 连接 proxy 服务不可用。
策略一：直接像上面 proxy_id 不存在一样，报错给 PL/SQL
策略二：认为 proxy server 正在重启中，先将请求放入可靠队列，等 proxy 启动后，再试。
如果等待 proxy 超过一定时间，那么就放弃，并且报错。
对于需要回复的请求来说，等待 proxy 时间就是等回复设置的超时时间，
PL/SQL 不能区分是因为 proxy 没有处理完还是 ext-hub 连不到 proxy，
有可能压根就没有执行，也有可能执行了但是没执行完所以没有回复，无法区分。

目前原则：
1. 发送永远都应该“成功”，区分不出连不上 ext-hub，错误 proxy_id，没有 proxy server.
2. 接受回复只有通过超时无结果报错
3. 单向发送最多只能知道是否有 ext-hub 可连接，无法知道是否最终将请求发出；
ext-hub 可以通过配置多个，总是可以确保任何时候有一个可用，包括支持 rolling update。
对于单向发送 ext-hub 按照尽力而为的原则处理，但是不保障完全执行。
发送请求时若要确保得到一定程度的处理，就必须放弃单向发送，改为使用要求同步回复的请求。
要求同步回复的请求可以检测到以下

【ext hub 会一直不段的尝试连接 ext hub nodejs server】[ ]
造成一些进程锁死，并且有可能带来一系列级联锁，最终锁死整个服务器。
因此必须确保当 ext hub 不可用时，放弃尝试，并且报错。
或者确保 ext hub server 可用，并且从 oracle 访问可达。

【exthub 恢复的时候会延迟执行 DCO 请求】
因为请求都放到 ext-hub 的队列中了
对于短信服务来说，延迟的请求可能需要被取消才合适

【如果 exthub 发现一些外部服务不可用】
一定不能退出，而是向 oracle 报告错误。这和超时报错是一个道理。

【proxy ID is not exites】[ ]
先在日志中写 proxyID，方便做调查
/home/node/noradle/lib/ext_hub.js:98
    wpw.whenHaveFreeTraceBackID(oraReq.readInt32BE(0) > 0, function(rpcSeq){
        ^
TypeError: Cannot call method 'whenHaveFreeTraceBackID' of undefined
    at ByLeadingSize.onOracleRequest (/home/node/noradle/lib/ext_hub.js:98:9)
    at ByLeadingSize.EventEmitter.emit (events.js:88:17)
    at Socket.handler (/home/node/noradle/lib/StreamSpliter.js:60:12)
    at Socket.EventEmitter.emit (events.js:115:20)
    at TCP.onread (net.js:395:14)





**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>