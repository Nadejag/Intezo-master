// import 'dotenv/config';
const { createProxyMiddleware } = require('http-proxy-middleware');
module.exports = function(app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: "http://localhost:3000",
      changeOrigin: true,
    })
  );
  app.use(
    '/pusher/auth',
    createProxyMiddleware({
      target:  "http://localhost:3000",
      changeOrigin: true,
      secure: false,
    })
  );
};