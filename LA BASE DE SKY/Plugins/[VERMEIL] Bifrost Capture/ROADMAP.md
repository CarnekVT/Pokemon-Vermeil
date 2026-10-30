# Bifröst Capture — seguimiento 0.9.0 (reconstrucción completa de código)

Actualizado 2026-10-30 · rama `feature/bifrost-overworld-capture-studio`.

**Estados:** «Integrado» significa código subido al repositorio y comprobado por pruebas aisladas, **no** funcionamiento confirmado dentro de mkxp. «Parcial» significa solución inicial sujeta a casos reales. «Pendiente» significa funcionalidad todavía por construir.

| Área | Estado | Verificación / siguiente tarea |
|---|---|---|
| Selección inmediata y bidireccional | Código integrado y tests | S y rueda cambian Ball o Team en ambos sentidos sin esperar |
| Cambio Ball/Team con W contextual | Código integrado y tests | W solo se usa dentro del apuntado; clic derecho como alternativa |
| Recordar Ball/Team/modo en guardado | Código integrado y tests | Persistencia en PokemonGlobalMetadata; Ball por ID, miembro por índice |
| HUD Team con icono y nombre | Código integrado; falta validación visual | Icono real de Pokémon, nombre, nivel, PS y transición rápida |
| Notificación lateral izquierda animada | Código integrado y tests | Entrada, hold, salida, cola y resultados diferenciados |
| Perfiles PLA-like y Z-A-like | Router implementado; assets opcionales | Hasta 12 eventos; reutiliza sonidos vanilla si faltan recursos autorizados |
| Migración de keybindings anteriores | Código integrado; falta probar Studio | Valores D/Q/Shift heredados se sustituyen en el editor con cambios pendientes de guardar |
| Interacción contextual C/X sin doble acción | Código integrado; tests | Protección del mapa incluso si Bifröst cierra antes del update de Scene_Map |
| Auditoría de inputs en Vermeil | Revisados los módulos relevantes | D Ready Menu, Q Turbo, Shift/Z carrera, F9 debug, flechas movimiento; falta prueba de terceros en mkxp |
| Tasa OW adicional separada | Código integrado; test automatizado | 12 % extra por paso en Vermeil, enfriamiento de 7 pasos, sin alterar batalla vanilla |
| Temperamentos neutro/miedoso/agresivo | Código integrado; tests de IA | Personalidad individual estable, huida, persecución y combate agresivo |
| HUD de temperamentos y objetivos | Código integrado; validar visuales | Retícula con pulso, tres colores, estados persigue y huye |
| Audio 009 y diez eventos | Código integrado; tests del router | Vanilla/original/muted, efectos autorizados en Audio/SE/Bifrost |
| Referencias Arceus, Z-A y Tetris 99 | Documentado | AUDIO_GUIDE.md; no se incluyen archivos comerciales |
| 001: Reglas, perfiles y catálogo desde cero | Integrado | Configuración global, mapa, especie y evento |
| 002: Resolución de impacto/captura desde cero | Integrado | Test de capturar y almacenar al OW creado |
| 003: Opciones dentro del juego desde cero | Integrado | Falta revisar menú en mkxp |
| 004: Integración de encuentros de hierba desde cero | Integrado | Test: tirada nativa crea OW válido |
| 005: Apuntado, HUD y lanzamiento desde cero | Parcial | Selector de tres Balls, imán de objetivo, estela y fallo visual coherente; validar con cámara 2.5D |
| 006: Huida/ataque visible desde cero | Integrado | Test de huida sin marca de captura |
| 008: apuntado y vuelo no bloqueantes | Código integrado y tests de input | Se camina con flechas mientras A prepara el lanzamiento |
| Origen del tiro estable mientras el jugador se desplaza | Código integrado y test | El contacto toma como origen la casilla al soltar A |
| Secuencia de captura en estados por fotograma | Código integrado; validar mkxp | Sin bucles manuales de Graphics/Input, reacción diferida |
| Traducciones con placeholders | Código corregido y test | Evita FrozenError al usar .dup con _INTL y placeholders |
| Cambio de mapa durante la captura | Código integrado; validar mkxp | Limpieza y prevención de Pokémon OW duplicado |
| 007: Notificaciones persistentes y captura animada | Código integrado; requiere prueba | Toast independiente con capturado/crítico/liberado/miss/escapó y equipo/caja; absorción y sacudidas |
| Almacenamiento sin mensajes modales | Código integrado; tests aislados | Inserta en equipo o caja y notifica sin abrir cuadro tradicional |
| Modo mantener/soltar en una sola acción | Código integrado; requiere prueba | A mantiene apuntado, soltar lanza; C sigue funcionando |
| Estela y desviación visual | Código integrado; requiere prueba | La misma tirada decide si la Ball se desvía y si el impacto falla |
| Maker Studio: nueva UI y lógica de edición | Integrado | Inspector ampliado con feedback, FX y control rápido; claves sincronizadas con runtime |
| Perfil exclusivo Bifröst | Integrado | Manuales limitados a catálogo |
| Perfil OW completo | Integrado | Generados naturales capturables aunque haya restricción heredada |
| Perfil mixto | Integrado | Por defecto 50 % de encuentros elegibles pasan a OW |
| Clásico | Integrado | No sustituye los encuentros de hierba |
| Ratón/teclado/mando y Toggle/Hold | Parcial | Revisar mapeo Input y mouse en mkxp |
| Distancia óptima 4, máximo 7, 8 falla | Integrado | Test de geometría |
| Captura por espalda y críticos | Integrado | Balance de probabilidades sin todos los efectos de Ball |
| Consumo de Ball correcto | Integrado | No gastar por puntería sin OW |
| Eventos OW decorativos | Integrado | No registrar sin etiqueta/llamada explícita |
| Especies/niveles/formas por mapa/especie | Integrado | Probabilidades y encuentros PBS |
| Generación de sprites Followers | Parcial | Se registran inmediatamente en el conjunto de eventos activos de Game_Map; falta prueba en mkxp. |
| Recursos faltantes / mapa sin espacio | Integrado | OW completo nunca inicia batalla normal; omite el spawn y comunica diagnóstico. Mixto conserva fallback clásico. |
| Gestión de objetos y sprites temporales | Integrado | Limpieza al escapar/capturar/transferir |
| Reacción a distancia y al fallar | Integrado | AI con escaneo espaciado |
| Captura y depósito en equipo/PC | Parcial | Ruta pbAddPokemon; probar en partida y guardado |
| Animación de trayectoria, giro, sombra | Parcial | No hay balística ni altura 3D física |
| Animación de absorción/captura y sacudidas | Parcial | Falta verificar ritmo/resultado |
| Audio y animación corporal del entrenador | Pendiente | Crear/reutilizar assets |
| Sincronización con legendarios errantes vanilla | Pendiente | Aparece/desaparece conforme a roaming global |
| Recursión Battle::Scene#pbFrameUpdate entre SleepAnimations y UmbraVeil | Código corregido; test aprobado | Reemplazado alias plano por prepend/super para evitar SystemStackError. |
| Compatibilidad con Visual 2.5D HD/Turbo/BSS/BAS | Pendiente | Prueba real de FPS/inputs y transiciones |
| Guardado/carga con OW activos | Pendiente | Simular transferencias/partidas reales |
| Tests automáticos de FPS y mapas completos | Pendiente | Requiere runner de juego/mkxp |

