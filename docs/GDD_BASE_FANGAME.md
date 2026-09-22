# GDD Base — Fangame de Pokémon

> Plantilla base para documentar fangames construidos sobre Pokémon Essentials / La Base de Sky.
>
> **Principio:** este documento no redefine Pokémon. Todo sistema estándar de Pokémon se considera **heredado** mientras el proyecto no indique explícitamente una modificación. El GDD documenta las decisiones propias del fangame, especialmente las diferencias, adiciones, reemplazos y sistemas nuevos.

---

## 0. Cómo usar esta plantilla

### Regla principal

No documentar como diseño propio aquello que ya forma parte de Pokémon estándar.

Ejemplos de elementos que, por defecto, se consideran heredados:

- Combate por turnos estándar.
- Tipos, efectividades y estados estándar.
- Pokémon, movimientos, habilidades y estadísticas estándar.
- Captura y obtención de Pokémon.
- Experiencia y subida de nivel.
- Evolución estándar.
- Equipo / party.
- PC / almacenamiento.
- Mochila e inventario.
- Tiendas y economía básica.
- Entrenadores y combates convencionales.
- Centros Pokémon y funciones equivalentes.
- Menús y pantallas estándar.
- Exploración mediante mapas y eventos.
- Guardado de partida.

**Solo documentar estos elementos cuando el fangame los modifique, sustituya o dependa de ellos de una manera especial.**

### Estados de cada decisión

- [PROPUESTA] — idea todavía no aprobada.
- [DECIDIDO] — decisión de diseño establecida.
- [EN PRUEBA] — implementada o prototipada, pero todavía evaluándose.
- [IMPLEMENTADO] — funciona en el juego.
- [DESCARTADO] — idea abandonada.
- [HEREDADO] — comportamiento estándar del motor / Pokémon que no necesita rediseño.

---

# 1. Identidad del proyecto

| Campo | Información |
|---|---|
| Nombre | [Nombre del fangame] |
| Subtítulo | [Opcional] |
| Autor / equipo | [Nombre] |
| Motor / base | [Pokémon Essentials + versión / Base de Sky] |
| Género | [RPG / aventura / etc.] |
| Plataforma | [Windows / Linux / etc.] |
| Estado | [Preproducción / producción / beta / etc.] |
| Versión del GDD | [0.1] |
| Última actualización | [Fecha] |

### Descripción en una frase

[El juego es...]

### Descripción corta

[1–2 párrafos que expliquen qué es el juego y qué lo diferencia.]

### Diferenciador principal

[¿Qué hace que este fangame exista en lugar de ser simplemente otra aventura Pokémon?]

---

# 2. Visión del juego

## 2.1 Fantasía del jugador

¿Qué experiencia queremos que el jugador sienta que está viviendo?

[Ejemplo: explorar una región aislada donde la actividad industrial está transformando progresivamente el ecosistema.]

## 2.2 Pilares de diseño

Definir entre 3 y 6 pilares.

### Pilar 1 — [Nombre]

[Qué significa y cómo afecta al diseño.]

### Pilar 2 — [Nombre]

[...]

### Pilar 3 — [Nombre]

[...]

### Pilar 4 — [Nombre]

[...]

## 2.3 Experiencia objetivo

El jugador debería sentir:

- [Emoción / sensación]
- [Emoción / sensación]
- [Emoción / sensación]

El jugador **no** debería sentir:

- [Sensación no deseada]
- [Sensación no deseada]

---

# 3. Público y alcance

## 3.1 Público objetivo

[Tipo de jugador al que se dirige.]

## 3.2 Público secundario

[Opcional.]

## 3.3 Duración objetivo

| Contenido | Objetivo |
|---|---|
| Historia principal | [X horas] |
| Compleción adicional | [X horas] |
| Postgame | [X horas] |
| Compleción total | [X horas] |

## 3.4 Alcance

### Incluido

- [Contenido]
- [Contenido]
- [Contenido]

### Fuera de alcance

- [Contenido deliberadamente excluido]
- [Contenido deliberadamente excluido]

---

# 4. Sistemas heredados vs. sistemas propios

Esta sección evita llenar el GDD con información que Pokémon ya define.

## 4.1 Sistemas heredados

Marcar los sistemas que permanecen esencialmente estándar:

