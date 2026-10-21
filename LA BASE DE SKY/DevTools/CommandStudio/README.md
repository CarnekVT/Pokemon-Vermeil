# Command Studio v0.1.0 (prototipo)

Editor externo para proyectos RPG Maker XP / Pokémon Essentials 21.1. No se carga como plugin del juego.

## Iniciar

1. Instalar Python 3.9+ (con tkinter) y Ruby 3.x en Windows.
2. Ejecutar `Iniciar_Command_Studio.bat` desde esta carpeta.
3. Abrir como proyecto la carpeta `LA BASE DE SKY` (contiene `Data`).
4. Buscar comandos nativos en Enciclopedia, crear mensajes en Text Studio, usar Script Studio y asistentes para generar eventos.
5. Cerrar RPG Maker XP antes de guardar cambios en archivos `.rxdata`.

### Seguridad

Utilizar sobre una copia del proyecto. Se crean respaldos en `Data/CommandStudioBackups` antes de escribir mapas. No se han comprobado aún los mapas reales de Pokémon Vermeil ni los comandos ampliados de LA BASE DE SKY. No edita eventos comunes ni sustituye el editor oficial. Las funciones Ruby detectadas se indexan de manera aproximada, no se validan semánticamente.

## Verificación

`python -m py_compile command_studio.py catalog.py wizards.py`

`ruby -c rmxp_bridge.rb`

Los tests del paquete original se mantienen disponibles en el archivo descargable entregado con Command Studio; el software está en fase de prueba.
