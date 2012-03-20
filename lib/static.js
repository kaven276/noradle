var e = require('express');
var app = e.createServer();
var cfg = require('./cfg.js');

var oneDay = 86400000;
var dir = cfg.static_root || require('path').join(__dirname, '../static');

app.use(e.favicon());
app.use(e.static(dir, {
    maxAge: oneDay * 1
}));
app.use(e.directory(dir, {
    maxAge: oneDay,
    icons: true
}));

var port = process.argv[2] || 81;
app.listen(port);
console.log("static server is listening at port " + port);
