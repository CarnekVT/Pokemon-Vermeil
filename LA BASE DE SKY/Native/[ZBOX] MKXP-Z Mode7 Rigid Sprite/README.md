# MKXP-Z Mode7 Rigid Sprite

Prototipo nativo para MKXP-Z `v2.4.2` (`290ffe1135142d91a40b8f295a7b8e284f432c9a`).

## Qué cambia

- Añade un modo opcional a `Sprite` que proyecta el **quad completo** desde una
  coordenada de mundo.
- La GPU calcula posición, escala cónica y respuesta vertical en el vertex
  shader.
- No corta el bitmap en scanlines ni consulta terrain tags vecinos.
- El `z`, tono, color, opacidad, patrón y viewport siguen usando las rutas
  nativas de `Sprite`.
- Si el ejecutable no contiene el binding, Visual 2.5D usa su renderer Ruby.

## API Ruby expuesta por el ejecutable

```ruby
MKXPZMode7.available?
MKXPZMode7.configure(
  enabled,
  camera_x, camera_y,
  screen_center_x, pivot_y,
  planet_radius, zoom, angle_scale, ground_y_scale,
  curve_weight, linear_weight, width_perspective, vertical_scale
)

sprite.mode7_rigid = true
sprite.mode7_world_x = world_x
sprite.mode7_world_y = world_y
sprite.mode7_elevation = elevation
sprite.mode7_curve_response = 0.08
```

Visual 2.5D ya contiene el adaptador en
`Plugins/[VERMEIL] Visual 2.5D/016_NativeRigidWalls.rb`.

## Aplicar a MKXP-Z

```bash
git clone --branch v2.4.2 https://github.com/mkxp-z/mkxp-z.git
cd mkxp-z
git apply "/ruta/al/juego/Native/[ZBOX] MKXP-Z Mode7 Rigid Sprite/patches/0001-mode7-rigid-sprite.patch"
git diff --check
```

Después compila MKXP-Z para Windows con su toolchain MSYS2/MinGW y reemplaza
`Game.exe` **guardando antes una copia del ejecutable original**.

Este workspace no trae MSYS2, Meson, CMake ni compilador C++, por eso aquí se
validó el parche contra el source exacto y `git diff --check`, pero no se generó
un binario.

## Ajuste

En `001_Settings.rb`:

- `NATIVE_RIGID_WALLS`: activa la ruta cuando el binding existe.
- `NATIVE_WALL_CURVE_RESPONSE`: `0.0` mantiene el objeto rígido; valores bajos
  como `0.05..0.12` dan volumen global sin rasterizar sus tiles.

ponytail: este primer parche cubre walls ya compuestos. Un tilemap GPU completo
solo tendría sentido después de validar esta ruta pequeña en los mapas reales.
