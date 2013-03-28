<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title"> 数据库连接的管理机制  </div>



反向连接机制
===

  Oracle 主动向指定的 NodeJS Gateway Server 发起连接，NodeJS Gateway 将连接放到连接池中管理。这区别于数据库客户端主动向数据库发起连接。这个较做 reverse connection，即反向连接机制。

  传统的数据库连接方式都是客户端主动连接数据库，然后管理一个数据库的连接池，但是 NodeJS 没有办法主动连接数据库，因为：

1. 如果使用基于OCI的 javascript 封装，需要开发这个 driver，实际部署还需要在 NodeJS 所在服务器上安装 Oracle 客户端环境
2. 如果使用基于JDBC Thin Driver 协议开发 javascript 版本，也会非常的困难

但是，我们是否必须要基于 oracle client driver 主动连库呢？分析如下，OCI 提供的功能过度过于复杂，而我们只需要执行 Oracle 上的存储过程，然后接受响应结果，而无需执行更多复杂的工作如 SQL。也就是说你要在数据库中执行的全部操作都应该封装到存储过程中，你所需要的所有回复都应该由该存储过程输出成一个响应(格式可以是多样的)，因此 Noradle 对数据库操作就简化为执行存储过程(当然包括传入入参和请求体等信息)，然后取得结果响应。结论是我们无需使用复杂的 oracle client driver 及其封装。我们把 oracle 反向连接到的 nodejs server 叫做连库的 gateway，最终客户端都是通过这些 gateway nodejs 连接到 oracle 中的。

  但是不使用基于 oracle client driver 的封装方式怎么才能连接到数据库中呢，恰好 Oracle 提供了 UTL_TCP 包，它提供了连接外部服务器，读取和写入 socket 的功能。因此 Noradle 会在数据库中预先启动一定数量的后台进程(基于scheduler)，然后让这些 oracle 服务进程执行主服务程序 gateway.listen，gateway.listen 会首先建立到 NodeJS 服务器的连接，然后等待 NodeJS 发送 socket 信息给自己。在 NodeJS 端被动的接受来自 Oracle 的连接并形成数据库连接池。当 NodeJS 需要执行 oracle 存储过程(PSP.WEB 页面生成程序)时，就从连接池中取出空闲的连接，然后将包括存储过程名、用户 http 请求信息等信息通过该空闲的 socket 发往对应的 oracle 后台服务进程，该进程会将所有请求信息解析并存放到包变量中供要执行的存储过程访问，然后动态执行该存储过程。而存储过程也会读写库表数据然后按照输出 http 响应的方式将结果返回给 NodeJS.

  反向连接(reverse db connect)比传统的正向连接的众多优势，清点如下：

