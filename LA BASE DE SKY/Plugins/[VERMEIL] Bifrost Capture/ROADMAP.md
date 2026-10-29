# Bifröst Capture — lista de seguimiento

Actualizada: 2026-10-29 · rama `feature/bifrost-overworld-capture-studio`.
**No es un listado de características probadas ingame**. Código integrado en GitHub no equivale a funcionamiento validado.

| Área / función | Estado | Observaciones |
|---|---|---|
| Plugin modular Essentials 21.1 | Código integrado; falta probar | Carpeta propia, meta, INI, lógica y runtime. |
| Perfil Bifröst predeterminado | Código integrado; falta probar | Restricción oficial de especies. |
| Perfiles Classic / Adventure / Safari / Custom | Código integrado; falta probar | Se configuran desde Maker Studio. |
| Acceso solo por evento (`access_mode=event`) | Código integrado; falta probar | Predeterminado Bifröst, `pbBifrostAim`. |
| Acceso siempre disponible (`access_mode=always`) | Código integrado; falta probar | Se abre con tecla en mapas jugables, incluso sin objetivo. |
| Acceso con objetivo cercano (`access_mode=nearby`) | Código integrado; falta probar | Comprueba área frontal y etiqueta de elegibilidad. |
| Atajo Aux2 R / Aux1 L / none | Código integrado; falta probar | Evitar colisiones con plugins y escenas. |
| Ajustar acceso/atajo ingame | Código integrado; falta probar | Menú por `pbBifrostRulesMenu`; preferencia por partida. |
| Editor de reglas Maker Studio | Código integrado; falta probar | Por global, mapa, especie y evento. |
| Zona de apuntado 7×7 frontal | Parcial | Cuadrícula UI funcional en código; no hay retícula 2.5D proyectada sobre mundo. |
| Cuarta casilla óptima, penalización a la lejanía | Código integrado; falta balancear | Fórmulas iniciales configurables. |
| Casilla octava sin impacto | Código integrado; falta probar | Solo zona inicial; otros perfiles pueden ampliar el alcance. |
| Bonificación por lanzar desde atrás | Código integrado; falta probar | En función de dirección del evento. |
| Mayor probabilidad de captura crítica por espalda | Código integrado; falta probar | Multiplicadores configurables. |
| Proximidad a tres casillas y reacción | Código integrado; falta probar | Reacción huir / atacar / ignorar. |
| Consumir Balls al fallar | Código integrado; falta probar | Configurable. |
| Seleccionar Poké Ball del bolso | Código integrado; falta probar | API de bolsillos de Pokémon Essentials usada. |
| Seleccionar Pokémon para comenzar combate OW | Parcial | Selección disponible, pero falta asegurar que el Pokémon elegido sea el enviado en combate. |
| Captura directa fuera de combate | Parcial | Falta validación de Pokédex, guardado, PC, formas e integración de animaciones. |
| Pokémon OW marcados como decorativos | Código integrado; falta probar | `[OWDECOR]`, exclusión de otros eventos sin `[OWCAP]`. |
| Permitir especies distintas a legendarios | Código integrado; falta probar | `restricted_species=0`; mantiene etiqueta explícita. |
| Combates originales en hierba alta | Conservado; falta regresión | No se modificaron los triggers originales. |
| Impact frame | Parcial | Flash básico configurable; falta sincronizar con choque y animación. |
| Trayectoria de Poké Ball y animaciones del jugador | Pendiente | Arco, vuelo, fallo, impactos, animación dinámica. |
| Retícula y proyectil fieles a perspectiva 2.5D | Pendiente | Coordenadas de eventos frente a coordenadas de pantalla. |
| Comportamiento natural del OW: visión, persecución, huida/movimiento | Pendiente | La reacción inicial es básica. |
| Respeto completo a obstáculos/colisiones | Parcial | Código comprueba eventos intermedios, falta geometría, paredes y alturas. |
| Captura con fórmula completa de Poké Balls | Parcial | Hay multiplicadores iniciales, no todos los efectos específicos. |
| Sincronización con roaming de Essentials | Pendiente | Estado, aparición, captura persistente y desaparición en mapas. |
| Legendarios con formas de Galar en combate OW | Parcial | Etiqueta de forma para captura; falta conservar forma al entrar en batalla. |
| Configuración de comportamiento individual por mapa/especie/evento | Código integrado; falta probar | INI y editor; verificar precedencias. |
| Pruebas reales con Turbo, Smooth Movement, BSS/BAS y Visual 2.5D | Pendiente | No se ha ejecutado el juego en esta sesión. |
| Tests de regresión automatizados | Pendiente | Escribir mocks para lógica de rango, captura y estados. |

## Recomendación de orden de trabajo

1. Arranque y estabilidad: carga del plugin + Maker Studio, atajos R/L, menús, apertura desde evento y apertura `always`.
2. Flujo de captura real: consumo de Balls, éxito/fallo, almacenamiento, Pokédex, formas regionales y guardar/cargar.
3. Integración de errantes: enlazar eventos OW con especies e individuos del sistema original de roaming.
4. Combate OW: enviar de verdad el Pokémon seleccionado, preservar formas y estados, confirmar reacción al entrar a 3 casillas.
5. Aspecto visual: animación del lanzador, trayectoria, impacto, retícula y profundidad 2.5D.
6. Validación con proyectos alternativos, mapas distintos, perfiles y opciones guardadas por partida.

## Ajuste incorporado en esta revisión

```ini
[global]
access_mode=event
hotkey=aux2
```

Cambiar `access_mode=always` permite abrir el apuntado sin evento de mapa, mediante R en el control original de Vermeil. `nearby` restringe el acceso a OWs válidos situados en el área frontal. La disponibilidad no implica que los Pokémon decorativos sean capturables. Para admitir otras especies, `restricted_species=0` + etiqueta `[OWCAP:ESPECIE:NIVEL]`.
