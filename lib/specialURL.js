/**
 * Created by cuccpkfs on 15-9-15.
 */
"use strict";

var urlParse = require('url').parse
  , fs = require('fs')
  , path = require('path')
  , fileRSParser = fs.readFileSync(path.join(__dirname, 'RSParser.js'))
  , fileNGResultsetsConverter = fs.readFileSync(path.join(__dirname, 'client/ng-resultsets-converter.js'))
  , fileJQResultsetsConverter = fs.readFileSync(path.join(__dirname, 'client/jq-resultsets-converter.js'))
  ;


exports.handler = function(req, res, next, cfg){

  if (req.url.substr(0, 3) !== '/_/') return false;

  var u = urlParse(req.url.substr(2));

  function responseFile(file){
    res.writeHead(200, {
      'Content-Length' : file.length.toString(),
      'Content-Type' : 'application/javascript',
      'Cache-Control' : 'public, max-age=86400'
    });
    res.end(file);
    return true;
  }

  switch (u.pathname) {
    case '/about':
      res.end('NORADLE for PL/SQL http servlet');
      return true;
    case '/js/RSParser.js':
      return responseFile(fileRSParser);
    case '/js/ng-resultsets-converter.js':
      return responseFile(fileNGResultsetsConverter);
    case '/js/jq-resultsets-converter.js':
      return responseFile(fileJQResultsetsConverter);
  }

  return false;
};