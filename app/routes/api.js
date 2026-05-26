const router = require('express').Router();

router.get('/items', (_, res) => {
  res.json({
    items: [
      { id: 1, name: 'widget' },
      { id: 2, name: 'gizmo' },
      { id: 3, name: 'doodad' },
    ],
  });
});

router.get('/items/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id) || id < 1 || id > 3) {
    return res.status(404).json({ error: 'not_found' });
  }
  const names = { 1: 'widget', 2: 'gizmo', 3: 'doodad' };
  res.json({ id, name: names[id] });
});

router.post('/echo', (req, res) => {
  res.json({ received: req.body, at: new Date().toISOString() });
});

module.exports = router;
