<script src="header.js"></script>

<div id="title"> Noradle Message Stream </div>

  A PL/SQL stored procedure for db call is not limited to generate a result page once, but can produce messages as a stream, at the NodeJS side, the stream is split, every message will emit a event.

  Message Stream can be used to sent out messages or request to the outside of oracle database, although it need NodeJS side to proactively call a message stream producer stored procedure. It's a bit different from the Noradle direct external call, it's can use any existing output API, move burden from user facing call to background message stream SP. If you want scheduled tasks to collect statistics and sent out, Message Stream will not work, because it's naturally a registered mechanism, so use direct external call in the above tasks instead.

Use Cases
==============

* You want some database events (like CPU or IO threshold is reached) to be reported to NodeJS, and then IM/SMS to system administrator or display in the monitor browser through web-socket.
* You want to detect data change and send the change message to NodeJS
* You want all inserted data to be synchronized to your partners corporation's system through NodeJS.

PL/SQL programming API ( bkr )
==============

  bkr is the shortcut synonym for psp.k_broker.

  The oracle response Content-Type is **"text/noradle.msg.stream"**, and charset is fixed to **'UTF-8'**. So NodeJS side will recognize the result as a message stream, and apply stream splitter for cut up discrete messages for emitting **message** events. When the stored procedure finished, it will disconnect from NodeJS and quit background oracle process for resource recycle.

Basic API
--------------

  the stored procedure for producing message stream is like this:

	bkr.stream_open;
	-- write output 1
	bkr.emit_msg;
	-- write output 2
	bkr.emit_msg;
	...
	bkr.stream_close;

  Call **bkr.stream_open** at the beginning, and call **bkr.stream_close** as the end. In the main parts, for every message to be wrote out, use any existing output API like h.line, h.xxx, p.xxx to generate message content, and then call **bkr.emit_msg** to flush out the message content to NodeJS.

  For a practical message stream, the stored procedure will not generate all messages at once, instead, it will generate next message after a interval from the time of the previous message sent, or it will wait for a oracle alert or pipe event, and then do some work and making new message and sent it to NodeJS. like this:

	bkr.stream_open;
	loop
	  dbms_alert.waitone('alert_name', message, status, timeout);
	  if message = 'quit' then
	    return;
	  end if;
	  -- write output
	  ...
	  bkr.emit_msg;
	end loop;
	bkr.stream_close;


High level API (two stage message stream)
--------------

  Since practical message stream

  Browser call some psp.web procedure, the PL/SQL will log request info in db and then emit a event(throuth alert/pipe) directly or by trigger. The message stream SP will wait for alert/pipe event, use SQL to find the newly logged requests info, and then use them to make a message and sent out to NodeJS. This way, the user-facing SP delegate the after logging work to message stream SP, and response to end-user more quickly. The processing work is decoupled, this is why we use two stage message stream, one stage(**sender**) is for logging and emit new request(with or without key clue like rowid), the other stage(**broker**) is for select and join tables to make message to NodeJS.

   Further more, we can wrap the work for the above template, and provide high level API. The abstraction is that: the sender is sending key/index/clue to a particular pipe for the broker to receive instantly, it can send **rowid** of the newly inserted info, the broker will get the rowid and use it to fetch main table data and it's sub-table data quickly, and make/send message to NodeJS. Optionally, the sender can send handler string for broker to dynamic execute it, can send table name if multiple table is involved, send event type if one rowid has insert/update/delete or the other variant messages.

  You can use brk.write_event to write standard key event structure to the broker, the broker can use brk.read_event to get the event key info, further more, if you use brk.write_event to write enough info, you are even not required to write a broker listener SP, you write event handler only. Parameters including table_name, rowid, type, callback will be passed to handler, in handle you just fetch data for the table_name, rowid, type and make message content, auto stream broker will just send the message to NodeJS.

  For the sender, call the write_event API.

	procedure write_event
	(
		broker varchar2,
		v      event
	);

	procedure write_event
	(
		broker      varchar2,
		req_handler varchar2,
		evt_table   varchar2,
		evt_rowid   rowid,
		evt_type    varchar2 := null,
		res_handler varchar2 := null
	);

  For the broker, call the read\_event API. The auto_stream will call read_event internally.

	type event is record(
		req_handler varchar2(99),
		res_handler varchar2(99),
		evt_table   varchar2(30),
		evt_rowid   rowid,
		evt_type    varchar2(30));

	function read_event(stream_name varchar2 := null) return event;

