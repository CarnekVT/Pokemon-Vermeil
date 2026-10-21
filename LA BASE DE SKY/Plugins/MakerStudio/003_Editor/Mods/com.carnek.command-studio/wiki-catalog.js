// Command Studio: wiki-backed *examples*, not an exhaustive list of functions.
// Source references are visible per entry; only documented samples are treated as verified.
const BASE="https://la-base-de-sky-wiki-1070f3.gitlab.io/pages/";
function entry(group,title,slug,template,args=[],note="",aliases=""){
 return {kind:"wiki",id:"wiki:"+slug+":"+title,group,title,source:BASE+slug+".html",template,args,note,aliases};
}
export const WIKI=[
 entry("Pokémon · Equipo","Añadir Pokémon","manipular-pokemon","pbAddPokemon({species}, {level})",[["species","Especie","symbol","PIKACHU"],["level","Nivel","integer","10"]],"Agrega al equipo o PC."),
 entry("Pokémon · Equipo","Añadir Pokémon silencioso","manipular-pokemon","pbAddPokemonSilent({species}, {level})",[["species","Especie","symbol","EEVEE"],["level","Nivel","integer","5"]]),
 entry("Pokémon · Equipo","Añadir solo al equipo, sin mensaje","manipular-pokemon","pbAddToPartySilent({species}, {level})",[["species","Especie","symbol","BULBASAUR"],["level","Nivel","integer","5"]],"Devuelve false cuando el equipo esté completo."),
 entry("Pokémon · Equipo","Quitar Pokémon de un slot","manipular-pokemon","pbRemovePokemonAt({slot})",[["slot","Posición (0–5)","integer","0"]],"No usar si queda un único Pokémon."),
 entry("Pokémon · Equipo","Elegir Pokémon","manipular-pokemon","pbChoosePokemon({index_variable}, {name_variable})",[["index_variable","Variable índice","integer","1"],["name_variable","Variable nombre","integer","2"]]),
 entry("Pokémon · Equipo","Elegir Pokémon apto","manipular-pokemon","pbChooseAblePokemon({index_variable}, {name_variable})",[["index_variable","Variable índice","integer","1"],["name_variable","Variable nombre","integer","2"]]),
 entry("Pokémon · Equipo","Elegir Pokémon intercambiable","manipular-pokemon","pbChooseTradablePokemon({index_variable}, {name_variable})",[["index_variable","Variable índice","integer","1"],["name_variable","Variable nombre","integer","2"]]),
 entry("Pokémon · Equipo","Consultar especie en equipo","manipular-pokemon","$player.has_species?({species})",[["species","Especie","symbol","PIKACHU"]],"Expresión booleana: usar en condición."),
 entry("Pokémon · Equipo","Comprobar si equipo está lleno","manipular-pokemon","$player.party_full?",[],"Expresión booleana."),
 entry("Pokémon · Equipo","Cantidad de Pokémon en equipo","manipular-pokemon","$player.party_count",[],"Expresión de lectura."),
 entry("Pokémon · Equipo","Curar equipo","scripts-utiles","$player.heal_party"),
 entry("Pokémon · Equipo","Curar un Pokémon del equipo","manipular-pokemon","$player.party[{slot}].heal",[["slot","Posición (0–5)","integer","0"]],"Verifica antes que haya un Pokémon en esa posición."),
 entry("Pokémon · Equipo","Hacer shiny un Pokémon","manipular-pokemon","$player.party[{slot}].shiny = true",[["slot","Posición (0–5)","integer","0"]]),
 entry("Pokémon · Equipo","Dar objeto equipado","manipular-pokemon","$player.party[{slot}].item = {item}",[["slot","Posición (0–5)","integer","0"],["item","Objeto","symbol","LEFTOVERS"]]),
 entry("Pokémon · Equipo","Comprobar objeto equipado","manipular-pokemon","$player.party[{slot}].hasItem?({item})",[["slot","Posición","integer","0"],["item","Objeto","symbol","LEFTOVERS"]]),
 entry("Pokémon · Equipo","Cambiar nivel","manipular-pokemon","pbChangeLevel($player.party[{slot}], {level}, nil)",[["slot","Posición","integer","0"],["level","Nuevo nivel","integer","20"]]),
 entry("Pokémon · Equipo","Pokémon conoce movimiento","scripts-utiles","$player.party[{slot}].hasMove?({move})",[["slot","Posición","integer","0"],["move","Movimiento","symbol","THUNDERBOLT"]]),
 entry("Objetos","Entregar objeto","scripts-utiles","pbReceiveItem({item}, {quantity})",[["item","Objeto","symbol","POTION"],["quantity","Cantidad","integer","1"]]),
 entry("Objetos","Quitar objeto de mochila","scripts-utiles","$bag.remove({item})",[["item","Objeto","symbol","POTION"]]),
 entry("Objetos","Comprobar objeto en mochila","scripts-utiles","$bag.has?({item})",[["item","Objeto","symbol","POKEBALL"]],"Expresión booleana."),
 entry("Objetos","Consultar cantidad objeto","scripts-utiles","$bag.quantity({item})",[["item","Objeto","symbol","POTION"]]),
 entry("Combates","Combate salvaje","scripts-utiles","WildBattle.start({species}, {level})",[["species","Especie","symbol","PIKACHU"],["level","Nivel","integer","25"]]),
 entry("Combates","Combate entrenador","definir-entrenador","TrainerBattle.start({trainer_type}, {name}, {version})",[["trainer_type","Tipo entrenador","symbol","YOUNGSTER"],["name","Nombre de entrenador","string","Pepito"],["version","Versión","integer","0"]]),
 entry("Combates","Regla de batalla","reglas-batalla","setBattleRule({rule})",[["rule","Regla","string","double"]],"Confirma las reglas disponibles en los scripts de esta versión."),
 entry("Mensajes","Mostrar mensaje","mensajes","pbMessage({text})",[["text","Texto","string","¡Hola, \\PN!"]]),
 entry("Mensajes","Confirmación Sí / No","mensajes","pbConfirmMessage({question})",[["question","Pregunta","string","¿Quieres continuar?"]],"Expresión booleana; usar en condición."),
 entry("Mensajes","Introducir texto","mensajes","pbEnterText({prompt}, {min}, {max})",[["prompt","Pregunta","string","Introduce un nombre:"],["min","Mínimo de caracteres","integer","0"],["max","Máximo de caracteres","integer","10"]]),
 entry("Mensajes","Pregunta con elecciones","mensajes","pbMessage({question}, [{yes}, {no}], -1)",[["question","Pregunta","string","¿Qué quieres hacer?"],["yes","Opción A","string","Luchar"],["no","Opción B","string","Huir"]]),
 entry("Menús","Abrir Pokédex","scripts-utiles","pbFadeOutIn { pbStartDex }"),
 entry("Menús","Abrir PC","scripts-utiles","pbFadeOutIn { pbPokeCenterPC }"),
 entry("Menús","Abrir tienda Pokémon","scripts-utiles","pbPokemonMart([{item1}, {item2}, {item3}])",[["item1","Objeto 1","symbol","POTION"],["item2","Objeto 2","symbol","SUPERPOTION"],["item3","Objeto 3","symbol","POKEBALL"]]),
 entry("Mapa y eventos","Obtener evento actual","controlar-eventos","get_self",[],"Disponible desde un script ejecutado por un evento."),
 entry("Mapa y eventos","Obtener evento por ID","controlar-eventos","get_character({id})",[["id","ID (0 jugador, -1 actual)","integer","3"]]),
 entry("Mapa y eventos","Consultar ID del mapa","scripts-utiles","$game_map.map_id"),
 entry("Mapa y eventos","Activar switch global","controlar-eventos","$game_switches[{id}] = {state}",[["id","ID interruptor","integer","10"],["state","Estado","boolean","true"]]),
 entry("Mapa y eventos","Cambiar variable","controlar-eventos","$game_variables[{id}] = {value}",[["id","ID variable","integer","1"],["value","Valor Ruby","expression","5"]]),
 entry("Mapa y eventos","Activar self switch del evento","controlar-eventos","$game_self_switches[[$game_map.map_id, @event_id, {letter}]] = {state}\n$game_map.need_refresh = true",[["letter","Letra","string","A"],["state","Estado","boolean","true"]],"Se ejecuta en el propio evento."),
 entry("Mapa y eventos","Consultar self switch de otro evento","controlar-eventos","pbGetSelfSwitch({event_id}, {letter}, {map_id})",[["event_id","ID evento","integer","3"],["letter","Letra","string","B"],["map_id","ID mapa","integer","25"]]),
 entry("Mapa y eventos","Cambiar gráfico del evento","controlar-eventos","get_self.character_name = {graphic}",[["graphic","Nombre charset","string","NPC 01"]],"Dentro del evento actual."),
 entry("Mapa y eventos","Mover evento por script","controlar-eventos","pbMoveRoute(get_character({id}), [PBMoveRoute::Down, PBMoveRoute::Right, PBMoveRoute::TurnUp])",[["id","ID de evento","integer","3"]],"Personaliza los pasos de la ruta en el código generado."),
 entry("Mapa y eventos","Reproducir SE","scripts-utiles","pbSEPlay({file})",[["file","Nombre de audio","string","Door exit"]]),
 entry("Mapa y eventos","Reproducir BGM","scripts-utiles","pbBGMPlay({file})",[["file","Nombre de BGM","string","Battle Elite"]]),
 entry("Mapa y eventos","Cambiar clima","scripts-utiles","$game_screen.weather({weather}, {strength}, {frames})",[["weather","Tipo de clima Ruby","symbol","Rain"],["strength","Intensidad","integer","5"],["frames","Fotogramas","integer","20"]]),
 entry("Mapa y eventos","Transferir jugador","scripts-utiles","pbTransferPlayer({map}, {x}, {y}, {direction})",[["map","Mapa ID","integer","25"],["x","Casilla X","integer","10"],["y","Casilla Y","integer","8"],["direction","Dirección","integer","2"]],"Confirma firma en los scripts locales de esta versión."),
 entry("Tiempo","¿Es por la mañana?","eventos-temporales","PBDayNight.isMorning?",[],"Expresión de condición."),
 entry("Tiempo","¿Es de día?","eventos-temporales","PBDayNight.isDay?",[],"Expresión de condición."),
 entry("Tiempo","¿Es por la tarde?","eventos-temporales","PBDayNight.isEvening?",[],"Expresión de condición."),
 entry("Tiempo","¿Es de noche?","eventos-temporales","PBDayNight.isNight?",[],"Expresión de condición."),
 entry("Tiempo","Hora actual","eventos-temporales","pbGetTimeNow",[],"Devuelve objeto Time."),
 entry("Handlers","Handler de evento global","handlers","EventHandlers.add({event}, {unique_key}, proc {\n  # Tu código Ruby aquí\n})",[["event","Símbolo de evento","symbol","on_new_game"],["unique_key","ID único","symbol","command_studio_example"]],"Código para un plugin, no para un evento RMXP corriente."),
 entry("Depuración","Mensaje de depuración","scripts-utiles","p {text}",[["text","Texto","string","Debug"]])
];

