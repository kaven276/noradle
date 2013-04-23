<script src="header.js"></script>

<div id="title"> Noradle Any Server </div>

要将 oracle 可以作为各种协议的服务器

1. 直接将浏览器页面请求映射到 oracle 存储过程，返回页面
2. 将 ajax 请求映射到 oracle 存储过程，返回经过 json 化或相当于 json 化的结果集
3. 将 websocket 请求映射到 oracle 存储过程，返回经过 json 化或未 json 化的结果集
4. nodejs 自己请求 oracle plsql 结果集


1. http server
2. db source for nodejs, use compact data result sets format
3. use mongoose like API to access oracle from javascript
4. as a webdav server
5. as a ftp server
6. as a email pop3 server
7. as a email IMAP server
8. as a radius server
9. as a DNS server
...

过程简介
---------------------------------------------
nodejs 前端接受到特定协议的请求时，将对请求解析，
然后使用 oracle reversed connection 将请求数据发给 gateway.listen。
其中发送的第一项就是协议类型或者就是协议需要动态执行的主过程。
然后 gateway.listen 按照协议类型调用协议主解析过程，
协议解析过程将请求参数打入 package variable 缓存，
并且指定进程协议处理的存储过程，
该处理存储过程访问解析好的请求数据，结合库表数据，输出响应体返回 nodejs 结果。
node 将结果做处理最终返回协议客户端。

协议类型和协议主解析程序名称的关系，如 protocol_server.serv 为
http -> http_server.serv
pop3 -> pop3_server.serv
ftp -> ftp_server.serv
nodejs -> data_server.serv
总的处理程序为 anyserver.listen

各个协议服务端共享页面输出基础 API，其实就是 blob cache，也可以直接向 socket 输出。

从本质上讲，只要 nodejs 可以将请求数据结构传给 oracle gateway.listen 并且指定执行那个过程，
并且 nodejs 可以很好的接受 oracle 的写回数据，
一切协议的 server 端就都可以实现。

因此，nodejs 到 oracle 的请求，oracle 到 nodejs 的回复是一切协议支持的基础。

oracle 的 tcp 读写支持都要基于 utl_tcp 包进行设计
而 javascript 则要考虑最新的 typed array 等最新二级制数据支持情况。
这个核心的数据通讯编程方法确定好了，就是 Noradle psp.web v6 的根基。
然后一切协议皆可实现。

数据交互协议设计
================

nodejs to oracle
----------------

nodejs 主动调用 oracle，而 oracle 主动 DCO 并接受回复的 in PDU 又和区别呢？

DCO 回复可以多个请求的回复一次传回 oracle，
传回PDU都包含自身完整长度和有 in session unique 的请求 ID。
传回的 PDU 都要先放到各自一 id 为索引的 blob 中先保存。
然后再分析 blob 中内容，而不能从网络流中执行处理。

oracle 作为被动的 server，接受请求只有一个请求，
然后一直等待一个响应或者是 message stream 响应。
oracle 测可以采用流式方式 parse income tcp stream，并最终执行主过程。
只有对 put/post 的体，或是上传文件，才可能会先保存到 blob 中。

因此可以看到，
DCO 的 parser plsql 应该偏重于使用 dbms_lob 包进行处理
DBCall 的 parse plsql 应该偏重于使用 utl_tcp 包进行处理

考虑到 DBCall 在 oracle 侧可以使用 utl_tcp 直接读取入参，
因此在此处分析 utl_tcp 的读取接口

		UTL_TCP.GET_RAW (
		   c     IN OUT NOCOPY connection,
		   len   IN            PLS_INTEGER DEFAULT 1,
		   peek  IN            BOOLEAN     DEFAULT FALSE)
		 RETURN RAW;

		UTL_TCP.GET_TEXT (
		   c    IN OUT NOCOPY connection,
		   len  IN            PLS_INTEGER DEFAULT 1,
		   peek IN            BOOLEAN     DEFAULT FALSE)
		 RETURN VARCHAR2;

		UTL_TCP.GET_LINE (
		   c           IN OUT NOCOPY connection,
		   remove_crlf IN            BOOLEAN DEFAULT FALSE,
		   peek        IN            BOOLEAN DEFAULT FALSE)
    RETURN VARCHAR2;