| Sistema | Estado | Notas |
|---|---|---|
| Combate estándar | [HEREDADO] | |
| Captura | [HEREDADO] | |
| Party | [HEREDADO] | |
| PC | [HEREDADO] | |
| Evolución | [HEREDADO] | |
| Experiencia | [HEREDADO] | |
| Inventario | [HEREDADO] | |
| Tiendas | [HEREDADO] | |
| Guardado | [HEREDADO] | |
| Exploración | [HEREDADO] | |

## 4.2 Sistemas modificados

Solo registrar lo que cambia.

### [Nombre del sistema]

**Base heredada:** [Qué comportamiento estándar conserva.]

**Cambio:** [Qué cambia.]

**Motivo:** [Por qué.]

**Impacto en el jugador:** [Cómo cambia la experiencia.]

**Dependencias:** [Otros sistemas afectados.]

**Estado:** [DECIDIDO / EN PRUEBA / IMPLEMENTADO]

## 4.3 Sistemas nuevos

### [Nombre del sistema]

**Objetivo:** [Qué problema o necesidad resuelve.]

**Descripción:** [Cómo funciona a nivel de diseño.]

**Reglas:** [Reglas que el jugador debe conocer.]

**Recursos implicados:** [Items / variables / tiempo / dinero / etc.]

**Interacciones:** [Qué otros sistemas utiliza.]

**Estado:** [PROPUESTA / DECIDIDO / etc.]

---

# 5. Bucle de juego

## 5.1 Bucle principal

[Acción] → [Acción] → [Acción] → [Recompensa / consecuencia] → repetir

## 5.2 Bucle de exploración

[Explorar] → [Descubrir] → [Resolver / combatir] → [Recompensa]

## 5.3 Bucle de combate

Por defecto se considera heredado de Pokémon.

**Solo completar si el fangame modifica el combate.**

[Preparación] → [Decisión] → [Resolución] → [Consecuencia]

## 5.4 Bucle de progresión

[Actividad] → [Progreso] → [Desbloqueo] → [Nueva posibilidad]

---

# 6. Estructura de la aventura

## 6.1 Progresión general

[Inicio] → [Zona / objetivo] → [Evento] → [Zona / objetivo] → ...

## 6.2 Capítulos / actos

### Acto 1 — [Nombre]

**Objetivo:** [ ]

**Conflicto:** [ ]

**Desbloqueos:** [ ]

**Clímax:** [ ]

### Acto 2 — [Nombre]

**Objetivo:** [ ]

**Conflicto:** [ ]

**Desbloqueos:** [ ]

**Clímax:** [ ]

### Acto 3 — [Nombre]

**Objetivo:** [ ]

**Conflicto:** [ ]

**Desbloqueos:** [ ]

**Clímax:** [ ]

---

# 7. Mundo y región

## 7.1 Concepto del mundo

[Descripción general de la región / mundo.]

## 7.2 Reglas del mundo

- [Regla]
- [Regla]
- [Regla]

## 7.3 Regiones y zonas

| Zona | Función | Identidad | Acceso | Estado |
|---|---|---|---|---|
| [Zona] | [Función narrativa/gameplay] | [Tema] | [Cómo se llega] | [Estado] |

## 7.4 Ciudades y asentamientos

Para cada asentamiento:

### [Nombre]

**Concepto:** [ ]

**Tema visual:** [ ]

**Función narrativa:** [ ]

**Servicios:** [ ]

**Puntos de interés:** [ ]

**Personajes importantes:** [ ]

**Conexiones:** [ ]

---

# 8. Diseño de mapas y exploración

## 8.1 Filosofía de exploración

[Qué queremos que el jugador haga mientras recorre el mundo.]

## 8.2 Estructura de mapas

Definir:

- Escala.
- Densidad de eventos.
- Caminos principales.
- Rutas alternativas.
- Atajos.
- Secretos.
- Puntos de interés.
- Áreas opcionales.
- Backtracking.
- Cambios de estado del mundo.

## 8.3 Interacción ambiental

[Qué elementos del escenario pueden interactuar con el jugador.]

## 8.4 Obstáculos y acceso

Por defecto se utilizan las convenciones de exploración de Pokémon.

Documentar solamente:

- Nuevos tipos de obstáculos.
- Nuevas herramientas.
- Nuevas reglas de acceso.
- Cambios en HM/MO o equivalentes.
- Sistemas de traversal nuevos.

---

# 9. Historia

## 9.1 Premisa

[Qué ocurre antes de que comience el juego.]

## 9.2 Conflicto principal

[Qué problema mueve la historia.]

## 9.3 Objetivo del jugador

[Qué intenta conseguir el jugador.]

