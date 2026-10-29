# Pokémon Vermeil — selector visual y Scene Director

## Estado de integración
- `Plugins/[LBDS_CUST] Scene Engine/004_VermeilTreatment.rb`: nuevo selector en el runtime, persistente por partida.
- `Plugins/[LBDS_CUST] Scene Engine/010_Intro.rb`: selección integrada antes del nombre y diálogos reescritos para no anticipar el tratamiento.
- `Plugins/MakerStudio/003_Editor/Mods/Scene Director Studio/model.js`: comando `treatment_input` y compilación Ruby.
- `importer.js`: reconocimiento del comando al importar Ruby.
- `editor.js`: inspector y atajos de navegación.
- `preview.js`: reloj común para tiempos en frames y previsualización interactiva.

## Maqueta (640 × 480)
- Barra de título: x=41..599, y=30..98.
- Retrato de medio cuerpo: área objetivo x=168..472, y=102..422.
- Flechas laterales: x≈83 / x≈557, y≈260.
- Indicaciones al pie: y=433..456.
- Orden de opciones: femenino, neutro, masculino; opción inicial neutro.

## Recursos pendientes
Copiar los PNG transparentes al juego en:
```
LA BASE DE SKY/Graphics/Scenes/Intro/GenderSelect/
  solen_femenino.png
  solen_neutro.png
  solen_masculino.png
```
La UI está separada del retrato. No usar capturas de la pantalla completa como sprites. Los tres PNG se entregan aparte y todavía deben revisarse visualmente; no están incluidos en este commit.

## Persistencia / uso
```ruby
VermeilTreatment.current
VermeilTreatment.text(
  masculino: "Está preparado.",
  femenino: "Está preparada.",
  neutro: "Ya puede continuar."
)
```

El tratamiento neutro omite tanto «elle» como terminaciones en «-e». La elección no altera el sprite ni `trainer_type`. Para un diálogo narrativo se puede usar `treatment_text(masculino: ..., femenino: ..., neutro: ..., speaker: ...)`.

## Verificación de juego pendiente
- Reproducir intro original ingame desde nueva partida.
- Confirmar funcionamiento de Input izquierdo/derecho y aceptación de pantalla.
- Verificar guardado/carga de la opción y las frases gramaticales.
- Comparar tiempos runtime/preview de fades, esperas y bucles Ruby.
- Revisar ajuste final de retratos a 640×480, sin recortes ni halos.
- Comprobar que la versión exportada desde Scene Director conserve bloques Ruby avanzados.