1. 无需安装基于OCI的 oracle 客户端，无需对 OCI 封装，无需用 javascript 重写 JDBC Think Driver
2. 应用程序无需做连库的配置和代码书写，只需在 oracle 侧配置哪些 NodeJS server 需要被动连库即可
3. oracle 服务器端主动发起连接，而不是由客户端随意连接数据库，这样只有注册的连库客户端才能访问到数据库，无需暴露数据库用户名和密码，这不是更加的安全吗
4. 因为是由 oracle 主动向外发起连接的，防火墙无需配置哪些节点(除了数据库开发和管理人员)可以访问数据库，既简单又安全
5. 通过一组连接和对应的后台oracle进程，可以选择任意连接和进程执行任意用户的存储过程（只限后缀 _b,_c,_h 等对外服务的存储过程）
6. oracle 服务器通过标识客户端(gateway)的可用状态，可以随时动态的拒绝某类客户端的访问
7. Noradle 服务进程可以在执行了一定量的请求次数和时间后，自动退出，并通过 k_pmon 重启（当然也可以是退出的时候自动将自己重启），从而实现资源的释放。而如果采用传统的客户端建立连接池，那么 oracle 服务进程的重启释放资源的操作就不是集中管控的，依赖于每个客户端。为了照顾数据库整体而管理好连接池，现在应用程序再也不用管理连接池了，来自各个NodeJS服务器的所有到数据库的连接都会由 Oracle 在服务端主动集中管理，它会根据数据库自身的负载来管理，而不是根据客户端的意愿，这难道不是更加合理吗？
8. 现在已经基本不存在 CS 客户端程序(他们的地址任意不固定)直连数据库的应用了（除了开发人员和数据库管理员），需要连接数据库的都是些在后台运行的有着固定地址的应用服务器等服务器，因此事先将他们注册到 Noradle 并且由 oracle 主动连接他们是非常可行的
9. NodeJS 对连接池的管理方式如下，一旦有访问 oracle 的请求而没有可用的 oracle 连接，他会将请求打入队列然后不阻塞继续执行其他工作，一旦有新的可用的空闲 oracle 连接，Noradle 会按 PIFO 原则取出一个待执行请求，用新出现的空闲 oracle 连接将该请求发送给 oracle 侧执行。因此即使连接池忙或者 oracle 暂时中断，或者重启了 Noradle 后台进程，都不会影响最终用户的访问，最多只是响应延时变长。对于编程的好处是，执行访问 oracle 的动作时，永远可以认为存在可用的空闲 oracle 链接，即使它们可能是 deferred.
10. 反向连接使每个 Noradle 服务进程都可以建立一个到 NodeJS proxy router 的连接，从而通过 multiplex 多路复用实现不限量的对外连接数。


NodeJS 数据库连接池管理机制
===

连接池静态结构
-----

### freeList
  为了找出空闲的 oraSock，一种方法是每次扫描整个 oraSock 数组来查看 oraSock 的状态是否是占用，该方法效率低，特别是在连接数较大时。为此 Noradle 设定了 freeList 队列(js array)，每当有新的连接接入时，将新连接加入到 freeList 的尾部，同时，每当有用完 oraSock 时，还要将其归还到 freeList 中。

### busyList
  为了管理好执行超时的请求，Noradle 设置 busyList 队列，当遇到新请求时，将 freeList 中的空闲 oraSock 取出并放到 busyList 中，然后执行该请求的处理逻辑。Noradle 在向 busyList 加入 oraSock 时，同时记录了加入时间，该时间用于判断该请求是否执行时间过长从而造成超时。

### waitQueue
  当请求到达时如果没有空间的 oraSock，那么将要将该请求的处理放到 FIFO 队列 waitQueue 中，当有新的空闲 oraSock 出现时(可能是新的连接或执行完请求后释放的连接)，从队 waitQueue 中取出最早的等待处理过程执行。等待 oraSock 才能执行的处理过程在打入 waitQueue 时也会记录当时的时间，当该处理程序等待空闲连接的时间太长时，Noradle 也会进行超时处理，直接以 null oraSock 调用处理回调，并由处理回调返回错误信息。

连接池动态管理
-----

1. 当有 oracle 新连接到 NodeJS 时，将该 oraSock 放到 freeList 的尾部
2. 当有新的请求时，从 freeList 的头部取出一个空闲的 oraSock，并作为参数调用处理回调程序，同时将该 oraSock 放到 busyList 中
3. 上述环节如果 freeList 为空，就会将该回调处理程序打到 FIFA 队列 waitQueue 的尾部，并且记录打入时间点
4. 当请求处理完毕后，将自己占有的 oraSock 从 busyList 中删除，并且放到 freeList 的头部
5. 每当 freeList 有新空闲 oraSock 加入后，都要同时看 waitList 中去看如果有等待回调就加该空闲 oraSock 用于该回调的执行，过程同第2步
6. 再从 waitList 中找出等待请求后，先会检查该请求是否已经被浏览器或客户端取消(对应的连接不可写)，若是则丢弃并看下一条等待记录。


  按照上面的过程，所有的请求都可以得到空闲的 oraSock 用于和数据库交互并且在完成后都可以释放该 oraSock 用于后续的请求。该机制有两个特点：