## 9.4 Tema

[Tema central.]

## 9.5 Tono

[Aventura / misterio / oscuro / cómico / etc.]

## 9.6 Estructura narrativa

[Resumen de principio → desarrollo → clímax → final.]

## 9.7 Finales

| Final | Condición | Consecuencia |
|---|---|---|
| [Final] | [Condición] | [Resultado] |

---

# 10. Personajes

## 10.1 Protagonista

**Concepto:** [ ]

**Motivación:** [ ]

**Personalidad:** [ ]

**Arco:** [ ]

**Relación con el mundo:** [ ]

## 10.2 Rivales / aliados

Para cada personaje:

### [Nombre]

**Rol:** [ ]

**Motivación:** [ ]

**Personalidad:** [ ]

**Relación con el protagonista:** [ ]

**Arco:** [ ]

**Apariciones:** [ ]

## 10.3 Antagonismo

[Quién o qué se opone al jugador y por qué.]

---

# 11. Pokémon y contenido de criaturas

## 11.1 Filosofía

La existencia y funcionamiento general de Pokémon se hereda del juego base.

Documentar solamente:

- Nuevas especies.
- Formas regionales.
- Formas alternativas.
- Evoluciones nuevas.
- Evoluciones modificadas.
- Tipos modificados.
- Habilidades nuevas o modificadas.
- Movimientos nuevos o modificados.
- Métodos de evolución nuevos.
- Sistemas de transformación.
- Cambios de disponibilidad.
- Cambios de balance deliberados.

## 11.2 Tabla de contenido nuevo / modificado

| Pokémon / contenido | Tipo de cambio | Descripción | Motivo | Estado |
|---|---|---|---|---|
| [Nombre] | [Nuevo / forma / balance] | [ ] | [ ] | [ ] |

## 11.3 Formas especiales

### [Nombre de la forma]

**Método de acceso:** [ ]

**Cambios visuales:** [ ]

**Cambios mecánicos:** [ ]

**Duración / condiciones:** [ ]

**Disponibilidad:** [ ]

---

# 12. Combate

> **Regla:** si el combate no cambia, esta sección puede reducirse a una sola línea:
> **“El combate utiliza las reglas estándar de Pokémon Essentials.”**

## 12.1 Cambios al sistema de combate

### [Sistema / mecánica]

**Qué cambia:** [ ]

**Regla:** [ ]

**Motivación de diseño:** [ ]

**Interacciones:** [ ]

**Casos especiales:** [ ]

## 12.2 Nueva mecánica de combate

Completar únicamente cuando exista una mecánica realmente nueva.

**Nombre:** [ ]

**Objetivo:** [ ]

**Input del jugador:** [ ]

**Estado del combate afectado:** [ ]

**Reglas:** [ ]

**Coste / riesgo:** [ ]

**Recompensa:** [ ]

**Contraestrategias:** [ ]

**Ejemplo de turno:** [ ]

## 12.3 Jefes y encuentros especiales

### [Jefe / encuentro]

**Contexto:** [ ]

**Composición:** [ ]

**Regla especial:** [ ]

**Objetivo de diseño:** [ ]

**Diferencia respecto a un combate estándar:** [ ]

---

# 13. Progresión del jugador

## 13.1 Progresión permanente

- [Nivel / medallas / historia / etc.]
- [Sistema propio]
- [Sistema propio]

## 13.2 Desbloqueos

| Desbloqueo | Requisito | Qué permite |
|---|---|---|
| [ ] | [ ] | [ ] |

## 13.3 Curva de dificultad

[Descripción de cómo aumenta la dificultad.]

## 13.4 Curva de poder

[Cómo crece el poder del jugador y qué limita esa progresión.]

---

# 14. Economía

Los sistemas económicos estándar se consideran heredados salvo modificación.

## 14.1 Moneda

[Moneda estándar / nueva moneda.]

## 14.2 Fuentes

- [ ]
- [ ]

## 14.3 Sumideros

- [ ]
- [ ]

## 14.4 Recompensas

[Qué obtiene el jugador y por qué.]

---

# 15. Objetos y recursos

## 15.1 Objetos estándar

[HEREDADO salvo modificaciones.]

## 15.2 Objetos nuevos

| Objeto | Función | Obtención | Restricciones |
|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] |

## 15.3 Recursos especiales

### [Recurso]

**Obtención:** [ ]

**Uso:** [ ]

**Límite:** [ ]

**Regeneración:** [ ]

---

# 16. NPCs y diseño de encuentros

