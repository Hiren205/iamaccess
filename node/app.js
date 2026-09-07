const express = require("express");
const app = express();
app.use(express.json());

// ─── In-memory store ───────────────────────────────────────────────
let items = [];
let nextId = 1;

// ─── Health check (required by EKS / ALB) ──────────────────────────
app.get("/health", (req, res) => res.json({ status: "ok" }));

// ─── Root ──────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({
    message: "Express CRUD API",
    version: "1.0.0",
    endpoints: {
      "GET    /items":      "List all items",
      "POST   /items":      "Create item  { name, description }",
      "GET    /items/:id":  "Get one item",
      "PUT    /items/:id":  "Update item  { name?, description? }",
      "DELETE /items/:id":  "Delete item",
    },
  });
});

// ─── CREATE ────────────────────────────────────────────────────────
app.post("/items", (req, res) => {
  const { name, description } = req.body;
  if (!name) return res.status(400).json({ error: "name is required" });

  const item = {
    id: nextId++,
    name,
    description: description || "",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  items.push(item);
  res.status(201).json(item);
});

// ─── READ ALL ──────────────────────────────────────────────────────
app.get("/items", (req, res) => {
  res.json({ total: items.length, items });
});

// ─── READ ONE ──────────────────────────────────────────────────────
app.get("/items/:id", (req, res) => {
  const item = items.find((i) => i.id === parseInt(req.params.id));
  if (!item) return res.status(404).json({ error: "Item not found" });
  res.json(item);
});

// ─── UPDATE ────────────────────────────────────────────────────────
app.put("/items/:id", (req, res) => {
  const idx = items.findIndex((i) => i.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: "Item not found" });

  const { name, description } = req.body;
  if (name)        items[idx].name        = name;
  if (description !== undefined) items[idx].description = description;
  items[idx].updatedAt = new Date().toISOString();

  res.json(items[idx]);
});

// ─── DELETE ────────────────────────────────────────────────────────
app.delete("/items/:id", (req, res) => {
  const idx = items.findIndex((i) => i.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: "Item not found" });

  const deleted = items.splice(idx, 1)[0];
  res.json({ message: "Deleted successfully", item: deleted });
});

// ─── Start ─────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));