## Casos críticos al probar

1. Activar perfil `full_ow` desde Studio, **Aplicar perfil**, **Guardar**.
2. Entrar en hierba con tabla de encuentros: el resultado de una tirada natural se convierte en evento OW con sprite Followers.
3. Mantener A para apuntar. S o rueda cicla Ball/Team; W o clic derecho cambia modo. Soltar A o pulsar C lanza. Verificar equipo/caja.
4. Probar que un Pokémon generado sigue siendo capturable si el catálogo manual Bifröst está restringido.
5. A 3 casillas, reacción de huida. Comprobar movimiento por pasos y desaparición sin marca de captura.
6. Probar disparos a 4, 7 y 8 casillas; objetos sólidos intermedios y captura por espalda.
7. Repetir con Visual 2.5D HD, Turbo, combates BSS/BAS, transferencias y guardados.

## Referentes utilizados

- Videos del usuario: lanzamiento sobre mapa, sombra del proyectil, HUD pequeño, especies en movimiento, captura con notificación.
- ZIJUK Instant Capture System (ICS) para Pokémon Essentials 21.1: idea de estructura modular, selección rápida de Balls y controles Hold/Toggle. **No se incorporó el código externo ni la dependencia obligatoria VOWE**.

La rama sigue siendo una **implementación experimental**. Los resultados de GitHub Actions prueban la lógica aislada, no la experiencia visual en juego. El material de ZIJUK y los videos se han usado para definir la experiencia, sin integrar automáticamente su plugin.