## 16.1 Filosofía de NPCs

[Qué función cumplen los NPCs.]

## 16.2 NPCs funcionales

| NPC | Función | Ubicación | Estado |
|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] |

## 16.3 NPCs narrativos

[Personajes que desarrollan mundo, historia o relaciones.]

## 16.4 Encuentros dinámicos

[Eventos que cambian según progreso, decisiones, hora, clima, etc.]

---

# 17. Misiones y contenido secundario

## 17.1 Misiones principales

[Las misiones que hacen avanzar la historia.]

## 17.2 Misiones secundarias

### [Misión]

**Inicio:** [ ]

**Objetivo:** [ ]

**Pasos:** [ ]

**Recompensa:** [ ]

**Consecuencia:** [ ]

**Estado:** [ ]

## 17.3 Coleccionables

| Coleccionable | Cantidad | Función | Recompensa |
|---|---:|---|---|
| [ ] | [ ] | [ ] | [ ] |

---

# 18. UI y UX

## 18.1 Principios

- [Legibilidad]
- [Velocidad]
- [Jerarquía]
- [Consistencia]
- [Feedback]

## 18.2 Interfaces modificadas

Documentar solamente las pantallas que cambien respecto al comportamiento estándar.

### [Pantalla]

**Objetivo:** [ ]

**Información mostrada:** [ ]

**Controles:** [ ]

**Flujo:** [ ]

**Cambios respecto al estándar:** [ ]

## 18.3 Nuevas interfaces

[Descripción de cada UI nueva.]

---

# 19. Dirección artística

## 19.1 Identidad visual

[Descripción.]

## 19.2 Referencias

| Referencia | Qué se toma | Qué NO se toma |
|---|---|---|
| [Juego / película / arte] | [ ] | [ ] |

## 19.3 Personajes

[Estilo, proporciones, poses, expresividad.]

## 19.4 Pokémon

[Cómo se integran los diseños propios con Pokémon existente.]

## 19.5 Entornos

[Arquitectura, naturaleza, iluminación, materiales.]

## 19.6 Cámara

[Perspectiva, zoom, movimiento, reglas especiales.]

---

# 20. Audio

## 20.1 Dirección musical

[ ]

## 20.2 Música

| Contexto | Tema / función | Estado |
|---|---|---|
| [Zona] | [ ] | [ ] |

## 20.3 SFX

[Sonidos nuevos o modificados.]

## 20.4 Voz

[Si aplica.]

---

# 21. Contenido y producción

## 21.1 Lista de contenido

| Categoría | Objetivo | Actual | Estado |
|---|---:|---:|---|
| Mapas | [ ] | [ ] | [ ] |
| NPCs | [ ] | [ ] | [ ] |
| Pokémon nuevos | [ ] | [ ] | [ ] |
| Formas | [ ] | [ ] | [ ] |
| Movimientos | [ ] | [ ] | [ ] |
| Habilidades | [ ] | [ ] | [ ] |
| Objetos | [ ] | [ ] | [ ] |
| Música | [ ] | [ ] | [ ] |
| UI | [ ] | [ ] | [ ] |

## 21.2 Dependencias críticas

[Sistema que debe existir antes de implementar otro.]

---

# 22. Requisitos técnicos

Esta sección no describe diseño de gameplay; registra las condiciones necesarias para que el diseño sea implementable.

## 22.1 Motor

[Versión.]

## 22.2 Plugins / sistemas externos

| Sistema | Dependencia | Función | Crítico |
|---|---|---|---|
| [ ] | [ ] | [ ] | [Sí/No] |

## 22.3 Sistemas personalizados

[Descripción breve.]

## 22.4 Restricciones técnicas conocidas

- [ ]
- [ ]
- [ ]

---

# 23. Guardado, persistencia y estado del mundo

## 23.1 Datos persistentes

[Qué decisiones / eventos sobreviven al cambio de mapa o carga.]

## 23.2 Estados del mundo

| Estado | Activación | Efectos |
|---|---|---|
| [ ] | [ ] | [ ] |

## 23.3 Compatibilidad con partidas

[Qué ocurre si se actualiza el juego durante una partida.]

---

# 24. Accesibilidad y calidad de vida

Documentar las decisiones propias del proyecto.

- Tamaño de texto: [ ]
- Velocidad de texto: [ ]
- Contraste: [ ]
- Reasignación de controles: [ ]
- Opciones de combate: [ ]
- Opciones de dificultad: [ ]
- Indicadores visuales: [ ]
- Feedback sonoro: [ ]
- Reducción de efectos: [ ]

