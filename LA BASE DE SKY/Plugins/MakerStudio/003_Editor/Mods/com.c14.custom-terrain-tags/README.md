# Terrain Tag Creator for Maker Studio

---

# 🇪🇸 ESPAÑOL

**Terrain Tag Creator** es un mod para Maker Studio que te permite añadir, gestionar, importar y exportar *Terrain Tags* (Etiquetas de Terreno) personalizadas de forma visual y sencilla.

Por defecto, Pokémon Essentials y RPG Maker utilizan las tags del 0 al 17. Este mod te permite crear tags a partir de la 18 en adelante y asignarlas a tus tilesets directamente desde el editor.

## Características
* **Gestor Visual:** Interfaz integrada en Maker Studio para añadir, renombrar y borrar tags.
* **Autoincremento Inteligente:** Sugiere automáticamente el primer ID libre disponible.
* **Importar / Exportar:** Guarda tus tags en un archivo `.json` para compartirlas con tu equipo o usarlas en otros proyectos. Incluye resolución de conflictos si los IDs chocan.
* **Guardado por Proyecto:** Las tags se guardan en la carpeta de tu juego (`Plugins/MakerStudio/003_Editor/.custom_terraintags`), por lo que no interferirán con otros proyectos que tengas en tu PC.
* **Bilingüe:** La interfaz se adapta automáticamente al idioma de tu Maker Studio (Inglés o Español).

## Cómo usarlo en el Editor
1. En la barra superior de Maker Studio, ve a **Mods -> Gestionar Terrain Tags...**
2. Añade un ID (18 o superior) y un nombre (ej. `Lava`, `Hielo`, `Veneno`).
3. Ve a la pestaña de edición de **Tilesets**.
4. Selecciona el modo **Terrain Tags**.
5. ¡Tu nueva tag aparecerá en el menú desplegable lista para pintar sobre el mapa!

## Cómo usarlo en tu Juego (Ruby)
Este mod solo se encarga de la parte del editor (asignar la tag al tile). Para que la tag haga algo en tu juego, debes programar su efecto en los scripts (Ruby).

Por ejemplo, para comprobar si el jugador está pisando tu nueva tag (supongamos que es la ID 18):

```ruby
# Comprueba la tag del tile en la coordenada X, Y actual
if $game_map.terrain_tag($game_player.x, $game_player.y) == 18
  # Pon aquí tu código: hacer daño, resbalar, reproducir un sonido, etc.
  print "¡Estás pisando la tag 18!"
end
```

## Instalación
1. Descarga el archivo `.zip` desde la pestaña de **Releases**.
2. Extrae el contenido en la carpeta `Mods/TerrainTagCreator` dentro de la raíz de tu Maker Studio.
3. Abre Maker Studio, ve al **Mod Manager** y activa el mod.

---

# 🇬🇧 ENGLISH

**Terrain Tag Creator** is a mod for Maker Studio that allows you to easily add, manage, import, and export custom Terrain Tags visually.

By default, Pokémon Essentials and RPG Maker use tags from 0 to 17. This mod allows you to create tags from 18 onwards and assign them to your tilesets directly from the editor.

## Features
* **Visual Manager:** Built-in UI to add, rename, and delete tags.
* **Smart Auto-increment:** Automatically suggests the first available free ID.
* **Import / Export:** Save your tags to a `.json` file to share them with your team or use them in other projects. Includes conflict resolution for clashing IDs.
* **Per-Project Saving:** Tags are saved in your game's folder (`Plugins/MakerStudio/003_Editor/.custom_terraintags`), so they won't interfere with other projects on your PC.
* **Bilingual:** The interface automatically adapts to your Maker Studio language (English or Spanish).

## How to use in the Editor
1. In the Maker Studio top menu bar, go to **Mods -> Manage Terrain Tags...**
2. Add an ID (18 or higher) and a name (e.g., `Lava`, `Ice`, `Poison`).
3. Go to the **Tilesets** editing tab.
4. Select the **Terrain Tags** mode.
5. Your new tag will appear in the dropdown menu, ready to be painted on the map!

## How to use in your Game (Ruby)
This mod only handles the editor side (assigning the tag to the tile). For the tag to actually do something in your game, you must program its effect in your scripts (Ruby).

For example, to check if the player is stepping on your new tag (let's assume it's ID 18):

```ruby
# Checks the tag of the tile at the current X, Y coordinates
if $game_map.terrain_tag($game_player.x, $game_player.y) == 18
  # Put your code here: deal damage, slide, play a sound, etc.
  print "You are stepping on tag 18!"
end
```

## Installation
1. Download the `.zip` file from the **Releases** tab.
2. Extract the contents into the `Mods/TerrainTagCreator` folder inside your Maker Studio root directory.
3. Open Maker Studio, go to the **Mod Manager**, and enable the mod.
