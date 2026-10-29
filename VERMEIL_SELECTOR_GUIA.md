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


## Corrección de velocidad, texto y versión Studio (29/10/2026)

- `mkxp.json` fija `fixedFramerate: 120`. Scene Engine ahora realiza pasos
  lógicos a 60 Hz: consume dos actualizaciones gráficas por paso cuando
  `Graphics.frame_rate` informa 120.
- Los mensajes de la intro usan explícitamente `speed: :slow`. Antes el
  narrador utilizaba `:slow` pero la guardiana y el Gran Espíritu heredaban
  `:normal`, el doble de caracteres por paso aproximadamente.
- Todos los `text_inline` de la intro carecen de saltos `\\n` forzados;
  el texto se ajusta por ancho y el paginador reequilibra la última página.
- El selector dibuja destellos, órbitas de partículas, pulso lateral,
  animación de entrada, balanceo del retrato y flash suave de confirmación.
- Studio importa y edita `treatment_input` y `treatment_text`, conserva
  los bloques Ruby y sincroniza los tiempos de texto de su preview.

### Actualizar una escena vieja del Studio sin duplicarla
1. Cierra y vuelve a abrir el juego / MakerStudio para cargar los plugins.
2. En Scene Director Studio, usa **Importar Ruby**, elige `010_Intro.rb`.
3. Si existe otra importación del mismo script y método, acepta **Actualizar
   escena desde Ruby**. Esto sustituye los comandos guardados en Studio de
   esa escena; se solicita confirmación antes.
4. Pulsa **Guardar** para regenerar `Data/SceneDirector/scenes.json`.
5. Reinicia la prueba. Comparar tanto la intro Ruby como la del menú
   Scene Director usando el mismo `mkxp.json`.

**Nota:** el `scenes.json` local no está versionado en esta rama. La nueva
versión del script fuente no modifica por sí sola escenas ya importadas.
Validar en ejecución real y revisar la compilación local; solo se han
verificado de forma estática/importación los archivos de la rama.
