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

但是，我们是否必须要基于 oracle client driver 主动连库呢？分析如下，OCI 提供的功能过度过于复杂，而我们只需要执行 Oracle 上的存储过程，然后接受响应结果，而无需执行更多复杂的工作如 SQL。也就是说你要在数据库中执行的全部操作都应该封装到存储过程中，你所需要的所有回复都应该由该存储过程输出成一个响应(格式可以是多样的)，因此 Noradle 对数据库操作就简化为执行存储过程(当然包括传入入参和请求体等信息)，然后取得结果响应。结论是我们无需使用复杂的 oracle client driver 及其封装。

  但是不使用基于 oracle client driver 的封装方式怎么才能连接到数据库中呢，恰好 Oracle 提供了 UTL_TCP 包，它提供了连接外部服务器，读取和写入 socket 的功能。因此 Noradle 会在数据库中预先启动一定数量的后台进程(基于scheduler)，然后让这些 oracle 服务进程执行主服务程序 gateway.listen，gateway.listen 会首先建立到 NodeJS 服务器的连接，然后等待 NodeJS 发送 socket 信息给自己。在 NodeJS 端被动的接受来自 Oracle 的连接并形成数据库连接池。当 NodeJS 需要执行 oracle 存储过程(PSP.WEB 页面生成程序)时，就从连接池中取出空闲的连接，然后将包括存储过程名、用户 http 请求信息等信息通过该空闲的 socket 发往对应的 oracle 后台服务进程，该进程会将所有请求信息解析并存放到包变量中供要执行的存储过程访问，然后动态执行该存储过程。而存储过程也会读写库表数据然后按照输出 http 响应的方式将结果返回给 NodeJS.

  反向连接(reverse db connect)比传统的正向连接的众多优势，清点如下：

1. 无需安装基于OCI的 oracle 客户端，无需对 OCI 封装，无需用 javascript 重写 JDBC Think Driver
2. 应用程序无需做连库的配置和代码书写，只需在 oracle 侧配置哪些 NodeJS server 需要被动连库即可
3. oracle 服务器端主动发起连接，而不是由客户端随意连接数据库，这样只有注册的连库客户端才能访问到数据库，无需暴露数据库用户名和密码，这不是更加的安全吗
4. 因为是由 oracle 主动向外发起连接的，防火墙无需配置哪些节点(除了数据库开发和管理人员)可以访问数据库，既简单又安全
5. 通过一组连接和对应的后台oracle进程，可以选择任意连接和进程执行任意用户的存储过程（只限后缀 _b,_c,_h 等对外服务的存储过程）
6. oracle 服务器通过标识客户端的可用状态，可以随时动态的拒绝某类客户端的访问
7. Noradle 服务进程可以在执行了一定量的请求次数和时间后，自动退出，并通过 k_pmon 重启（当然也可以是退出的时候自动将自己重启），从而实现资源的释放而如果采用传统的客户端建立连接池，那么 oracle 服务进程的重启释放资源的操作就不是集中管控的，依赖于每个客户端为了照顾数据库整体而管理好连接池。现在应用程序再也不用管理连接池了，来自各个NodeJS服务器的所有到数据库的连接都会由 Oracle 主动集中管理，它会根据数据库自身的负载来管理，而不是根据客户端的意愿，这难道不是更加合理吗？
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


**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>