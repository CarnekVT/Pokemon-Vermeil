# Normal maps para Lighting Studio

Estas carpetas permiten asignar una textura de normales a un recurso original del juego:

- `Tilesets/` — tilesets completos (`Graphics/Tilesets`).
- `Autotiles/` — autotiles (`Graphics/Autotiles`).
- `Characters/` — sprites overworld/OWs (`Graphics/Characters`).

Ejemplo:

```
Graphics/Tilesets/Bosque.png
Graphics/LightingStudio/Normals/Tilesets/Bosque_n.png
Graphics/Characters/Hero.png
Graphics/LightingStudio/Normals/Characters/Hero_n.png
```

En el panel **Lighting Studio > Normal Maps** selecciona el original y después el PNG de normales con los selectores de Maker Studio. Para ajustar la convención, cada vínculo ofrece «Invertir Y» (canal verde).

**Requisitos de producción:** PNG con dimensiones, rejilla y fotogramas idénticos a la textura original; normales RGB en espacio tangente, por defecto orientadas en +Z (color neutro #8080FF aproximadamente). `invertY` guarda la convención para un shader posterior.

**Estado actual — experimental:** los vínculos se guardan y se verifican, pero el runtime RGSS/mkxp de Lighting Studio **todavía no aplica esos normal maps al sombreado**. Se necesita una etapa de integración con los sprites del mapa, sprites OW y renderizador/shader de materiales. No se simula ese comportamiento con per-pixel Ruby en cada fotograma para evitar nuevos picos de FPS.


## Resolución automática para jugador, Pokémon seguidor y formas

No registres manualmente cada especie ni agregues switches por Pokémon. Activa la **detección automática global** en Lighting Studio. El resolvedor toma el gráfico que el juego ya haya elegido y busca un PNG con el mismo nombre más `_n` dentro de la carpeta correspondiente. Se admiten subcarpetas, por ejemplo:

```
Graphics/Characters/Followers/VENUSAUR.png
Graphics/LightingStudio/Normals/Characters/Followers/VENUSAUR_n.png
```

Cambiar el Pokémon seguido hace que la siguiente consulta de recurso use el nuevo gráfico; la lista manual solo se usa para nombres excepcionales. Los resultados de existencia se cachean y pueden refrescarse con `LightingStudio.normal_reset_cache` o al cambiar de mapa.

**Límite:** la detección dinámica de rutas está lista, pero no hay aún renderizado de normales en pantalla ni shader conectado al sprite.