1. 即使请求到达时没有可用的空闲 oraSock 用于访问 oracle db，该请求不会出现异常，而是等待新的空闲 oraSock 出现后延迟执行而已。
2. 总是经常使用的那些 oraSock 被不断的重复使用，对应的在 oracle 端后台服务进程发生进程切换的可能行非常低，oracle服务器的运行效率非常高。


自动回收连接池资源的机制
-----

### 等待 free oraSock 超时

  如果等待 free oraSock 的处理回调等待时间太长，系统会在定时检测过程(默认3s一查)中认定为等待超时，直接使用空 oraSock 调用回调，要求其做错误处理。对于 psp.web 页面，Noradle 会返回 500 错误页面，并且在内容中说明是系统的并发访问量大，没有可以用的数据库连接执行请求处理。
  但是，如果等待处理的请求太多，等待时间太长，用户就经常会重新提交重复的请求，因此造成对系统的更大的压力，从而造成恶性循环，为了解决该问题。Noracle 设计了以下机制。
  这时系统超时记录计数器加一。
  另外，当长度超过指定数量，一般为 oraSock 的 n 倍，比如说2倍，则干脆连等待队列都不进，而是直接报错。
  上述举措有两个好处，一是最终用户可以立刻得到500错误而不是等很长时间才能看到反馈，二是 Noradle 系统也不用无谓的耗费过多的资源来保持很长的等待队列。

### 使用 busy oraSock 的处理程序执行超长

需要报告 500 错误，并且强制执行杀死该进程。
杀死该进程的任务应该由 oracle 管理员进行，NodeJS 可以将杀死该进程的语句输出到日志供 DBA 直接拷贝执行。
一些任务就是执行时间长，比如说使用 chunked 方式传输的页面，统计报表页面，事件流产生器等等，
这时必须防止误判。
为了能够让 Noradle 监控 oraSock 的执行时间，就需要登记该 oraSock.once(data) 当有数据响应时，认为是正常的就是需要长时间执行，取消计时。
当长时间没有反馈时，可以肯定就是需要告警的情况。
对于告警的 oraSock 的执行，需要将被执行过程登记。
因此所有的 busy orasock 也要记录，系统定时查看其是否长时间没有响应，然后进行统计记录。
最终可以查看哪些过程执行时间过长，其平均执行时长，最大时长和方差，粒度为 3s。
系统应该提供监控界面，可以实时查看到最新的慢过程清单（包含所有数据库的程序）
NodeJS 退出前，还应该将该清单写入日志文件，该日志文件登记了从系统启动开始到结束时的日志情况。


对保持占有 oraSock 为后续请求服务的需求
-------

  在普通请求后，可能会紧跟着 linked css 或者是 feedback page，这些成为“伴随请求”，伴随请求如果因为浏览器缓存或者是网络原因没有将请求发送到服务器上，服务器则通过超时来释放 oraSock 资源供其他请求使用。伴随请求的响应不做 cache 处理，oracle 侧的服务进程如果发现上一个请求有伴随请求，需要等待该伴随请求一段时间才允许退出。

### feedback 机制


### linked component css

### 对需要使用 PV 保持中间状态的应用的需求 (maybe todo)

  比如说有程序自动连接提交的一组请求，他们之间需要保持上一步结果状态供下一步用，这时可以利用 PL/SQL package variable 来保持状态。在一组请求的开始申请 free oraSock，然后在该组请求的最后会还该 oraSock。

  对于非自动连续提交的一组请求，而是有人工一个一个间隔一小段时间提交的请求来说，长时间占用一个 oraSock 并且大部分时间都不实际执行请求会造成 oraSock 和数据库服务器进程资源的浪费。

  但是上述情况考虑到不使用该 PV 的普通 servlet，不使用PV或使用不同的PV，因此不存在不冲突。因此也可以在 free oraSock 紧张的情况下临时复用该 oraSock，执行完后，依然归持有其的请求组。该机制最多会造成请求组中的一些请求的执行出现延迟而已。在换取其他请求更快的得到执行的情况下，还是值得的。

  但是如果使用特定 PV 保持状态的并发用户会话太多的化，因为互相之间的冲突，无论如何也会造成大的并发需求。因此还是不可行的。因此他只适合并发较小的连续请求组，如果并发可能大了，或者状态要在更长的范围包括整个用户会话保持，那么就不能使用本方案。未来将会通过另外一个连接向 Oracle 发送中断指定会话中指定请求号的请求的信息。


