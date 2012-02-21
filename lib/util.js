var fs = require('fs');
var uploadDir = require('./cfg').upload_dir;
exports.ensureDir = function(path) {
    console.log('ensure dir for %s', path);
    var sects = path.split('/');
    var len = sects.length - 1;
    console.log('len=' + len);
    for (var i = len; i > 0; i--) {
        var tryPath = uploadDir + sects.slice(0, i).join('/');
        console.log('try path = %s', tryPath);
        try {
            var stat = fs.statSync(tryPath);
            // if (stat.isDirectory()) ...;
        } catch(e) {
            continue;
        }
        break;
    }
    for (var j = i; j < len; j++) {
        console.log('j=' + j);
        tryPath = uploadDir + sects.slice(0, j + 1).join('/');
        console.log('mkdir %s', tryPath);
        fs.mkdirSync(tryPath);
    }
}