// Más parámetros documentados, con nombres, valores y tipos editables.
WIKI.push(
 entry("Combates","Encuentro salvaje con resultado","encuentros-salvajes","pbWildBattle({species}, {level}, {result_variable}, {can_run}, {can_lose})",[["species","Especie","symbol","SNORLAX"],["level","Nivel","integer","30"],["result_variable","Variable resultado","integer","1"],["can_run","Permitir huir","boolean","true"],["can_lose","Permitir perder","boolean","false"]]),
 entry("Combates","Batalla salvaje doble","encuentros-salvajes","pbDoubleWildBattle({species_a}, {level_a}, {species_b}, {level_b})",[["species_a","Especie A","symbol","PLUSLE"],["level_a","Nivel A","integer","15"],["species_b","Especie B","symbol","MINUN"],["level_b","Nivel B","integer","15"]]),
 entry("Combates","Regla: no se permite huir","encuentros-salvajes",'setBattleRule("cannotRun")'),
 entry("Combates","Regla: perder sin Game Over","encuentros-salvajes",'setBattleRule("canLose")'),
 entry("Combates","Regla: música de combate","encuentros-salvajes","setBattleRule({key}, {file})",[["key","Regla de música","string","battleBGM"],["file","Archivo BGM","string","Battle Legendary"]]),
 entry("Objetos","Obtener objeto de suelo","manipular-objetos","pbItemBall({item}, {quantity})",[["item","Objeto","symbol","NUGGET"],["quantity","Cantidad","integer","1"]]),
 entry("Objetos","Añadir a mochila (silencioso)","manipular-objetos","$bag.add({item}, {quantity})",[["item","Objeto","symbol","POTION"],["quantity","Cantidad","integer","5"]]),
 entry("Objetos","Mochila: comprobar espacio","manipular-objetos","$bag.can_add?({item}, {quantity})",[["item","Objeto","symbol","POKEBALL"],["quantity","Cantidad","integer","10"]]),
 entry("Objetos","Elegir objeto de mochila","manipular-objetos","pbChooseItem",[],"Devuelve el objeto escogido o nil."),
 entry("Objetos","Elegir bonguri","manipular-objetos","pbChooseApricorn",[],"Devuelve el bonguri elegido o nil."),
 entry("Objetos","Precio de un objeto","manipular-objetos","GameData::Item.get({item}).price",[["item","Objeto","symbol","POTION"]]),
 entry("Objetos","Comprobar ID de objeto","manipular-objetos","GameData::Item.exists?({item})",[["item","Objeto","symbol","POTION"]]),
 entry("Pokémon · Movimientos","Aprender movimiento","manipular-objetos","pbLearnMove($player.party[{slot}], {move})",[["slot","Posición del Pokémon","integer","0"],["move","Movimiento","symbol","TACKLE"]],"Comprobar compatibilidad cuando procede."),
 entry("Pokémon · Movimientos","Comprobar compatibilidad de MT","manipular-objetos","$player.party[{slot}].compatible_with_move?(GameData::Item.get({tm}).move)",[["slot","Posición Pokémon","integer","0"],["tm","ID de MT","symbol","TM01"]]),
 entry("Mapa y eventos","Centro Pokémon actual","eventos","pbSetPokemonCenter"),
 entry("Mapa y eventos","Movimiento de cámara","mapas","pbScrollMap({dir}, {distance}, {speed})",[["dir","Dirección","integer","2"],["distance","Distancia","number","5"],["speed","Velocidad","integer","4"]])
);


