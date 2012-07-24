<link type="text/css" rel="stylesheet" href="doc.css" />
<span class="psp_logo">*PSP*.*WEB*<span>
****************************************

<div id="title"> 数据库连接的管理机制  </div>



反向连接机制
===

  Oracle 主动向指定的 NodeJS Gateway Server 发起连接，NodeJS Gateway 将连接放到连接池中管理。这区别于数据库客户端主动向数据库发起连接。


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


  按照上面的过程，所有的请求都可以得到空闲的 oraSock 用于和数据库交互并且在完成后都可以释放该 oraSock 用于后续的请求。该机制有两个特点：


1. 即使请求到达时没有可用的空闲 oraSock 用于访问 oracle db，该请求不会出现异常，而是等待新的空闲 oraSock 出现后延迟执行而已。
2. 总是经常使用的那些 oraSock 被不断的重复使用，对应的在 oracle 端后台服务进程发生进程切换的可能行非常低，oracle服务器的运行效率非常高。


超时自动回收连接池资源
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

  但是如果使用特定 PV 保持状态的并发用户会话太多的化，因为互相之间的冲突，无论如何也会造成大的并发需求。因此还是不可行的。因此他只适合并发较小的连续请求组，如果并发可能大了，或者状态要在更长的范围包括整个用户会话保持，那么就不能使用本方案。

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




**********************************************
<span class="psp_logo footer">*PSP*.*WEB*<span>