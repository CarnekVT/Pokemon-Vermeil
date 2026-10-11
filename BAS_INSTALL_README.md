# Pokémon Vermeil · Battle Animation Studio v1.0.88
## ¿Qué hace este programa?
Battle Animation Studio es un **mod del editor Maker Studio** para crear y retocar animaciones de combate Pokémon sin editar directamente los parámetros Ruby/PBS. Incluye timeline con keyframes, gráficos, sonido, cámara y emitters/partículas (trayectoria, aparición, dispersión y vida).
## Contenido del paquete
- `LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/Battle Animation Studio/` → mod completo para la carpeta EDITOR de Maker Studio.
- `LA BASE DE SKY/Plugins/Battle Animation Studio Runtime/` → plugin Ruby del runtime del juego.
- En el mod hay además subcarpetas `runtime/` y `runtime_game/` correspondientes a sus puentes y compatibilidad; se conservan del proyecto.
## Instalación
1. Haz una COPIA del proyecto (incluidas animaciones y mods).
2. Copia únicamente las carpetas empaquetadas a la raíz de `LA BASE DE SKY` respetando rutas.
3. Se requiere una instalación compatible de Maker Studio con su editor base; **el editor core no se incluye**, porque no estaba versionado en la rama de recuperación.
4. Reinicia Maker Studio. Busca el mod Battle Animation Studio y prueba en una copia del proyecto antes de exportar nuevas animaciones.
## Control de emitters
En la vista RUTA usa clic izquierdo: punto central = origen, tirador AZUL = dirección, NARANJA = apertura, MORADO = área de nacimiento y BLANCO (FIN) = distancia. La pestaña Rápido expone estos cinco parámetros por número. La pestaña Técnico/PBS conserva controles avanzados.
## Ejemplo Gen 5
Sludge Bomb se reconstruyó con TRES clips: proyectil único usando PRAS- Sludge Bomb.png; impacto de burbujas violetas cerca del objetivo, y vapor morado breve al desaparecer. Se sincronizan los sonidos Sludge Bomb1 y Sludge Bomb2. Referencia de video: aprox. 56:24.5–56:28.5. El movimiento Sludge Wave aparece después y NO debe confundirse con Sludge Bomb. La previsualización aún requiere verificación dentro de Maker Studio y del juego.
## Origen y versión
Fuente: CarnekVT/Pokemon-Vermeil · rama de rescate de mods.
No sustituye al resto de mods del usuario.
