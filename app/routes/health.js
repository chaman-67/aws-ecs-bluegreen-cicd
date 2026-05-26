const router = require('express').Router();

const startedAt = Date.now();

router.get('/', (_, res) => {
  res.json({
    status: 'ok',
    uptime_seconds: Math.floor((Date.now() - startedAt) / 1000),
    version: process.env.APP_VERSION || 'dev',
    sha: process.env.BUILD_SHA || 'local',
    region: process.env.AWS_REGION || 'unknown',
  });
});

router.get('/ready', (_, res) => {
  res.json({ ready: true });
});

router.get('/live', (_, res) => res.sendStatus(200));

module.exports = router;