---

# 25. Localización

## Idiomas objetivo

- [Idioma]
- [Idioma]

## Consideraciones

[Texto dinámico, nombres, género, caracteres especiales, expansión de UI, etc.]

---

# 26. Testing y balance

## 26.1 Criterios de aceptación

Una mecánica se considera terminada cuando:

- [ ]
- [ ]
- [ ]

## 26.2 Pruebas de gameplay

| Sistema | Caso | Resultado esperado | Estado |
|---|---|---|---|
| [ ] | [ ] | [ ] | [ ] |

## 26.3 Balance

Registrar aquí decisiones cuantitativas que necesiten iteración.

| Elemento | Valor inicial | Valor actual | Motivo |
|---|---:|---:|---|
| [ ] | [ ] | [ ] | [ ] |

---

# 27. Riesgos de diseño

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| [ ] | [Baja/Media/Alta] | [Bajo/Medio/Alto] | [ ] |

---

# 28. Decisiones abiertas

No dejar ideas ambiguas mezcladas con decisiones definitivas.

| ID | Decisión pendiente | Opciones | Próximo paso | Estado |
|---|---|---|---|---|
| D-001 | [ ] | [ ] | [ ] | [PROPUESTA] |

---

# 29. Registro de cambios de diseño

| Versión | Fecha | Cambio | Motivo |
|---|---|---|---|
| [0.1] | [ ] | [ ] | [ ] |

---

# 30. Referencias y fuentes de diseño

## Juegos de referencia

- [Juego] — [qué se estudia]
- [Juego] — [qué se estudia]

## Referencias visuales

- [ ]

## Referencias narrativas

- [ ]

## Referencias técnicas

- [ ]

---

# 31. Apéndice — Ficha rápida de una nueva mecánica

Usar esta ficha cada vez que el proyecto añada una mecánica que Pokémon no tenga o modifique de forma significativa una existente.

## [Nombre de la mecánica]

**Estado:** [PROPUESTA / DECIDIDO / EN PRUEBA / IMPLEMENTADO]

**Tipo:** [Nuevo / Modificación / Reemplazo]

**Problema que resuelve:** [ ]

**Objetivo de diseño:** [ ]

**Descripción para el jugador:** [ ]

**Cómo funciona:** [ ]

**Input:** [ ]

**Reglas:** [ ]

**Coste:** [ ]

**Riesgo:** [ ]

**Recompensa:** [ ]

**Frecuencia de uso:** [ ]

**Interacción con sistemas Pokémon existentes:** [ ]

**Casos límite:** [ ]

**Feedback visual:** [ ]

**Feedback sonoro:** [ ]

**Tutorial / explicación:** [ ]

**Dependencias técnicas:** [ ]

**Criterio de éxito:** [ ]

---

# 32. Apéndice — Ficha rápida de una zona

## [Nombre de zona]

**Tipo:** [Ciudad / ruta / mazmorra / área especial]

**Función:** [Narrativa / exploración / combate / tutorial / etc.]

**Tema:** [ ]

**Sensación:** [ ]

**Entrada:** [ ]

**Salida:** [ ]

**Puntos de interés:** [ ]

**Encuentros:** [ ]

**NPCs:** [ ]

**Objetos:** [ ]

**Secretos:** [ ]

**Eventos:** [ ]

**Desbloqueos:** [ ]

**Conexiones:** [ ]

**Estado:** [ ]

---

# 33. Apéndice — Ficha rápida de un personaje

## [Nombre]

**Rol:** [ ]

**Edad:** [ ]

**Personalidad:** [ ]

**Motivación:** [ ]

**Objetivo:** [ ]

**Conflicto:** [ ]

**Relación con protagonista:** [ ]

**Arco:** [ ]

**Diseño visual:** [ ]

**Equipo Pokémon:** [ ]

**Apariciones:** [ ]

**Estado:** [ ]

---

# Principio final

> **El GDD no existe para explicar Pokémon. Existe para explicar el fangame.**

Si una regla pertenece al Pokémon estándar y el proyecto no la cambia, se referencia como **heredada**.

Si el proyecto la cambia, se documenta **la diferencia**.

Si el proyecto crea algo que Pokémon no tiene, se documenta **el sistema completo**.

Esto mantiene el documento útil, evita duplicar documentación del motor y permite que la plantilla pueda reutilizarse como punto de partida para múltiples fangames.
