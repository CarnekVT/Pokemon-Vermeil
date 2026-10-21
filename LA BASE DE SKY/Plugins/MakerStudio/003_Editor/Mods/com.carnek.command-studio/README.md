# Command Studio — Maker Studio (v0.2.0)

Este **mod web de Maker Studio** es diferente del programa externo en `DevTools/CommandStudio`.

## Abrir
- Ejecuta Maker Studio desde el proyecto.
- En **Mods → Command Studio**, abre el panel. También está en **Tools → Command Studio** cuando el host admite ese menú.
- Si Maker Studio ya estaba abierto, reinícialo para detectar el nuevo mod.

## Funciones
- Catálogo completo de códigos de evento de RPG Maker XP (incluye códigos estructurales y de continuación).
- Asistentes para texto, comentario, script Ruby, condiciones, interruptores, variables, transferencias, imágenes, audio y otros comandos comunes.
- Presets editables de Essentials 21.1.
- Explorador bajo demanda de métodos `.rb` en `Plugins` del proyecto.
- Exportación de código Ruby/texto para pegar en un evento, o JSON de `EventCommand` para herramientas externas.

**Limitación importante:** este panel NO inserta automáticamente eventos en `.rxdata` ni modifica eventos en el editor gráfico de Maker Studio. Su botón Copiar texto/script genera código compatible con los cuadros del editor RMXP; el JSON no se pega como script. Para editar mapas directamente se mantiene el editor externo anterior.

Las funciones de Essentials y los plugins pueden variar en LA BASE DE SKY: revisa cada firma antes de usarla. No escribe archivos del proyecto.

## Desarrollo
El mod usa el SDK de Maker Studio (`ctx.ui.registerPanel`, `ctx.menu.registerMenuItem`, `ctx.fs.listProjectDir`, `ctx.fs.readProjectFile`) y no necesita Ruby ni Python para mostrarse.