因此可以看到可以支持一下方式
1. by line: is.get, is.getn, is.getd
2. TLV 方式
3. text/raw 对于参数为大段文本且可能其中有换行符的情况适用
  is.gett : 首先看 uint4 查看长度，然后按长度指示读取 text
  is.getr : 首先看 unit4 查看长度，按后按长度只是读取 raw

对应的 nodejs 端也有响应的 API 可以将请求数据轻松打入 oracle.

os.put: 自动删除或转换其中的换行符号，以免 oracle 读取时误判。
os.putn, os.putd
os.putt : 自动计算出长度，先发送一个 uint32 长度，在打入实际数据
os.putr : 自动计算出长度，先发送一个 uint32 长度，在打入实际数据

这样 nodejs 可以向 oracle 打入各种类型的数据

### 其他

特别说明 boolean 作为 T,Y 字符串打入即可。

对于机器级的各种整数浮点数，可以考虑支持。

建议针对各种协议的请求，都设计对应的 type，其可以自动读取上面信息并保存到该 type 实例的成员中去。
之后，主处理程序需要引用入参时，就可以直接从 pv.object.attr 中去区信息了。
或者以上来根据协议，适用 type_param.get_params(conn) 将全部变量读到包变量中。

oracle to nodejs
----------------

无论是 DCO 还是 DBCall，自 oracle 向 nodejs 写数据都是先向 blob 写数据，
然后在通过 utl_tcp 一并发往 nodejs。
因此 plsql API 完全可以相似，无非就是写输出流追加到 blob 中去。

三种 nodejs call oracle 方式
==========================

## 基本的 remote call 模式

  nodejs 将请求发往 oracle，等待 oracle 将结果写回，然后释放连接供其他请求适用。

## 接受 message stream 回复

  nodejs 将请求发往 oracle，oracle 的结果很大，
  因此采用 fragmented message stream 方式发回，
  这样 nodejs 接受完一个段落就可以处理一个段落，
  不用等到全部数据都返回才开始处理，
  这样延时小，nodejs 缓冲内存资源占用小。

## nodejs 单向调用 oracle

  这时，当 nodejs 发送完请求后，即可标记该连接再次为空闲。
  从而其他的请求可以继续。
  实现的方式就是不打算回复的过程直接调用接受输出的 API 即可。
  (todo) 需要设计这么一个 API。
  但是这样依然存在延时，因为毕竟前一请求必须都到了 oracle 并被协议包读取到PV后才可能通过回复释放连接。
  因此还是希望能够由请求方指示释放连接。

协议设计
=============

any server 的主过程
------------------

pmon 首先监听协议名，然后根据协议名动态执行特定协议的主过程。
该主过程读取 tcp socket 中的请求信息，做处理和响应。

现有的 psp.web 的主过程 gateway 需要调整，改成 server.listen.
原先发送的 psp.web 请求的第一个参数前添加新的头参数为协议代号或者是主过程名。

pmon 启动的后台进程也都是 anyserver.listen，而不再是 gateway.listen

原先的 gateway.listen 分解为

1. http.listen
2. dbcall.listen

原先 http 请求信息全部打入 pv 中，然后通过各自协议的 r 包来访问

我们还可以增加如，
1. radius.listen
2. pop3.listen
3. ftp.listen
等等

优势
=======

这样我们可以使用 pl/sql 实现各种协议的服务端，包括有状态协议的服务端(利用GAC/SID)，
而原先协议服务器只将数据库作为数据库，则数据在网络开销上就很慢，
因为处理一个客户端请求，需要前端服务器和数据库服务器的多次往返交互，
还增加了前端服务器解析数据库服务器生成的标准结果集的开销。
现在 pl/sql 存储过程一次行接受全部请求参数，然后最终结果送出即可。
也就是是处理请求所要参考的数据在哪里，程序逻辑就应该写到那里。
如果参数数据在 oracle 数据库，程序逻辑就应该写到 oracle 存储过程中才好。

现在你可以只懂 pl/sql 就可以实现各种协议的服务器，
这个开源软件最终会有大量的 nodejs(或其他语言的) 开发人员去写各个协议的解析器(nodejs前端和oracle侧主解析器)
这时，你只需使用 pl/sql 就可以实现各种协议服务器，如 DNS, radius 等等.
It's very amazing.

anyserver 不仅可以实现基于 tcp 的协议，也可以实现基于 utp 的协议，
比如说 DNS server，前端 nodejs 实现 DNS 请求的解析转成 oracle 易读的格式，
然后 oracle 的 dns.listen 读取请求数据到 pv 中，
然后 dns 处理程序读取数据库中的数据并提供服务。