抗压力和 DOS 攻击机制
======

防范用户不停的刷新
----------

   用户已经提交的请求如果在后台执行时间长(比如说由于后台处理资源紧张，请求一直在排队)，就会在浏览器表现为页面停滞，这时用户往往会重新点击连接到该页的链接或者按F5重新刷新该页。这个其实是非常常见的，若不服务器不做特殊设计，就会造成无谓承载大量无效(已被客户端取消)请求的负担。因为服务器负载高造成页面停止并引发用户重复歘新，那么就会进入恶性循环，不断恶化直到服务器彻底锁死。发生这种情况是，浏览器会对承载原先请求的连接做中断和结束处理，在 NodeJS 服务端会识别到，表现为一个已接受请求对应的TCP连接已经是不可写，这时 Noradle 的 db pool mamanger 就会取消该请求。方式有两种：

 1. 当由于连接池资源紧张，请求一直在排队等待，当有空闲连接时 Noradle 回去等待队列找出最前面的等待请求，然后在这个关键点检查该请求对应的浏览器TCP是否已经不可写，若不可写则代表浏览器已经取消了该请求，这时直接丢弃该请求，看队列中的下一个。
 2. 当请求已经放到 busyList 中，也就是已经在 Oracle 侧执行了，暂时没有实现追回机制，只能等待该请求执行完。

防范来自程序的恶意 DOS 攻击
----------

  Status: Todo

  当程序大量连接并且大量发送请求时，Noradle 靠 MSID 识别相同的浏览器。如果请求中都没有 MSID，那么 Noradle 会生成一个刷新自己的请求，但是返回响应头中会设置 MSID. 如果攻击者不使用该 BSID 提交新的请求，那么 Noradle 就会不停的重复要求访问者用新的 MSID cookie 刷新请求。如果来自同一个IP的客户端发送无 MSID cookie 请求的密度过大，那么就认定他为恶意程序，以后一段时间内直接拒绝来自该 IP 的连接。因为正常情况下，即使是代理访问 Noradle 服务，其无 MSID 且无 BSID 的情况也是非常的少间的。



in-hub （todo）
======

  全部 oracle 后台进程供全部需要访问 oracle 的 NodeJS 服务共享，在数据库中只配置一个反向连接地址，该地址就是 in-hub NodeJS server 的接受 oracle 连接的地址。然后 in-hub 像原先 oracle 反向连接各个 NodeJS server 一样连接他们。各个 NodeJS server 的连接池就好像直接持有 oracle 连接一样。系统允许 in-hub 分配给各个 NodeJS server 的连接数的总和数量大于实际在后台启动的 oracle 服务器进程数。这样每个访问 oracle 的 NodeJS server 最大可能得到并发服务器进程数都会在其他数据库访问量少的时候得到增大，从而达到共享 oracle 进程资源的目的，防止了一组 oracle 服务进程被单个 NodeJS server 锁定，即使是空闲也不能被其他 NodeJS server 利用的弊病。

  In-Hub 增加一个网络处理环节，可能会造成微小的处理延迟，性能损失。但是 psp.web NodeJS server 若和 In-Hub 在同一台服务器上，可以使用 unix pipe 进行通信，效率其实也是非常的高的。

  当一个 client NodeJS 需要访问数据库时，只要访问 in-hub server 即可。Client NodeJS 可以建立多个到 in-hub server 的连接。当一个 Client2InHub 连接在用时，该连接绑定(一一对应)到一个 oraSock 上。

Oracle DB 后台进程的管理
======

oracle 后台服务进程的资源释放机制
-----
会活跃的哪些后台进程在执行一定数量的请求或存在一定的时间后，会 graceful 退出，用以释放资源。

访问控制
------

### 控制 NodeJS server 能访问哪些数据库用户

  在 server\_control\_t 配置表中配置可访问用户清单，使用正则表达式，用户名小写。