NodeJS side
-------------
  The NodeJS message stream register code is just like normal oracle db call, you create a instance of Noradle.DBCall, and then call with plsql name and parameters, and the callback will receive the result. The different is:

1. the **callback(err,msg)** will be execute for every message in the message stream and for the finish of stream
2. you can use **msgStream.on('message', function(msg){...})** for additional capture of message in the stream
3. you can use **msgStream.on('finish', function(){...})** for additional capture of finish event in the stream
4. you can use **dbCall.on('message', function(msg){...})** for additional capture of message in the stream in DBCall instance level


	var Noradle = require('..')
    , dbc = new Noradle.DBCall('demo', 'theOnlyDB')
    , msgStream
    , count = 0
    , plsq = 'callout_broker_h.emit_messages'
    , params = {}
    ;
	msgStream = dbc.call(plsql, params, function(err, msg){
	  if (err) {
	    console.error(status);
	    process.exit(2);
	  } else if (!msg) {
	    console.log('The End');
	    return;
	  }
	  console.log(msg);
	  console.log('\nNO.%d message arrived @callback:', ++count);
	});

	// essential when the source message stream will be propagated to more than one destinations
	msgStream.on('message', function(msg){
	  console.log('message (%s) is sent(synchronized) to www.sina.com.cn', msg.replace(/\n$/, ''));
	});
	msgStream.on('message', function(msg){
	  console.log('message (%s) is sent(synchronized) to www.tencent.com', msg.replace(/\n$/, ''));
	});

	dbc.on('message', function(msg){
	  console.log('message (%s) is captured at DBCall level', msg.replace(/\n$/, ''));
	});


Error handling
---------

  If making a message in the stream encounter a exception, the callback in dbc.call will get err parameter a error text.
You can log the error text or alert it to administrator. Internally, the 4 byte message length field will be positive
for normal message, and be negtive for error message.


NodeJS 主动调用的 output message stream broker 的局限性
=====================================================

    NodeJS 主动退出后，Oracle 侧的 broker 可能还会继续执行，
broker 将读取下一条消息 key，并且生成下一条完整的消息，
然后在写 socket 时发生错误，从而丢失最后一条消息。

可能的解决方法：

1. 最好 broker  使用 peek 方式读 pipe，可惜 Oracle 不支持此 peek 特性。
2. 因此需要 broker 将读到的 pipe 再写回到 pipe 中，但是这个会造成当前的消息排列到了最后处理。
3. 这样只好重新连接 NodeJS，但问题是 output message stream 只能由 NodeJS 侧主动发起，在连接到 Oracle 就不知道是哪个过程了。
4. 需要 broker 先退出然后 NodeJS 才能退出。如果在每个消息读之前，broker 都锁定 NodeJS 不要退出，似乎没有办法做到，因为 NodeJS 随时可能以任何方式死掉。
5. NodeJS 在 stream 未结束时，应该不退出，并且监听结束事件，这样可以做到 graceful 退出。

message stream 用于 node 从 oracle 获取流式数据是非常好的
======================================================

  因为是 nodejs 主动向 oracle 要数据，而不是 oracle 主动向外发送数据，因此使用 message stream 可以加快 nodejs 处理 oracle 大数据的效率。
  因此，message stream 依然保留，但是只作为 framed stream 由 nodejs 主动请求 oracle 数据使用。

【问题】
message stream 在生成某一个消息时出错，该如何标识错误消息呢？
可以捕获错误，然后清除缓存内存，重新打入错误信息。
可以 emit 带有错误标识的信息，即内容长度为负数即可。

【MS vs DCO】
MS 需要为代理程序单独配置 in oracle 连接。退出进程时，不易同步退出后台进程，从而造成消息写到空 TCP socket 最终丢失。
DCO 有可靠的连接，能够识别和处理进程意外退出，连接意外中断的情况，支持安全的手动退出，因此不会造成消息丢失。
而 MS 使用的 DBCall 机制主要面向的是客户端程序对 oracle 的调用，客户端断掉其实没有影响。
但是将服务器端使用客户端方式被调用，可能会造成请求丢失。


<script src="footer.js"></script>