// Essentials Docs / Messages + LBDS / Mensajes – message API functions used in events.
WIKI.push(
 entry("Mensajes","Preguntar Sí/No","mensajes","pbConfirmMessage({question})",[["question","Pregunta","string","¿Quieres continuar?"]],"Devuelve true/false; usar como condición."),
 entry("Mensajes","Confirmación con opción negativa primero","mensajes","pbConfirmMessageSerious({question})",[["question","Pregunta","string","¿Seguro que quieres continuar?"]],"Devuelve true cuando elige Sí."),
 entry("Mensajes","Mostrar nombre del hablante","mensajes","NameBox.load({speaker})",[["speaker","Nombre","string","Profesor Oak"]],"Muestra una etiqueta antes del siguiente mensaje; cerrar luego con NameBox.dispose."),
 entry("Mensajes","Cerrar caja de nombre","mensajes","NameBox.dispose",[],"Libera el nombre del hablante."),
 entry("Mensajes","Texto largo libre","mensajes","pbMessageFreeText({prompt}, {default}, false, {max})",[
 ["prompt","Instrucción","string","Escribe tu respuesta"],["default","Valor inicial","string",""],["max","Máximo de caracteres","integer","100"]],"Devuelve el texto. La entrada es un diálogo con teclado; no es un mensaje normal."),
 entry("Mensajes","Elegir texto corto","mensajes","pbEnterText({prompt}, {min}, {max}, {default})",[
 ["prompt","Instrucción","string","¿Cómo te llamas?"],["min","Mínimo","integer","0"],["max","Máximo","integer","10"],["default","Nombre inicial","string",""]],"Invoca la pantalla de entrada de nombre."),
 entry("Mensajes","Mensaje con ayuda","mensajes","pbMessageWithHelp({text}, [{help}], [{choice}])",[
 ["text","Mensaje","string","Elige una opción"],["help","Ayuda","string","Esta opción te ayuda"],["choice","Opción","string","Continuar"]],"Para menús con texto explicativo. Revisa que opciones y ayudas tengan la misma longitud."),
 entry("Mensajes","Mensaje con lista y cancelación","mensajes","pbMessage({text}, [{one}, {two}], {cancel})",[
 ["text","Pregunta","string","¿Qué prefieres?"],["one","Opción A","string","Luchar"],["two","Opción B","string","Huir"],["cancel","Índice cancelación (0=sin cancelar)","integer","-1"]],"Devuelve un índice basado en 0; puede ser -1 al cancelar."),
 entry("Mensajes","Nombre del Pokémon del equipo elegido","manipular-pokemon","$player.party[{slot}].name",[["slot","Posición 0–5","integer","0"]],"Expresión Ruby de lectura.")
);