也可以支持 ftp，ftp nodejs 前端处理会话，
在 oracle 端也会通过 GAC 保存当前的路径，设置属性等环境信息。
然后可以直接将用户对 ftp path/file 的请求，
映射到不同的 blob 表和字段上，或者动态输出表的集合数据。
ftp 的会话由客户端ip:port组成，nodejs 侧使用该值的 md5 hash 生成会话ID。

对于一个经由 nodejs 前端转换完的协议请求包由 protocol.listen 保存到 pv 之后，
就需要存在一个机制将协议具体的请求端点映射成 oracle 特定的存储过程。
这个映射往往需要在 nodejs 前端完成，
比如将 http 的 path 映射成存储过程名，
或者将 ftp 的路径映射成具体的存储过程名。
一般来讲，这种映射关系应该在 nodejs 侧完成，oracle 侧只是负责具体执行功能。
当然，也完全可以在 oracle 端根据接受的协议参数，参考配置和规则，决定执行那个处理程序。

protocol_server.serv 不一定要读取请求信息，它完全可以指定特定的过程读取请求信息，并且生成响应结果。
这样，你完全可以用任何存储过程来处理任何形式的请求，随便你怎么设计都行。
any_server.serv 会先接受 dbu,prog两个参数，然后执行它。

common 请求数据格式顺序要求
-------------------------
* protocol name
》解析协议入参，打入 PV
* 设置 dbu or schema
* 设置 proc or pack.proc or view or table 任何可执行或可查看的目标对象
* 设置 sid (但是 sid 的选择可能需要在特定协议内部定调)
* 调用 dad_entry 转而调用 k_gw.do
* k_gw.do 按照目标程序动态执行，按照相同用户下的 k_filter.before.after一并执行，错误信息返回

protocol_server.serv 做
* 读取协议数据，打入 PV OO
* 做协议格式错误
* 做基本的访问控制
* 指明需要 k_gw 切换用户身份执行的过程名称
* 有任何错误，只要进入的请求流保持同步，就不必退出进程，而是返回错误号
* 0 代表正常，1 代表继续，-1 代表退出

该协议下的真正的处理程序
* 读取 PV OO
* 调用基本输出 API 和协议层面的输出 API，标明结束

区分 http 请求和 DBDriver 请求
-------------------------

anyserver 的处理顺序。
------------------------------------
* node 接受用户请求、对于有会话的生成会话ID
* node 将请求数据解析成 oracle 易读的形式
* node 将数据发往 anyserver.listen
* 第一行请求数据为 protocol 名称，如 http
* anyserver.listen 动态调用 name.listen 执行该协议主处理过程
* 剩余几行为标准的，包括
- 该协议下具体的存储过程的 dbu.pack.proc 定位信息
- 会话 ID
- 上述信息对于每种协议都是通用的，都放到 cpv(common pv) 下
* 协议主处理程序读取协议请求参数
* 协议主处理程序执行端点过程
* 端点过程通过协议请求访问包获取请求参数，执行处理
* 端点过程调用公共的 utl_tcp 和 blob buffer API 进行输出
* 端点过程执行完
* 协议主处理程序将响应输出，也就是 blob buffer 中为输出的部分
* 结束信息标识方法如下
- 第一是在响应的一开始就写响应体的长度
- 如果长度是负数，其绝对值就是该部分的长度，并且后面一定还有其他部分
- 如果长度是正数，该值就代表是回复的最后一个部分(或是唯一的部分)
- 这样 nodejs 端可以很方便的知道返回响应是否完毕了。
- 这样，一切响应都可以
- 1. 直接写 tcp，但是前面都有写入的长度标志，包括标志本身的长度
- 2. 写 blob buffer，然后调用 API 将 buffer 内容一并写出

todo:
* 第一行先改为是 http

可能访问一个页面的时候，除了主页面外，还会有一个甚至多个定长附件部分。
这时主页面 header 返回时，系统就应该可以决定还有多少个后续部分，
follows = [feedback]
follows = [main,css]
这样每轮 writeToLength 结束，都要 shift 出一个，如果没有了，就执行 res.end,fin


输入流
-------
各个 xxx_server.serv 直接从 pv.c TCP connection 中直接读取数据，

