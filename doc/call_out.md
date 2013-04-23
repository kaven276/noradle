<script src="header.js"></script>

<div id="title"> Oracle call outside net service Thinking </div>

使用统一的标准监听器具有巨大的优势，主要体现在方便性上。

  1. oracle 只需通过 k_pmon 启动一组标准 message stream broker 即可，broker deamon 的启停管理都非常的方便
  2. 标准 broker 可以事先实现到 NodeJS proxy router 的连接，而且可以基本保证在 k_pmon 启动服务时就建立好连接
  3. 标准 broker 在 daemon 运行过程中，如果发现连接中断，可以自动切换到其他的 NodeJS proxy router
  4. 标准 broker 在需要动态执行存储过程生成对外 PDU 的时候，是动态执行，不会锁定相关的过程，也不会受被执行的过程的影响
  5. 标准 broker 可以定期的重启以释放资源，如果是 NodeJS proxy 主动连接执行 out broker，就很难有机会进行重启

可以看到，上述特点都非常重要，如果在每个自定义的 out broker 上实现上述特性，将是非常的困难的，因此我们必须通过标准的 broker 进行对外请求。

另外，使用了标准 broker 后，可以实现标准的 NodeJS proxy router，该 router 可以部署到和 oracle 在一起的内部网络中，
这样，oracle 访问该 router 由于只能使用不加密的 tcp，但是 router 可以通过加密链接访问处于其他网络位置的专有 proxy.
这样，处于不同内部网络的 oracle 分别拥有自己的 NodeJS proxy router，但是确可以安全的共享一组位于任何网络位置的专有 NodeJS proxy。
-----

下面分析了各类型的 PDU 的格式
一、pipe 消息格式
二、oracle 到 NodeJS 的消息格式

因为本设计必须照顾到必须通过 dbms_pipe 发送消息，因此最终的 API 一定是尽量符合 dbms_pipe 的规格的。
参考一些网络应用协议，如 SGIP,SMPP,Email,WebSocket，
同时考虑 NodeJS 使用 javascript 容易接受和解析来自 oracle 的消息。
最后，希望消息格式能够充分表达 json 和 xml 能够表达的数据结构。

因为 dbms_pipe 采用 .pack_message 方法向内部打入消息，因此可以将一个 pack item 作为一行或者一个 TLV 发送给 NodeJS.

为了使最终的 pipe 消息能够很好高效的还原成 json 形式的消息，并且充分利用 V8 的类化数据结构，就需要专门的设计。

参考 xml，xml 无非就是级联的数据结构加上元素属性，如果将属性改为所属第一项子元素，该元素存储名值对的化，就其整体结构上来说，完全可以用 json 表达。
但是 xml 的具体数据项包含了字符串、二进制数据和注释。
因此 Noradle PDU 必须支持二进制数据，为了更好的支持二进制数据，就必须使用 TLV
对于 oracle 来说，因为 pipe 可以发送 raw 数据，因此完全可以支持向 NodeJS 发送不经转换的二进制数据。

【借鉴 WebSocket 的设计】

一、WebSocket协议看上去是 http 协议
WebSocket 协议的目标是任意两个节点的无阻碍双向通信，并且可以借助标准的 http proxy/gateway/tunnel 进行中转，这个功能对 BS 模式通信非常重要，可以利用现有的网络中转服务。
但是对于 Noradle psp2node 功能来说，确不重要，因为 NodeJS proxy router 总是要放在和 oracle 一起的内网。
而该 NodeJS proxy router (NJPR) 总是可以使用 websocket 协议和专有 NodeJS proxy 通信，甚至可以采用 ssl 进行加密通信。
因此关于利用 http upgrade 的设计其实对 Noradle psp2node 功能是不需要的。

二、WebSocket支持 framing
参考 WebSocket 协议，它支持 framing，主要是为了避免 buffer 完整的大消息，和使用 multiplex 防止一个大消息占用完整的通道。
对于 Noradle 来说，因为可以同时建立多个到 NodeJS proxy router 的链接，并且同时监听和处理 OutProxy pipe 消息，因此不存在大消息占用完整通道的问题。
同时，Noradle 使用内存 blob 缓存任意大小的消息，内存占用大小根本就不是问题，因此完全可以不采用 framing 的复杂设计。

三、WebSocket分为 text 和 binary frame
Noradle 的 PDU 的内部结构完全可以包含文本和二进制内容，因此无需区分 text/binary PDU

四、WebSocket 支持 mask (只要求从浏览器客户端到服务器的通讯加密)
因为从用户终端发往服务器的数据可能带有私人敏感数据(如用户名密码等等)，而服务端的返回结果往往相对不太私密。所以 WebSocket 要求单向做 mask.
但是考虑到 Noradle 中，oracle 向 NodeJS proxy router 的数据流都在内网，而且都是服务器之间的通信，因此完全不需要做任何安全措施。
这不光不需要进行 mask ，也不许要 ssl。如果增加安全措施，反而会浪费处理资源，白白增加无谓的消耗。

