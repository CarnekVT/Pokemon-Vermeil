# 2.5D Geometry v4 — mandatory clean reset

V4 intentionally does not read the old `Data/VERMEIL2_5D` folder.

Before using the editor, delete the entire folder:

`Data/VERMEIL2_5D/`

The editor blocks itself while that folder exists. This is intentional and prevents ghost terrain, stale compiled objects and old runtime JSON from returning.

V4 writes new non-JSON files to:

`Data/VERMEIL_GEOMETRY_V4/`

- `MapXXX.v25d` authoring
- `MapXXX.v25r` runtime terrain
- `MapXXX.v25c` collision
- `MapXXX.v25m` deferred model mesh stream

The new format is a strict tagged format, not JSON. Terrain is authoritative and does not inherit legacy terrain heights.
