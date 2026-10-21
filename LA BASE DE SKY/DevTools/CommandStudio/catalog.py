"""RPG Maker XP native event-command catalog plus Pokémon Essentials presets.
Every native opcode is addressable, including auxiliary/continuation commands.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class Command:
    code: int
    title: str
    category: str
    aliases: str = ''
    note: str = ''

# Based on RGSS1/RPG Maker XP event command codes. Including structural and
# editor-internal continuations enables accurate display and searching.
DATA = {
 'Mensajes y entrada': [
  (101,'Mostrar texto','mensaje diálogo hablar texto'),(401,'Continuar texto','continuación mensaje'),
  (102,'Mostrar elecciones','opciones elegir respuestas'),(402,'Rama de elección','opción rama'),
  (403,'Cancelar elección','cancelar opciones'),(404,'Fin de elecciones','cerrar opciones'),
  (103,'Introducir número','entrada numérica'),(104,'Opciones de texto','ventana posición'),
  (105,'Entrada de botón','detectar tecla botón'),
  (108,'Comentario','nota documentar evento'),(408,'Continuar comentario','continuación nota')],
 'Flujo y lógica': [
  (106,'Esperar','pausa frames fotogramas'),(111,'Condición','if cuando script variable interruptor'),
  (411,'Si no (Else)','else alternativa'),(412,'Fin de condición','fin if'),
  (112,'Bucle','loop repetir'),(413,'Fin de bucle','repeat above'),(113,'Romper bucle','break'),
  (115,'Terminar evento','exit'),(116,'Borrar evento temporalmente','erase'),
  (117,'Llamar evento común','common event'),(118,'Etiqueta','label'),(119,'Ir a etiqueta','jump label')],
 'Interruptores y variables': [
  (121,'Controlar interruptores','switch on off'),(122,'Controlar variables','variable sumar restar'),
  (123,'Interruptor local','self switch A B C D'),(124,'Temporizador','timer'),
  (125,'Cambiar dinero','oro gold'),(126,'Cambiar objetos','items inventario'),
  (127,'Cambiar armas','armas'),(128,'Cambiar armaduras','armaduras'),
  (129,'Cambiar grupo','party personajes'),
  (131,'Cambiar apariencia de ventana','windowskin'),(132,'Cambiar BGM de batalla','battle music'),
  (133,'Cambiar ME al terminar batalla','battle ending me'),
  (134,'Permitir guardar','save access'),(135,'Permitir menú','menu access'),
  (136,'Permitir encuentros','random encounters')],
 'Mapa y movimiento': [
  (201,'Transferir jugador','teleport mapa coordenadas'),(202,'Cambiar ubicación de evento','event move location'),
  (203,'Desplazar mapa','scroll mapa'),(204,'Configuración de mapa','panorama niebla fondo batalla'),
  (205,'Tono de niebla','fog tone'),(206,'Opacidad de niebla','fog opacity'),
  (207,'Mostrar animación','animation'),(208,'Transparencia del jugador','transparent'),
  (209,'Establecer ruta de movimiento','movement ruta'),(509,'Continuación de movimiento','move route continuation'),
  (210,'Esperar fin de movimiento','wait movement'),
 ],
 'Pantalla y gráficos': [
  (221,'Preparar transición','transition prepare'),(222,'Ejecutar transición','transition'),
  (223,'Cambiar tono de pantalla','screen tone color noche'),(224,'Destello de pantalla','flash'),
  (225,'Sacudir pantalla','shake'),(231,'Mostrar imagen','picture show'),
  (232,'Mover imagen','picture move'),(233,'Girar imagen','picture rotate'),
  (234,'Cambiar tono de imagen','picture color'),(235,'Borrar imagen','picture erase'),
  (236,'Efectos climáticos','weather lluvia nieve')],
 'Audio': [
  (241,'Reproducir BGM','musica música'),(242,'Desvanecer BGM','fade music'),
  (245,'Reproducir BGS','ambiente sonido'),(246,'Desvanecer BGS','ambiente fade'),
  (247,'Guardar BGM/BGS','memorize audio'),(248,'Restaurar BGM/BGS','restore audio'),
  (249,'Reproducir ME','efecto musical'),(250,'Reproducir SE','sonido efecto'),
  (251,'Detener SE','stop sound')],
 'Batalla / Base de datos XP': [
  (301,'Procesar batalla','battle'),(601,'Rama victoria','if win'),
  (602,'Rama huida','escape'),(603,'Rama derrota','lose'),(604,'Fin de batalla','battle end'),
  (302,'Abrir tienda','shop'),(605,'Continuar mercancía','shop continuation'),
  (303,'Introducir nombre','name input'),(311,'Cambiar HP','health'),
  (312,'Cambiar SP','mana'),(313,'Cambiar estado','state'),(314,'Recuperar todo','heal'),
  (315,'Cambiar EXP','experience'),(316,'Cambiar nivel','level'),
  (317,'Cambiar parámetros','stats'),(318,'Cambiar habilidades','skill'),
  (319,'Cambiar equipo','equipment'),(320,'Cambiar nombre del actor','actor name'),
  (321,'Cambiar clase de actor','class'),(322,'Cambiar gráfico del actor','sprite'),
  (331,'Cambiar HP del enemigo','enemy hp'),(332,'Cambiar SP del enemigo','enemy sp'),
  (333,'Cambiar estado enemigo','enemy state'),(334,'Curar enemigo','heal enemy'),
  (335,'Aparecer enemigo','appear enemy'),(336,'Transformar enemigo','transform'),
  (337,'Animación de batalla','battle animation'),(338,'Infligir daño','damage'),
  (339,'Forzar acción','force action'),(340,'Cancelar batalla','abort battle'),
  (351,'Menú','menu'),(352,'Guardar juego','save'),(353,'Game Over','game over'),
  (354,'Volver al título','title')],
 'Ruby / interno': [
  (355,'Ejecutar script Ruby','script rgss código'),(655,'Continuación de script','script multilinea'),
  (0,'Final / marcador estructural','end')]
}

COMMANDS = [Command(code, title, cat, tags) for cat, items in DATA.items() for code,title,tags in items]
BY_CODE = {c.code:c for c in COMMANDS}
INTERNAL = {0,401,402,403,404,408,411,412,413,509,601,602,603,604,605,655}

# Generator recipes. All other opcodes remain accessible through the advanced
# editor, with parameter structures inferred from existing project examples.
ESSENTIALS = [
 ('Curar equipo','Equipo','pbHealAll','Cura todo el equipo del jugador.'),
 ('Dar Pokémon','Pokémon','pbAddPokemon(:RIOLU, 5)','Añade un Pokémon al equipo o almacenamiento.'),
 ('Dar objeto','Objetos','pbReceiveItem(:POTION, 1)','Entrega un objeto al jugador.'),
 ('Quitar objeto','Objetos','pbTakeItem(:POTION, 1)','Retira objetos, según disponibilidad.'),
 ('Combate salvaje','Combates','WildBattle.start(:PIKACHU, 5)','Comienza un combate salvaje.'),
 ('Combate entrenador','Combates','TrainerBattle.start(:YOUNGSTER, "Luis")','Inicia combate con un entrenador existente.'),
 ('Mensaje','Textos','pbMessage(_INTL("¡Hola!"))','Muestra un mensaje con Essentials.'),
 ('Interruptor local','Eventos','pbSetSelfSwitch(@event_id, "A", true)','Configura un interruptor local.'),
 ('Obtener nombre jugador','Datos','$player.name','Expresión con el nombre del jugador.'),
 ('Obtener cantidad equipo','Datos','$player.party.length','Cuenta Pokémon en el equipo.'),
]

# For protected structure markers, an insertion must be created as an entire
# coherent block, never as a loose branch tail.
STRUCTURAL = {102,111,112,301} | INTERNAL

# Canonical examples for parameter JSON. XP-based data only; functions may be
# overridden by Essentials' event interpreter in specific projects.
DEFAULT_PARAMS = {
 103:[1,2],104:[0,0],105:[1],106:[20],
 113:[],115:[],116:[],117:[1],118:['etiqueta'],119:['etiqueta'],
 121:[1,1,0],122:[1,1,0,0,0],123:['A',0],124:[0,60],
 125:[0,0,100],126:[1,0,0,1],127:[1,0,0,1],128:[1,0,0,1],129:[1,0,0],
 131:[''],132:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],
 133:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],
 134:[0],135:[0],136:[0],
 201:[0,1,10,10,2,0],202:[0,0,1,10,10],203:[2,10,4],
 204:[0,''],205:[{'__class':'Tone','values':[0,0,0,0]},20],206:[128,20],
 207:[-1,1],208:[0],210:[],221:[],222:[''],
 223:[{'__class':'Tone','values':[0,0,0,0]},20],
 224:[{'__class':'Color','values':[255,255,255,255]},20],
 225:[5,5,20],231:[1,'',0,0,0,0,100,100,255,0],
 232:[1,0,0,0,0,100,100,255,0,20],233:[1,5],
 234:[1,{'__class':'Tone','values':[0,0,0,0]},20],235:[1],236:[0,5,20],
 241:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],242:[5],
 245:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],246:[5],
 247:[],248:[],249:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],
 250:[{'__class':'RPG::AudioFile','name':'','volume':100,'pitch':100}],251:[],
 351:[],352:[],353:[],354:[],
}