### 控制只能访问 xxx_x 命名的对外程序

  只有形如 xxx\_x 的 \_b,\_c,\_h 程序被认为是可以从 NodeJS 调用的对外服务程序，其他命名的程序单元都被仅指从 NodeJS 直接调用。

  在 server\_control\_t.dbu\_filter 中按照正则表达式设置允许访问的数据库用户，用户名都按小写配置。如果为 null，代表不进行数据库用户访问控制。

### 进一步的控制

  由各个用户自己的 k_filter.before 来进行自定义的权限控制，防止未经允许的程序被执行。


系统监控
=======

  可以通过 /server-status 访问到系统当前状态，包括以下信息：

1. 系统运行开始时间，运行多长时间
2. 系统的各个端口号(数据库监听，http/https 监听)
3. 系统总共处理的多少个请求
4. oraSock 的连接池连接数量，空闲数量，在用数量
5. 所有当前正在处理中的开始时间，url/dbunit, 对应的 oracle sid, serial
6. 系统最大峰值连接数和等待数 (high watermark) (todo)
7. 平均响应时长(从接到请求到返回 header 和到返回全部)，最大响应时长和平均方差 (todo)


  还包括以下非关键信息

1. I/O 吞吐量 (todo)

todos
======

### 调查 oraSock 是否需要应用 keep-alive 保持连接

c.setKeepAlive(true, 1000 * 60); // todo: if it's required? [ ]




### 支持 oracle resource manager 机制

  对于每个访问 oracle 的 NodeJS server，都会在请求处理开始设定 oracle resource 分组标识为该 NodeJS server 标识，从而允许系统按照 NodeJS server 的不同分配不同的资源使用策略。


### monitor support snapshot and delta display

  You can take system stats snapshot manually or repeat automatically, and you can require any delta show between them and the current state. Noradle will provide graphic system activity/statistics display.

in-hub
============

如果 oracle 作为 versatile server 的化，就需要 oracle 主动启动一定数量的服务进程去反向连接到各个 nodejs gateway server 中去，
这时，就会出现几个问题。
1. 需要在 oracle 侧为每个需要反向连接的 protocol gateway 配置连接端点、进程重启设置等数据
2. 不同的 oracle process 只能同时监听一个 nodejs gateway server，因此进程不能跨不同的 protocol 复用
因此，考虑设计 in-hub，达到一下目的
1. oracle 只需配置到 in-hub 的连接，而无需知道其他具体 gateway 的服务地址，从而大大简化了数据库配置
2. 各个 gateway nodejs server 只需连接到 gateway server，将请求转换为 oracle 内对应的 server 主过程处理即可
in-hub 没有业务逻辑，只负责作为 tunnel 来将 gateway 的请求发往目的数据库

具体设计：
如 http 请求先到 gateway，然后 gateway 将请求进行协议预处理，
然后将 oracle 能理解的请求数据通过其中一个到 in-hub 的连接(unix pipe 或 tcp socket) 发往 gateway，
in-hub 接受到 gateway 的请求后，找到一个 free reverse connection，然后将来自 gateway 的请求数据直接 pipe 到其中，
如果当时没有 free connection to oracle，则将请求数据缓存到队列，直到有 free connection to oracle 出现再将缓存数据发出。
oracle 接到来自 in-hub 转发的 gateway 请求数据流后，将根据请求头动态调用主过程，
如有负责 http 的，有负责 DBCall，有负责 SQL 的，有负责 mongoose 协议的，什么都有，也可以自定义。
主过程直接过程中会输出结果，
因为 in-hub 为已经建立了 gateway socket 和 oracle socket 之间的对应关系，
因此输出结果直接对应到 gateway socket 并且传回。
gateway 会决定这条通道是否用完，用完后 gateway 会通知 in-hub.
对于 css,feedback 等操作都有这个需要，
如果让 gateway 来决定一个请求应答是否结束，那么就需要 gateway 发包通过 in-hub 用完 oracle 连接，
这样做效率显然是不高的，因此应该要求 oracle 一次性的将回复都返回，包括 css,feedback。并且标识回复已经结束。
这样，in-hub 就可以直接识别回复已结束并释放该 oracle 连接给其他服务使用了。
对于单向访问，这些访问无需回复，那么 gateway 发出请求时，就要标识该请求无需回复。
这样 in-hub 将请求发送完后就可以释放 oracle connection 给其他请求使用。

