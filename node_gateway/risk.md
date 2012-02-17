## how to use multiple process of node

If one node server will only provide psp.web access, then node will mainly do header parse, data transfer and chunked encoding, cache work. One process can service large number of concurrent request.

If more concurrent request arrived, node may be need to use more processes, then how to divide work between the process ?
By function or by user classification ?

Can multiple node process listen to one port.

Node main process can use cluster to fork many child process that shared the same port.
When new connection arrived, one child process will get the request.

## stability

If some exception occurred, if node will crush.

When long running, if node will run slower and cause memory leak.

Cases what can cause raise exception and quit daemon process

* execute a none-exists procedure