### 确保读完请求数据
并且一定要确保其中的数据读完，
如果不能读完，那么下次该连接被别的请求复用时，就是出现错位，
下个请求的读取程序会读到上个请求没读完的数据。
请求的最后必须是一个特殊标识.
每轮请求处理完后，在循环的最后会读取该标识，
如果没有内容或内容不是该标识，那么就证明 nodejs 协议接入器没有按照协议要求发送请求，
这时，gateway.listen 关闭并重新建立新连接，但是不必退出。
读取该标识超时设置为0或很短。
要求 nodejs 发送该结束标识不能延迟，
这样发现有问题的时候可以很快检测出来，从而释放进程资源处理下一个请求。


### 请求中包含上行的流式数据和上行文件，并且是可选的
上行的流式数据原则上无需进入数据库中，
但是如果一定要上行，那么
1. 不必须在非上行文件后面读取
2. 不能可选，如果上行文件，就必须读取，一般接受先接受到 pv.blobs 中
表单上传文件必须指示 psp.web nodejs 前端是否上传文件到 oracle.
提供 get_blob(length,blob out)
提供 get_blob(name in) API，读取以下格式的文件上传
utl_tcp.get_length
utl_tcp.read_raw
保存到 pv.rblobs(name) 中，或 rb.xxx 中。

### 读取方法

使用以下 API 来读取请求信息
utl_tcp.read_raw
utl_tcp.read_text
utl_tcp.read_line
该如何调用，由协议自己决定，但是最后一定要有一个 read_line 得到


输出流
------
head
body
feedback head
feedback body
css head
css body
stream frame body （如果 len<0，则代表该 frame 不是 final frame）
chunk body

如果 stream flush 过，则不好判断 body 何时结束了。


OO
-----
还不如直接借鉴 J2EE 的 servlet 模式呢。
servertype
package s 代表一个 servlet
s.r 代表请求 -> 指向特定协议下的请求，
这样，很多个协议都可以继承 r class，形成特定协议的 req 对象。
然后该协议下具体的 servlet 就可以访问该信息来完成响应。


output 对 HTTP 协议和其他协议的区别。
----------------------------------

### header

http 有 header 信息，其中有 chunked 传输方式，或者 content-length 信息。
这些信息可以决定数据流在何处结束。

但是对于 arbitrary protocol 来说，可能有其他的长度指定方法。
通常，像短信协议等等低级协议，都要求在一开始就要标明信息块的长度，
而且该长度包含长度自身。
对于只有一个回复的简单协议，node front gateway 就可以直接知道响应何时结束了。
对于有多个回复的协议，可以采用多 frame 方式返回，通过在最后一个 frame 的长度为 - 来得知是最后的 frame。

这样 HTTP/DATA 协议也都可以按此方式改造
1. header 构成第一个 frame
2. body 构成第二个 frame
3. 如果中间 flush，则在最后 flush 的时候使用负数 flush。

要求输出时，要么一定性的填好 frame，并加上长度头发送。
要吗一点点在 buffer 中输出，然后调用 flush 输出中间的 flush。
然后在最后调用 finish 输出长度取负的 frame。

当然也不好强求，因为完全可以边产生数据边写 tcp，虽然这可能造成网络传输的碎片化。
处于性能考虑，应该禁止网络传输的碎片化。

如果 node 接受了一部分响应就认为读完全部响应了，
那么 node 会将该 oraSock 退还连接池，
这时连接池可能马上转给其他请求使用，
这些请求就会接受到上一个请求后续发出的响应，
这样请求-回复对应关系就会搞乱了，
因此有必要确保收到响应的头必须是指定的模式，
否则就认为收到了之前响应的残余部分。

如果都按照 HTTP 模式输出响应，然后在 nodejs 端做处理显然不合适。
因为 http 在 node 端会有压缩，计算 digest 等过程，
这些过程对于其他协议可能就完全不需要。
因此我们只能允许自由输出。

因为预知长度的响应可能很大，如果只作为一个 frame 输出，做 stream spliter 操作就会等待全部拼接完才会处理。
这样就会产生一定的延迟，因此需要将每个 tcp buffer 满了就输出一个 frame。

因此基本的输出 API 就有两个。
resp.write_frame(text varchar2)
resp.write_frame(
resp.write_buffer()
resp.flush_buffer()
resp.end()

<script src="footer.js"></script>