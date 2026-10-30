# Environment Design Studio — v0.1.0

Modulo de planificacion de mapas de Pokemon Vermeil para Maker Studio, compatible con la API de mods 1.0.0.

- Se abre desde **Mods → Environment Design Studio** sobre un mapa abierto.
- Ficha contextual por mapa: geografia, clima, sociedad, arquitectura, historia, ecologia Pokemon, atmosfera, iluminacion, jugabilidad, narrativa y restricciones.
- Asistente **local determinista**: propuestas basadas en palabras clave de la ficha; no es un LLM ni certifica hechos.
- Buscador opcional: abre consultas dirigidas en Wikimedia Commons, Wikipedia, OpenStreetMap o imagenes web mediante la API **ctx.ui.openUrl** (requiere confirmacion del usuario). No hay scraping, conexion silenciosa, API key ni acceso automatico a resultados.
- Registra referencias como enlaces y anotaciones verificables por el autor.
- Guarda por mapa en Data/WorldDesign/Environment/map_XXXX.json. No modifica Data/MapXXX.rxdata ni los plugins de iluminacion/camara.
- **Map Design Studio** puede consultar la ficha y usarla como contexto de sus sugerencias.
- La escritura de JSON es explicita (boton Guardar). El cierre con modificaciones pregunta si se guardan.

## Limites de la version 0.1
No descarga imagenes, no conecta directamente con APIs de buscadores ni realiza inferencia generativa remota. No se ha ejecutado sobre la GUI real; verificar cargado de mod, lectura/escritura y dialogos de cierre en Maker Studio antes de usarlo en produccion.