五、WebSocket  支持灵活紧缩的 PDU 长度标识
Noradle 认为都使用 UInt32BE 写下 PDU 长度也不过占用4个字节，因此没有必要做太细的设计。因为虽然可以节省两三个字节，但是接收端的处理更为复杂，给开发和运行带来负担，最终并不划算。

六、WebSocket 支持 ping/pong frame
只要 oracle 进程在，其持有的到 NodeJS proxy router 的连接都不会断，一旦断了就会重试，如果连接不上就会是下一个 NodeJS proxy router。
oracle 发起的 TCP 不会超时自动端掉，而 NodeJS 也不会超时自动断掉 socket server，而且 oracle 无 buffer TCP 发送如果遇到问题一定会报错，
也就是发送 PDU length 的时候一定会报错，因此完成可以重新连接并且重发。
因此 ping/pong 所起的检查连接可用和保持连接(防止超时自动断开)的功能根本就无需使用。

七、WebSocket close control frame
在 Noradle 中，oracle 到 NodeJS proxy router 的连接永远都不应该关闭，因此根本就无需 close frame.

结论：Noradle 中 oracle 向 NodeJS proxy router 发送对外请求 PDU 的协议，不用向 WebSocket 那么复杂，可以非常的简单。

【专有 NodeJS proxy 的网络协议设计】
首先是要确保有 javascript 接口的网络应用协议的客户端实现，比如说 soap client, email client, ftp client 等等。
然后开发一个专门为 oracle 调用的接口，只要 oracle 将指定格式的消息发往该接口，该接口就可以解析 PDU 并转换为调用 javascript client API 的调用。
而且该接口也可以为其他非 oracle 软件提供服务接口，只要使用标准 http 请求，http body 中填入指定的消息就可以。
这样 NodeJS proxy 只要设计为标准的 http 服务即可，而 NodeJS proxy router 不过是带有路由转发的 http 代理而已。
出于效率的考虑，该 http 服务的请求需要提供 header 部分的大小，因此采用类 http 的设计，但是最终提供的是 socket 服务。
该服务更像是 WebSocket 服务，因为也是首先先发送 http 头部给服务器，然后在发送一个个的消息，而且每个消息的开始都是消息的长度。
它又有些像 soap 协议，因为 soap 协议的 envelop 也是在 http body 内，Noradle 出于效率考虑，envelop/header 部分先写长度 Uint
Get xxx 第一行，代表了需要访问什么服务，比如说 SGIP submit，NodeJS proxy router 就会将 psp2node PDU 转发到 SP 服务上，内容原封不动。

极端好的情况，要实现的网络应用协议完全可以用 pl/sql 实现，这时，NodeJS proxy 就简单化为纯消息队列服务（提供可靠传输、路由、加密...）
如果 pl/sql 不太好实现该网络应用协议(比如说二进制处理等等)，或者比用 NodeJS 实现更加麻烦，或者没有必要完整的实现，那么就课程设计简化的应用协议，
该协议实现原协议中有用的部分，消息格式更适合于 oracle 生成和 javascript 解析。
当然，我们的设计并不是为了实现固有的网络应用协议，真正的目标还是能够使用 PL/SQL API 调用网络协议，这才是真正的目的。

可以实现的协议包有

  1. soap client. 但是是将 json 或 json/yaml 格式的数据，其实生成 yaml 格式的数据相对还是比较简单的，而且也容易找到现成的解析器
  2. SGIP PDU
  3. SMPP PDU
  4. GET Email
  5. Send Email
  6. Get FTP
  7. 获取当前登录用户的手机号

TCP PDU 格式

  1. 包长度 UInt16BE，最大 PDU 支持 64K
  2. header 长度，包含 header 自身，Uint8，最大 256 字节
  3. header 内容，固定部分属性和TLV （可能有压缩标志一个字节、消息协议类型号 1 个字节共支持 256 种）
  4. body 内容

