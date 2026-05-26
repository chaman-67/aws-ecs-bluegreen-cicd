const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const client = require('prom-client');

const health = require('./routes/health');
const api = require('./routes/api');

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || require('../package.json').version || 'dev';
const BUILD_SHA = process.env.BUILD_SHA || 'local';

const app = express();

const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: 'sample_api_' });
const httpDuration = new client.Histogram({
  name: 'sample_api_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});
register.registerMetric(httpDuration);

app.use(helmet());
app.use(express.json());
app.use(morgan('combined'));

app.use((req, res, next) => {
  const end = httpDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path || req.path, status: res.statusCode });
  });
  next();
});

app.use('/health', health);
app.use('/api', api);

app.get('/', (_, res) => res.json({ service: 'sample-api', version: APP_VERSION, sha: BUILD_SHA }));

app.get('/metrics', async (_, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error' });
});

if (require.main === module) {
  app.listen(PORT, () => console.log(`sample-api v${APP_VERSION} (${BUILD_SHA}) listening on :${PORT}`));
}

module.exports = app;
