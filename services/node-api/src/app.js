const express = require('express');

const app = express();

app.get('/', (_req, res) => {
  res.json({
    service: 'node-api',
    message: 'Hello from Node through Jenkins'
  });
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;