其中 header 内容包括

  1. 路由目标代号：1 byte，NodeJS proxy router 根据它进行路由，需要为每个具体的 NodeJS proxy 分配一个代号该代码映射到一个 UDP/TCP 服务的地址和预先建立到该地址的唯一连接(router proxy 和专业 proxy的连接(不可以是非NodeJS的))当然也可以建立多个连接，但是每个连接是完全相同的，没有任何区别。目标路由代码使用 Int8，
  2. 同步调用的回调目标代码：该代码请求序列号(UInt8，每个数据库实例的每个服务进程中唯一) 循环使用，router proxy 根据接受的 Noradle out PDU，将器头部追加上数据库实例号(IInt8) 和数据库服务进程号(UInt8 不会同时超过256个Noradle 服务运行)然后在将改过的 PDU 发给专业 proxy，专业 proxy 生成完响应后，会将数据库实例号和进程号将响应 PDU 发回到 router proxy，router proxy 根据响应 PDU 中的 dbid,pid 参考自己的接入连接登记表，将响应 PDU 体发往正确的 oracle 实例中的正确的 oracle 进程。oracle 存储过程可以在发出多个请求 PDU 后，先做些别的工作，等到需要响应结果的时候，在调用 get 等待，当有响应发回时，该响应带有该进程内唯一的请求号，存储过程就可以知道是那个响应先返回了，就可以解析他，并将结果存到局部变量或包变量中。如果该响应是当前需要的响应，就可以继续处理，如果不是，也可以解析并存储结果，但是还要继续等待。响应 PDU 应该设计成适合流式处理的，也就是使用 utl_tcp 的 readline 和 read(length) 顺序处理就可以解析的形式。这样就不用 oracle 设立大的 blob buffer 消耗资源。
  3. 异步调用的回调。请求中添加目标库实例代码(地址和实例号)和存储过程名，也就是说指定了特定库的特定用户下的特定存储过程来接受响应结果。上述信息作为 PDU 中的 meta header 部分一起通过 router proxy 到达专业 proxy，该专业 proxy 处理完成后，按照 meta header 中的指定接受方，使用 javascript2oracle API 将响应结果回写数据库。
同步调用代码和异步调用代码都使用 TLV 方式，对于特定的 Type，Length 是固定的从而无需指定。

  1. 同步调用回调目标代码，只有一个，如果无需同步调用，则填写 UInt32 的 0
  2. 异步调用回调地址，第一个字节 UInt8 代表有多少个异步回调地址，然后后面每个异步回调地址写一个字节 UInt8 长度，然后是具体的回调目的地。
协议的总体要求：

  1. 能够实现 multiplex，也就是每个 oracle 进程只需要连接一个 NodeJS 代理服务器，就可以间接的实现到全部外部服务的连接。原先一个 oracle 进程需要向多个服务器的连接多路复用到一个 NodeJS 连接上，需要在每个发往 NodeJS 的消息头上都追加路由代号，也就是 NodeJS 再向外连接时使用的客户端端口号。这样，oracle 就可以按照 Noradle PDU 发送消息，消息中除了头部的 UInt16 端口号外，其余的部分都会转发到最终的真实的目的地这样，每个 oracle 进程的每个对外连接请求都会转换为 NodeJS proxy router 到外部的连接，这就带来了一个问题。对于像 SGIP 这样的协议，其实一个 oracle 库中的哪个进程访问 NodeJS SP 代理服务都只需要 NodeJS proxy router 建立一个到 SP 代理服务的连接就够用了。connect(host,port,dblevel) 然后返回一个连接句柄(其实是 NodeJS 实际对外连接用的端口号或对外 socket 号)，然后 oracle 可以 write_xxx 向 Noradle PDU 中写入内容，然后调用 send(连接句柄) 将详细发出，这时 NodeJS proxy router 就会将该 PDU 转发到相应的目标服务上。这时，表面上看 oracle 同时连接了多个外部服务，但是其实只连接了一个 NodeJS proxy router 服务。当 oracle 需要对外同步请求时，发出请求后会等待回复，这时 oracle 可以同时发出多个目标地址的请求，然后等待其中的任意一个返回结果。还可以发出请求后，先做写别的事情，完了再接受结果。这样 oracle 的对外网络调用就会更加灵活。特别是可以等待并发请求的同步回复，这将大大提高 Noradle 进程的 CPU 利用率，在需要结果返回的时候才等待结果返回真是太棒了。这样每个 psp.web 页面请求可以将发出全部外部调用，然后在生成页面的过程中，需要哪个响应就等待哪个响应好了。

【有状态协议和无状态协议的支持】
上面的设计都是针对无状态协议的，所有专业 proxy 可以启动时就登录到目标外部服务器或者需要时再登录。
然后 oracle 通过 router 向他们发送请求 PDU，专业 proxy 解析完请求 PDU 后，组成对外的请求 PDU 然后等待结果。

然是如果遇到了 oracle 要访问外部的一个有状态服务器，比如说根据不同登录会话的身份继续发出相同的请求，但是响应结果不相同。
这就需要 oracle 发往外部的 PDU 要包含一个流标识，该标识只需要在进程内唯一即可，
这样 router proxy 和专业 proxy 就知道 dbid+pid+streamid 相同值时，是一个有状态的流，这时该专业 proxy 可能会为该流单独建立一个到目标外部服务器的连接。


<script src="footer.js"></script>