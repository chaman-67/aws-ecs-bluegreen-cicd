const request = require('supertest');
const app = require('../server');

describe('Health endpoints', () => {
  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body).toHaveProperty('uptime_seconds');
  });

  test('GET /health/ready returns ready:true', async () => {
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
  });

  test('GET /health/live returns 200', async () => {
    const res = await request(app).get('/health/live');
    expect(res.status).toBe(200);
  });
});

describe('API endpoints', () => {
  test('GET /api/items returns 3 items', async () => {
    const res = await request(app).get('/api/items');
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(3);
  });

  test('GET /api/items/2 returns gizmo', async () => {
    const res = await request(app).get('/api/items/2');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('gizmo');
  });

  test('GET /api/items/99 returns 404', async () => {
    const res = await request(app).get('/api/items/99');
    expect(res.status).toBe(404);
  });

  test('POST /api/echo echoes body', async () => {
    const res = await request(app).post('/api/echo').send({ hello: 'world' });
    expect(res.status).toBe(200);
    expect(res.body.received).toEqual({ hello: 'world' });
  });
});

describe('Metrics', () => {
  test('GET /metrics returns prom-format', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('sample_api_');
  });
});