这里有一个危险情况，包括
1. gateway 指示是单向请求无需回复，但是 oracle 还是向 in-hub 输出结果了
2. oracle 向 in-hub 输出结果并且包含结束标记，但是之后又向 in-hub 写数据了
因此当 in-hub 发现一个 free oracle connection 接受到数据时，应该做出识别和响应处理。
in-hub 应该丢弃这些 free oracle connection 发来的数据，并且记录日志。
日志为 logger.db(info)，具体可以静态或动态配置如何输出。
开发人员看到这些日志后，应该修正问题。
同时，系统必须使用标准的 output.end API 来标识全部回复已完成，
这时，如果会话中再次调用 output 并且实际写 in-hub，就会报错。
有了上述在 in-hub 侧和 oracle 侧两侧的异常识别处理机制，
oracle socket 通道就不会出现请求回复错乱窜位的情况。

和 ext-hub 一样，in-hub 也可以有多个，防止单点障碍，并可以尽量快的切换到其他可用的节点。

有个 in-hub tunnel 的作用，各个以 oracle 为后端的 protocol gateway server，
都可以非常简单的建立多个连接到 in-hub，然后向其发出请求包，再等待该连接上的回复就好了。

gateway 发往 in-hub 的请求回复数据最好参考 websocket 和 socket.io 协议，支持 fragmentation。
比如 http 协议，原先是在 oracle 侧读到最后一个参数后，就知道请求结束了。
但是 in-hub 并不知道来自 gateway 的请求结束了，当然他也无需知道，因为 oracle 会告诉 in-hub 回复已结束。
而回复已结束就代表请求已结束。这时 in-hub 可以 mark free 这个到 oracle 的通道。
这么看，fragmentation 也就不需要了。

但是依然存在危险情况，包括：
1. in-hub 收到 busy orasock 的回复结束标志，但是 gateway 依然发送对应请求的后续部分。
因此，为了杜绝这种情况，要求标识 gwsock 为 free 标识，
当 in-hub 发现 orasock 的回复结束，就标识对应的 gwsock 为 free。
而如果 free gwsock 依然发送数据就需要识别出来，
要求每个 gwsock 的请求数据必须以固定的 magic number 开头，
如果不是该 magic number，就说明 gateway 的请求发送有误，
此时 in-hub 应该记录日志，并且告警。

可以看出，in-hub 担负着检测一下两类异常的责任
1. gateway 发完请求后还往 gwsock 中写数据的问题
2. oracle 写完回复后还网 orasock 中写数据的问题

pipe line request 的需求分析。


in-hub 总体评价
---------------

优势：
* 全部客户(而不是每个客户)共享 in-hub 维护的一组 oracle 连接，共享度更高，oracle 后台进程利用率更高，进程资源占用少，进程切换少。
* oracle 侧的连接管理 p_mon 得以简化，只需连接 in-hub 一个地址即可。无需为访问 oracle 的客户单独配置连接数据
* 客户端不必逆向监听oracle连接，而是主动连接 in-hub 即可。而且一般只需一个连接即可。
* 各个客户端的连接数，最大并发占用 oracle 服务进程的数，都可以在 in-hub 中加以控制
* 当并发请求增多时，还可以动态增加 oracle 后台服务进程。k_pmon 只需为数据库整个负载负责，只要数据库还能运转，依然可以分配更多的服务进程。

连接：in-hub 可以支持 gateway 的各种连接方式，包括 TCP,UDP,Named Pipe
* gateway 不仅可以通过 tcp 连接 in-hub/oracle, 还可以通过 unix domain socket 连接 in-hub/oracle，性能会更好。
* gateway 还可以通过 udp 连接 in-hub 如果每个请求就是一个 udp 包的话，对于比较简单的请求回复协议和单向协议，可以直接使用 udp 完成。
* oracle 可以变身为各个类型的 server，包括 UDP server，比如 DNS.


