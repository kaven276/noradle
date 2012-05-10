console.info('This is sole pl/sql dynamic page server (service only PL/SQL page)');
console.info('Static file should be served on another server for better proformance and CDN)');
console.info('Usage: node psp.web [oracle_port] [client_port] [client_port_ssl]');

require('./common.js').start_dynamic(require('./psp.web.js'));
