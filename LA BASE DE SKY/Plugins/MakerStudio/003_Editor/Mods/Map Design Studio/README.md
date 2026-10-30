# Map Design Studio v0.1.0

Modulo no destructivo de planificacion espacial + constructor de regiones basico para Maker Studio (Mod API 1.0.0).

## Uso
1. Abre un mapa y accede a **Mods → Map Design Studio** o al menu contextual de un tile.
2. En **Zonas del mapa** crea anotaciones rectangulares de recorrido, intereses, habitats, interiores, narracion o actividad productiva. Se dibujan en el mapa con un overlay reversible y no afectan al juego.
3. En **Asistente contextual**, el sistema lee Data/WorldDesign/Environment/map_XXXX.json (si existe) y propone zonas ausentes con reglas locales. No usa IA generativa.
4. En **Constructor** elige coordenadas, capa y Tile ID existente (se puede muestrear una casilla del mapa), protege lo ya ocupado y aplica un rectangulo o contorno mediante map.batchWrite; Ctrl+Z usa el deshacer de Maker Studio.
5. En **Referencias** busca ejemplos de arquitectura o geografia mediante el navegador, y consulta enlaces guardados en Environment Design Studio.
6. Los planos de zonas se guardan en Data/WorldDesign/MapDesign/map_XXXX.json.

## Seguridad y limites
- No cambia scripts de Essentials, Animated Props, Visual 2.5D o Lighting Studio.
- No edita propiedades de prioridad, colisiones o autotiles: utiliza tiles que el proyecto ya tiene configurados. El constructor NO es aun un sistema de caminos auto-conectados ni Room Builder con tiles de esquinas especificos.
- Si se desmarca la proteccion de tiles ocupados, pide una confirmacion antes de aplicar.
- No importa resultados web automaticamente ni usa claves o solicitudes HTTP ocultas.
- En esta version la "pseudo-IA" es un motor de sugerencias por reglas y ausencia de tipos de zona.
- **Sin prueba en GUI real**: verificar apertura, menu contextual, overlay con zoom, escritura por lotes, deshacer y guardado por mapa. No declarar release estable antes de las pruebas.