export const WIKI_REFERENCES=[
 ["Pokémon","manipular-pokemon"],["Movimientos","movimientos"],["Habilidades","habilidades"],["Objetos","manipular-objetos"],
 ["Combates","combate"],["Entrenadores","definir-entrenador"],["Mensajes","mensajes"],["Mapas","mapas"],
 ["Eventos","eventos"],["Control de eventos","controlar-eventos"],["Eventos temporales","eventos-temporales"],
 ["Handlers","handlers"],["Scripts útiles","scripts-utiles"],["Archivos PBS","pbs"],["Plugins","plugins"]
].map(([title,slug])=>({title,url:BASE+slug+".html"}));
export function rubyValue(type,raw){
 let v=String(raw??"").trim();
 if(type==="string")return JSON.stringify(v);
 if(type==="symbol"){v=v.replace(/^:/,"");if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(v))throw Error("Símbolo Ruby inválido: "+v);return ":"+v;}
 if(type==="integer"){if(!/^-?\d+$/.test(v))throw Error("Se requiere un entero: "+v);return String(parseInt(v,10));}
 if(type==="boolean"){if(!["true","false"].includes(v))throw Error("Usa true o false");return v;}
 if(type==="expression"){if(!v)throw Error("Introduce una expresión");return v;}
 return v;
}
export function buildWiki(item,values){
 let template=item.template;
 for(const [name,label,type] of item.args){
  const value=rubyValue(type,values[name]);
  template=template.split("{"+name+"}").join(value);
 }
 return template;
}
