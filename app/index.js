const express = require('express');
const app = express();
const PORT = process.env.PORT || 8090;

app.use(express.json());

// In-memory store — resets on restart, no DB
let items = [];

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/items', (req, res) => {
  res.status(200).json(items);
});

app.post('/items', (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: 'name is required' });
  }
  const item = { id: items.length + 1, name };
  items.push(item);
  res.status(201).json(item);
});

app.delete('/items/:id', (req, res) => {
  const id = parseInt(req.params.id, 10);
  items = items.filter(i => i.id !== id);
  res.status(204).send();
});

app.listen(PORT, () => {
  console.log(`Middleware running on port ${PORT}`);
});