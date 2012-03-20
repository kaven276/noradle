var e = require('express');
var app = e.createServer();
var cfg = require('./cfg.js');
var path = require('path');

var oneDay = 24 * 60 * 60 * 1000;
var dir = cfg.static_root || path.join(__dirname, '../static');
var doc = path.join(__dirname, '../doc');

app.use(e.favicon());
app.use('/doc', require('./compiler.js')({
    src: doc,
    enable: ['marked', 'stylus']
}));
app.use('/doc', e.static(doc, {
    maxAge: oneDay * 1
}));
app.use('/doc', e.directory(doc, {
    icons: true
}));
app.use(e.static(dir, {
    maxAge: oneDay * 1
}));
app.use(e.directory(dir, {
    icons: true
}));

var port = process.argv[2] || 81;
app.listen(port);
console.log("static server is listening at port " + port);