和 oracle MTS 架构比较
------------------------

in-hub 将扮演原先 oracle MTS 架构的 dispatcher 进程的角色，
而 noradle process 则扮演 shared server。
而 dispatcher 可以有多个进行负荷分担和故障切换，
in-hub 一个进程可持有的 gateway 进程数可能也有限，数量最大为 (gateway 数量) * (noradle 后台进程数量)，
一般不会太多，因此采用 in-hub 负荷分担来分担大的连接数其实是不必要的。
但是设置备份 in-hub 还是有必要，毕竟如果一个 in-hub 异常，如底层的设备出现异常，那么还可以有其他 in-hub 使用。
所有 oradle 客户端进程连接 in-hub，in-hub 选择最小号可用 slot 的 job process.

原先 oracle 的 listener 不需要，因为 gateways 直接连接 in-hub 即可。
当 in-hub 存在备份时，所有 gateway 如果连接不上主 in-hub 时，就连接备份 in-hub.


这时，使用 DBCall 的所有  NodeJS 程序都将主动向 in-hub 请求连接。
可以请求持久连接，一直占用一个 oracle process，就像 dedicated server 一样。
或者请求一个存储过程，执行完后就归还连接，使用 GAC 保存会话信息，就像 shared server 一样。


in-hub 部署位置
--------------

如果希望将 in-hub 部署到和 oracle 相同的服务器上(同一物理机，可能在不同的虚机中)，
这样可以使用 127.0.0.1 loopback 地址进行 tcp 通讯，
那么 oracle 到 in-hub 的连接将非常的稳定，
而 oracle utl_tcp 是有缺陷的，对于连接异常不是能及时检测出来，甚至发出术后后都不知道连接已经断了，
所以稳定的 tcp 连接对于 oracle utl_tcp 的应用来说非常重要。
因此 noradle 永远都推荐将 in-hub 部署到和 oracle 在同一服务器上，不再同一虚机也要在同一物理机。
如果 oracle 所在服务器不能安装 nodejs 环境，也要将 in-hub 部署到 oracle 跟前，
防止网络故障导致 oracle 侧 utl_tcp bug 引发问题。


in-hub 要不要支持多个 oracle database 的反向连接
---------------------------------------------

一个 in-hub 若负责多个数据库，必然造成 gateway 到 in-hub 协议的复杂化，
也不符合 in-hub 仅仅做简单的 tunnel 的原则，
因此每个 in-hub 负责一个数据库，
如果在一个服务器上运行多个数据库，并且要求在该服务器上运行 in-hub，
那么也要对每个数据库单独配置一个 in-hub 才行。


gateway 需不需要连接多个 in-hub
-----------------------------

一个 gateway 比如说做 http psp.web 服务，如果该服务器不同的 dad 需要映射不同的数据库的不同用户，
那么这个需求是完全成立的。
该服务需要自己根据http请求将请求数据发往对应的 in-hub 中才行。
但是一般来说，采用各个协议的反向代理协议也能实现相同的功能。
因此一般是不需要 gateway 连多个 in-hub 的。

情形一：比如企号通按省做成分布式，按照 gid.sheng.unidialbook.com 访问路由到不同省的 oracle db 中去。
那么各个 .sheng.unidialbook.com 就应该注册各自的服务器地址，
也就是数据库如何分布的，对应的域名往往也做相应的分布，最终还是一个域名下的gateway访问对应的一个database。
所以说连多个 in-hub 的需求太少了。

in-hub 和直接 reverse connection to gateway 的比较
------------------------------------------------

direct to gateway 减少了 in-hub 中间环节，运行效率可能会更高。
但是也有缺点：
1. 很难降低 utl_tcp 的缺陷造成的影响
2. 降低了 oracle 侧服务进程的利用率
因此 in-hub 依然重要。

***********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>