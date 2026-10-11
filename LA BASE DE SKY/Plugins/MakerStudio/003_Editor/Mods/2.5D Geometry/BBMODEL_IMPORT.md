# Blockbench import — Geometry 4.1.1

Supported `.bbmodel` element types:
- Cuboid / cube elements (`from` + `to`)
- Free Model `mesh` elements (`vertices` + `faces`)

Mesh import:
- 3-vertex faces are retained as runtime-compatible degenerate quads.
- 4-vertex faces are imported directly.
- N-gons are triangulated as a fan.
- Blockbench element origin/rotation is baked into mesh vertices.
- Per-face texture references are preserved.
- Original per-vertex UV coordinates are retained as `uv_points`; a normalized UV bounding rectangle is also generated for the current V25 renderer.
- Embedded PNG textures are copied to `Graphics/Models/` when Maker Studio permits binary writes.

The importer no longer requires a cuboid to exist in the file.
