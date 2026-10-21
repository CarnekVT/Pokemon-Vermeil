// Command Studio 0.4: actions are user goals, not a flat dump of Ruby methods.
// All builders produce normalized RMXP command descriptors. The host editor
// serializes them with ctx.events.createCommand() and validates on commit.
export const q=(v)=>JSON.stringify(String(v??""));
export const integer=(v,min=0,max=999999)=>{const n=Number(v);if(!Number.isSafeInteger(n)||n<min||n>max)throw Error("Número fuera de rango ("+min+"–"+max+"): "+v);return n;};
export function symbol(v){const s=String(v??"").trim().replace(/^:/,"");if(!/^[A-Za-z_]\w*$/.test(s))throw Error("Identificador no válido: "+v);return ":"+s;}
export const command=(code,parameters=[],indent=0)=>({code,parameters,indent});
export const ruby=(code)=>String(code).replace(/\r/g,"").split("\n").map((text,i)=>command(i?655:355,[text],0));
export const message=(text,indent=0)=>String(text).replace(/\r/g,"").split("\n").map((line,i)=>command(i?401:101,[line],indent));
export const switchCmd=(id,on)=>command(121,[id,id,on?0:1]);
export const selfSwitch=(letter,on)=>command(123,[letter,on?0:1]);
export function branch(condition,yes,no=[]){
 const list=[command(111,[12,condition],0),...yes.map(c=>({...c,indent:c.indent+1}))];
 if(no.length)list.push(command(411,[],0),...no.map(c=>({...c,indent:c.indent+1})));
 list.push(command(412,[],0));return list;
}
function field(key,label,type,value,opts){return{key,label,type,value,options:opts};}
const sym=(key,label,value)=>field(key,label,"symbol",value);
const text=(key,label,value)=>field(key,label,"text",value);
const num=(key,label,value,min=0,max=99999)=>({...field(key,label,"number",value),min,max});
const flag=(key,label,value=true)=>field(key,label,"boolean",value);
const sel=(key,label,value,options)=>field(key,label,"select",value,options);
const intro=(v)=>message(v.intro||"¡Hola!");
export const ACTIONS=[
 {id:"talk",title:"NPC con diálogo",category:"Diálogos",icon:"💬",description:"Mensajes nativos, líneas múltiples y códigos Essentials.",
  keywords:"hablar texto npc mensaje dialogo conversar parrafo",fields:[text("text","Texto del NPC","¡Hola, \\PN! ¿Cómo estás?")],
  build:v=>message(v.text),next:["choices","heal","npc_name"],source:"mensajes"},
 {id:"choices",title:"Pregunta con dos opciones",category:"Diálogos",icon:"❓",description:"Genera ramas de elección y sus respuestas correctamente indentadas.",
  keywords:"pregunta elegir respuesta si no opciones decisiones",fields:[text("question","Pregunta","¿Quieres continuar?"),text("yes","Opción afirmativa","Sí"),text("no","Opción negativa","No"),text("yesText","Respuesta al elegir Sí","¡Perfecto!"),text("noText","Respuesta al elegir No","Está bien.")],
  build:v=>[...message(v.question),command(102,[[v.yes,v.no],0]),command(402,[0,v.yes]),...message(v.yesText,1),command(402,[1,v.no]),...message(v.noText,1),command(404)],
  next:["gift_item_once","trainer","switch"],source:"mensajes"},
 {id:"heal",title:"Centro de curación rápido",category:"Pokémon y equipo",icon:"✚",description:"Diálogo + curación del equipo en un solo asistente.",
  keywords:"curar sanacion equipo pokemon enfermera pokemon center pokecenter",fields:[text("intro","Mensaje inicial","¡Deja que cure a tus Pokémon!"),text("outro","Mensaje final","¡Tus Pokémon están en plena forma!")],
  build:v=>[...message(v.intro),...ruby("$player.heal_party"),...message(v.outro)],next:["talk","switch"],source:"scripts-utiles",functions:["heal_party"]},
 {id:"give_pokemon",title:"Regalar Pokémon",category:"Pokémon y equipo",icon:"🐣",description:"Entrega un Pokémon especificando especie y nivel.",
  keywords:"regalar pokemon inicial recibir pokemon especie nivel starter",fields:[sym("species","Especie (PBS)","RIOLU"),num("level","Nivel",5,1,100),text("intro","Mensaje","¡Recibe este Pokémon!")],
  build:v=>[...message(v.intro),...ruby("pbAddPokemon("+symbol(v.species)+", "+integer(v.level,1,100)+")")],next:["switch","gift_pokemon_once"],source:"manipular-pokemon",functions:["pbAddPokemon"]},
 {id:"gift_pokemon_once",title:"Regalo de Pokémon solo una vez",category:"Pokémon y equipo",icon:"🎁",description:"Controla si el regalo ya se recibió mediante interruptor local.",
  keywords:"pokemon una vez regalo unico regalar pokemon starter inicial self switch",fields:[sym("species","Especie","EEVEE"),num("level","Nivel",5,1,100),sel("letter","Interruptor local","A",["A","B","C","D"]),text("thanks","Mensaje después de recibirlo","¡Cuídalo mucho!"),text("again","Mensaje si regresas","¡Espero que esté bien!")],
  build:v=>branch("!$game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]]",
     [...ruby("if pbAddPokemon("+symbol(v.species)+", "+integer(v.level,1,100)+")\n  $game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]] = true\n  $game_map.need_refresh = true\nend"),...message(v.thanks)],message(v.again)),
  next:["give_item","talk"],source:"manipular-pokemon",functions:["pbAddPokemon"]},
 {id:"give_item",title:"Entregar objeto",category:"Objetos e inventario",icon:"🎒",description:"Selecciona un objeto PBS y su cantidad.",
  keywords:"item objeto mochila entregar medicina pocion pokeball regalo",fields:[sym("item","Objeto","POTION"),num("count","Cantidad",1,1,999),text("intro","Texto previo","¡Toma este objeto!")],
  build:v=>[...message(v.intro),...ruby("pbReceiveItem("+symbol(v.item)+", "+integer(v.count,1,999)+")")],next:["gift_item_once","require_item"],source:"scripts-utiles",functions:["pbReceiveItem"]},
 {id:"gift_item_once",title:"Objeto único de suelo o NPC",category:"Objetos e inventario",icon:"📦",description:"Entrega un objeto y marca el evento para impedir regalos repetidos.",
  keywords:"item objeto suelo pokeball escondido recoger cofre regalo una vez",fields:[sym("item","Objeto","POTION"),num("count","Cantidad",1,1,999),sel("letter","Interruptor local","A",["A","B","C","D"]),text("done","Mensaje si ya se recogió","Ya no queda nada aquí.")],
  build:v=>branch("!$game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]]",
    [...ruby("if pbReceiveItem("+symbol(v.item)+", "+integer(v.count,1,999)+")\n  $game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]] = true\n  $game_map.need_refresh = true\nend")],
    message(v.done)),next:["talk","require_item"],source:"scripts-utiles",functions:["pbReceiveItem"]},
 {id:"require_item",title:"Puerta que requiere un objeto",category:"Lógica y progreso",icon:"🚪",description:"Bifurca según si el jugador tiene un objeto.",
  keywords:"requisito llave puerta objeto condicion permiso entrar",fields:[sym("item","Objeto requerido","CARDKEY"),text("yes","Mensaje con el objeto","¡La puerta se ha abierto!"),text("no","Mensaje sin el objeto","Necesitas una llave para abrirla.")],
  build:v=>branch("$bag.has?("+symbol(v.item)+")",message(v.yes),message(v.no)),next:["transfer","switch"],source:"scripts-utiles"},
 {id:"species_condition",title:"Comprobar Pokémon del equipo",category:"Lógica y progreso",icon:"🔍",description:"Mensajes y acciones según tenga una especie.",
  keywords:"si tiene pokemon comprobar especie equipo requisito",fields:[sym("species","Especie","PIKACHU"),text("yes","Respuesta si lo tiene","¡Veo que tienes a ese Pokémon!"),text("no","Respuesta si no lo tiene","Vuelve cuando lo tengas.")],
  build:v=>branch("$player.has_species?("+symbol(v.species)+")",message(v.yes),message(v.no)),next:["give_item","trainer"],source:"manipular-pokemon"},
 {id:"wild",title:"Encuentro salvaje por evento",category:"Combates",icon:"🌿",description:"Encuentro configurado por especie y nivel.",
  keywords:"batalla wild pokemon salvaje encuentro iniciar lucha",fields:[sym("species","Especie","ZORUA"),num("level","Nivel",12,1,100),text("intro","Mensaje opcional","¡Un Pokémon apareció!")],
  build:v=>[...message(v.intro),...ruby("WildBattle.start("+symbol(v.species)+", "+integer(v.level,1,100)+")")],
  next:["battle_rule","switch"],source:"encuentros-por-evento",functions:["start"]},
 {id:"trainer",title:"Entrenador con diálogo y combate",category:"Combates",icon:"⚔",description:"Combate y mensaje previo; requiere un entrenador definido en PBS.",
  keywords:"entrenador trainer batalla combate iniciar vencer rival",fields:[sym("type","Tipo de entrenador","YOUNGSTER"),text("name","Nombre registrado","Luis"),num("version","Versión del entrenador",0,0,999),text("intro","Mensaje antes del combate","¡Te desafío!")],
  build:v=>[...message(v.intro),...ruby("TrainerBattle.start("+symbol(v.type)+", "+q(v.name)+", "+integer(v.version,0,999)+")")],
  next:["trainer_once","give_item"],source:"definir-entrenador"},
 {id:"trainer_once",title:"Entrenador que recuerda su derrota",category:"Combates",icon:"🏅",description:"Solo combate hasta ser vencido; guarda el resultado en un interruptor local.",
  keywords:"trainer batalla combatir victoria una vez derrotado despues entrenador",fields:[sym("type","Tipo de entrenador","YOUNGSTER"),text("name","Nombre PBS","Luis"),num("version","Versión",0,0,999),sel("letter","Interruptor local","A",["A","B","C","D"]),text("intro","Antes de combatir","¡Prepárate!"),text("after","Después de vencerlo","¡Buen combate!")],
  build:v=>branch("!$game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]]",
     [...message(v.intro),...ruby("if TrainerBattle.start("+symbol(v.type)+", "+q(v.name)+", "+integer(v.version,0,999)+")\n  $game_self_switches[[$game_map.map_id,@event_id,"+q(v.letter)+"]] = true\n  $game_map.need_refresh = true\nend")],message(v.after)),
  next:["give_item","switch"],source:"definir-entrenador"},
 {id:"battle_rule",title:"Preparar regla para el próximo combate",category:"Combates",icon:"⚙",description:"Configura opciones del siguiente combate sin escribir la sintaxis.",
  keywords:"reglas combate batalla double canlose cannotrun field environment terrain",fields:[sel("rule","Regla","double",["single","double","triple","cannotrun","canlose","disablebag","certaincapture","autobattle"])],
  build:v=>ruby("setBattleRule("+q(v.rule)+")"),next:["trainer","wild"],source:"reglas-combate",functions:["setBattleRule"]},
 {id:"switch",title:"Activar o desactivar interruptor",category:"Lógica y progreso",icon:"◉",description:"Usa el comando nativo de interruptores compatible con Essentials.",
  keywords:"interruptor global switch activar desactivar flags",fields:[num("id","Número de interruptor",1,1,99999),flag("on","Activar",true)],
  build:v=>[switchCmd(integer(v.id,1,99999),!!v.on)],next:["talk","conditional_switch"],source:"eventos"},
 {id:"selfswitch",title:"Cambiar interruptor local",category:"Lógica y progreso",icon:"☑",description:"Ideal para páginas de evento y recompensas únicas.",
  keywords:"interruptor local self switch a b c d",fields:[sel("letter","Interruptor","A",["A","B","C","D"]),flag("on","Activar",true)],
  build:v=>[selfSwitch(v.letter,!!v.on)],next:["talk"],source:"eventos"},
 {id:"variable",title:"Modificar variable global",category:"Lógica y progreso",icon:"∑",description:"Asigna o incrementa una variable del juego.",
  keywords:"variable sumar restar establecer set plus",fields:[num("id","Número de variable",1,1,99999),sel("operation","Operación","0",[["0","Asignar"],["1","Sumar"],["2","Restar"],["3","Multiplicar"]]),num("value","Valor",1,0,999999)],
  build:v=>[command(122,[integer(v.id,1,99999),integer(v.id,1,99999),integer(v.operation,0,3),0,integer(v.value)])],next:["conditional_switch","talk"],source:"eventos"},
 {id:"conditional_switch",title:"Diálogo según interruptor",category:"Lógica y progreso",icon:"◇",description:"Crea el If / Else / End con dos respuestas.",
  keywords:"condicion if else switch interruptor variable historia dialogo",fields:[num("id","Interruptor",1,1,99999),text("yes","Texto cuando está activo","¡Bienvenido de nuevo!"),text("no","Texto cuando está inactivo","Primero debes completar la misión.")],
  build:v=>branch("$game_switches["+integer(v.id,1,99999)+"]",message(v.yes),message(v.no)),next:["give_item","transfer"],source:"eventos"},
 {id:"transfer",title:"Transportar a otro mapa",category:"Mapa y escenas",icon:"↪",description:"Transferencia mediante comando de evento, con destino y dirección.",
  keywords:"teletransportar ir otro mapa transferencia viaje puerta entrada salida",fields:[num("map","Mapa destino",1,1,9999),num("x","Casilla X",5,0,9999),num("y","Casilla Y",5,0,9999),sel("dir","Mirada","0",[["0","Mantener"],["2","Abajo"],["4","Izquierda"],["6","Derecha"],["8","Arriba"]])],
  build:v=>[command(201,[0,integer(v.map,1,9999),integer(v.x,0,9999),integer(v.y,0,9999),integer(v.dir,0,8),0])],
  next:["talk","play_se"],source:"transferencias-mapa"},
 {id:"wait",title:"Esperar unos fotogramas",category:"Mapa y escenas",icon:"⌛",description:"Pausa dentro de eventos y cinemáticas.",
  keywords:"esperar pausa delay tiempo fotogramas espera escena",fields:[num("frames","Fotogramas",20,0,99999)],build:v=>[command(106,[integer(v.frames)])],
  next:["talk","play_se"],source:"eventos"},
 {id:"play_se",title:"Reproducir efecto de sonido",category:"Audio y presentación",icon:"♪",description:"Efecto sonoro con volumen y tono ajustables.",
  keywords:"reproducir se audio sonido efecto puerta paso",fields:[text("file","Nombre de audio (SE)","Door exit"),num("volume","Volumen",80,0,100),num("pitch","Tono",100,50,150)],
  build:v=>ruby("pbSEPlay("+q(v.file)+", "+integer(v.volume,0,100)+", "+integer(v.pitch,50,150)+")"),
  next:["wait","talk"],source:"audio"},
 {id:"play_bgm",title:"Reproducir música",category:"Audio y presentación",icon:"♫",description:"Iniciar BGM con volumen y tono configurables.",
  keywords:"reproducir bgm musica cancion ambiente",fields:[text("file","Nombre BGM","Battle Wild"),num("volume","Volumen",80,0,100),num("pitch","Tono",100,50,150)],
  build:v=>ruby("pbBGMPlay("+q(v.file)+", "+integer(v.volume,0,100)+", "+integer(v.pitch,50,150)+")"),
  next:["talk","wait"],source:"audio"},
 {id:"tint",title:"Cambiar tono de pantalla",category:"Audio y presentación",icon:"◐",description:"Oscurecimiento, desaturación o iluminación gradual.",
  keywords:"tono pantalla color noche dia iluminacion oscuro fade",fields:[num("red","Rojo (+/- 255)",-64,-255,255),num("green","Verde (+/- 255)",-64,-255,255),num("blue","Azul (+/- 255)",-64,-255,255),num("gray","Gris",0,0,255),num("frames","Fotogramas",20,0,9999)],
  build:v=>ruby("$game_screen.start_tone_change(Tone.new("+integer(v.red,-255,255)+", "+integer(v.green,-255,255)+", "+integer(v.blue,-255,255)+", "+integer(v.gray,0,255)+"), "+integer(v.frames,0,9999)+")"),
  next:["play_bgm","wait"],source:"eventos"},
 {id:"time_night",title:"NPC solo de noche",category:"Tiempo y mundo",icon:"☾",description:"Genera mensajes distintos según la hora.",
  keywords:"noche madrugada hora tiempo nocturno npc dia",fields:[text("yes","Por la noche","La luna brilla hoy."),text("no","Durante el día","Nos vemos esta noche.")],
  build:v=>branch("PBDayNight.isNight?",message(v.yes),message(v.no)),next:["talk"],source:"eventos-temporales"},
 {id:"name_rater",title:"NPC Cambianombres",category:"Servicios y menús",icon:"✎",description:"Acceso al servicio para cambiar motes.",
  keywords:"cambia nombres mote name rater renombrar pokemon",fields:[text("intro","Texto inicial","¡Puedo cambiar el mote de tus Pokémon!")],
  build:v=>[...message(v.intro),...ruby("pbNameRater")],next:["talk"],source:"npcs-especiales",functions:["pbNameRater"]},
 {id:"pc",title:"Abrir PC Pokémon",category:"Servicios y menús",icon:"▣",description:"Abre el almacenamiento Pokémon.",
  keywords:"pc terminal almacenamiento caja pokemon ordenador",fields:[],build:()=>ruby("pbPokeCenterPC"),next:["talk"],source:"pc-almacenamiento"},
 {id:"pokedex",title:"Abrir Pokédex",category:"Servicios y menús",icon:"◫",description:"Abre la Pokédex desde un evento.",
  keywords:"pokedex dex pokedex abrir menu consultar",fields:[],build:()=>ruby("pbStartDex"),next:["talk"],source:"pokedex"},
 {id:"custom_ruby",title:"Ejecutar script de Essentials",category:"Avanzado",icon:"⌘",description:"Editor libre para una función concreta o un bloque Ruby.",
  keywords:"ruby script custom codigo programacion comandos manual",fields:[field("code","Código Ruby","code","pbMessage(_INTL(\"¡Hola!\"))")],
  build:v=>ruby(v.code),next:[],source:"secciones-scripts"}
];

ACTIONS.push({
 id:"dialogue_namebox",title:"Diálogo con nombre del personaje",category:"Diálogos",icon:"🏷️",
 description:"Muestra el nombre de quien habla en una cajita arriba del mensaje, y después la cierra.",
 keywords:"nombre del npc namebox dialogo personaje hablar conversacion",
 fields:[text("name","Nombre del personaje","Profesor Oak"),text("speech","Texto del mensaje","¡Bienvenido al laboratorio!")],
 build:v=>[...ruby("NameBox.load("+q(v.name)+")"),...message(v.speech),...ruby("NameBox.dispose")],
 next:["talk","choices"],source:"mensajes"
});
ACTIONS.push({
 id:"choices_with_item_icons",title:"Opciones con imágenes de objetos",category:"Diálogos",icon:"🖼️",
 description:"Muestra dos respuestas con sus iconos de objeto. Exclusivo de la ampliación LBDS; los objetos deben existir en PBS.",
 keywords:"opciones con imagenes iconos elegir item objeto visual menu choiceimage",
 fields:[text("question","Pregunta","¿Qué objeto quieres?"),text("a","Opción 1","Poción"),
   sym("iconA","Icono de objeto 1","POTION"),text("b","Opción 2","Superpoción"),
   sym("iconB","Icono de objeto 2","SUPERPOTION"),
   text("replyA","Respuesta a 1","Has elegido la poción."),
   text("replyB","Respuesta a 2","Has elegido la superpoción.")],
 build:v=>[...message(v.question),
   command(108,["s:ChoiceImage: 1, item, "+symbol(v.iconA).slice(1)]),
   command(108,["s:ChoiceImage: 2, item, "+symbol(v.iconB).slice(1)]),
   command(102,[[v.a,v.b],0]),command(402,[0,v.a]),
   ...message(v.replyA,1),command(402,[1,v.b]),
   ...message(v.replyB,1),command(404)],
 next:["talk","give_item"],source:"mensajes"
});


ACTIONS.push(
 {id:"companion_join",title:"Añadir un compañero de aventura",category:"Entrenadores",icon:"🤝",
  description:"Un NPC se une como entrenador aliado para batallas dobles. Debe existir en trainers.txt.",
  keywords:"compañero acompañante cheryl aventura aliado partner registrar equipo",
  fields:[sym("type","Tipo de entrenador del PBS","POKEMON_RANGER_F"),text("name","Nombre exacto del NPC","Cheryl"),num("version","Versión del entrenador",0,0,999),text("line","Diálogo","¡Iré contigo y combatiré a tu lado!")],
  build:v=>[...message(v.line),...ruby("pbRegisterPartner("+symbol(v.type)+", "+q(v.name)+", "+integer(v.version,0,999)+")")],
  next:["companion_leave","trainer"],source:"entrenador-companero"},
 {id:"companion_leave",title:"Despedir al compañero",category:"Entrenadores",icon:"👋",
  description:"El compañero de combate deja de viajar con el protagonista.",
  keywords:"acompañante compañero despedir salir cancelar partner acompañamiento",
  fields:[text("line","Diálogo de despedida","¡Gracias por la ayuda! Nos vemos.")],
  build:v=>[...message(v.line),...ruby("pbDeregisterPartner")],next:["talk"],source:"entrenador-companero"},
 {id:"badge_reward",title:"Conceder una medalla",category:"Lógica y progreso",icon:"🏅",
  description:"Otorga una medalla al jugador y muestra un diálogo de felicitación.",
  keywords:"medalla gimnasio insignia ganar progreso premio badge recompensa",
  fields:[num("badge","Número de medalla (la primera es 1)",1,1,24),text("line","Mensaje","¡Has conseguido una nueva Medalla!")],
  build:v=>[...ruby("$player.badges["+ (integer(v.badge,1,24)-1) +"] = true"),...message(v.line)],
  next:["badge_gate","give_item"],source:"jugador"},
 {id:"badge_gate",title:"Puerta según medallas",category:"Lógica y progreso",icon:"🏛️",
  description:"Un NPC muestra mensajes diferentes según las medallas del jugador.",
  keywords:"puerta medallas gimnasio liga necesita requisito desbloquear progreso",
  fields:[num("badges","Medallas necesarias",4,0,24),text("yes","Cuando cumple el requisito","¡Adelante! Puedes pasar."),text("no","Si aún no lo cumple","Necesitas más medallas para entrar.")],
  build:v=>branch("$player.badge_count >= "+integer(v.badges,0,24),message(v.yes),message(v.no)),
  next:["transfer","talk"],source:"jugador"},
 {id:"item_trade",title:"Intercambiar objetos con un NPC",category:"Objetos e inventario",icon:"🔄",
  description:"El NPC revisa si tienes suficientes objetos, pide confirmación y entrega una recompensa.",
  keywords:"trueque intercambio objetos tienda quest pociones bayas npc premio",
  fields:[sym("take","Objeto que entrega el jugador","ORANBERRY"),num("takeQty","Cantidad necesaria",3,1,999),
   sym("give","Objeto que recibe el jugador","RARECANDY"),num("giveQty","Cantidad recibida",1,1,999)],
  build:v=>ruby(
    "if $bag.has?("+symbol(v.take)+", "+integer(v.takeQty,1,999)+")\n"+
    "  if !$bag.can_add?("+symbol(v.give)+", "+integer(v.giveQty,1,999)+")\n"+
    "    pbMessage(_INTL(\"No tienes espacio suficiente.\"))\n"+
    "  elsif pbConfirmMessage(_INTL(\"¿Quieres realizar el intercambio?\"))\n"+
    "    $bag.remove("+symbol(v.take)+", "+integer(v.takeQty,1,999)+")\n"+
    "    pbReceiveItem("+symbol(v.give)+", "+integer(v.giveQty,1,999)+")\n"+
    "  end\n"+
    "else\n"+
    "  pbMessage(_INTL(\"No tienes los objetos necesarios.\"))\n"+
    "end"
  ),next:["give_item"],source:"manipular-objetos"},
 {id:"weather_event",title:"Cambiar el tiempo del mapa",category:"Mapa y escenas",icon:"🌧️",
  description:"Activa lluvia, sol, nieve u otro clima con una transición.",
  keywords:"clima lluvia sol nieve tormenta arena niebla ruta ambiente tiempo weather",
  fields:[sel("weather","Clima","Rain",[["Rain","Lluvia"],["Storm","Tormenta"],["Snow","Nieve"],["Sandstorm","Arena"],["Sun","Sol"],["Fog","Niebla"],["None","Despejado"]]),
   num("intensity","Intensidad (0 a 9)",5,0,9),num("frames","Duración de cambio",20,0,9999)],
  build:v=>ruby("$game_screen.weather("+symbol(v.weather)+", "+integer(v.intensity,0,9)+", "+integer(v.frames,0,9999)+")"),
  next:["talk","wait"],source:"clima"},
 {id:"weekday_npc",title:"Personaje de un día concreto",category:"Tiempo y mundo",icon:"📅",
  description:"Un NPC dice algo diferente un día elegido de la semana.",
  keywords:"dia semana lunes viernes domingo mercado horario fecha npc calendario",
  fields:[sel("day","Día","5",[["0","Domingo"],["1","Lunes"],["2","Martes"],["3","Miércoles"],["4","Jueves"],["5","Viernes"],["6","Sábado"]]),
   text("yes","Mensaje ese día","¡Hoy es mi día especial!"),text("no","Mensaje los otros días","Regresa otro día.")],
  build:v=>branch("pbGetTimeNow.wday == "+integer(v.day,0,6),message(v.yes),message(v.no)),
  next:["give_item","talk"],source:"eventos-temporales"},
 {id:"give_egg",title:"Regalar un huevo Pokémon",category:"Pokémon y equipo",icon:"🥚",
  description:"Entrega un huevo de una especie al jugador con mensaje.",
  keywords:"huevo huevo pokemon egg criar regalo misterioso incubar",
  fields:[sym("species","Especie del huevo","TOGEPI"),text("line","Mensaje","¡Recibiste un Huevo Pokémon!")],
  build:v=>[...message(v.line),...ruby("pbGenerateEgg("+symbol(v.species)+")")],
  next:["talk","selfswitch"],source:"manipular-pokemon"},
 {id:"music_fanfare",title:"Reproducir una fanfarria",category:"Audio y presentación",icon:"🎶",
  description:"Reproduce un efecto musical especial para conseguir objetos, medallas y eventos.",
  keywords:"musica fanfarria jingle victoria premio me",
  fields:[text("name","Archivo ME","Pokemon get"),num("volume","Volumen",90,0,100)],
  build:v=>ruby("pbMEPlay("+q(v.name)+", "+integer(v.volume,0,100)+")"),
  next:["talk","badge_reward"],source:"audio"},
 {id:"rival_variable",title:"Rival que cambia equipo según una variable",category:"Combates",icon:"⚔️",
  description:"Elige la versión del rival según el inicial elegido por el jugador. Requiere versiones PBS configuradas.",
  keywords:"rival inicial variable dinamico nivel version batalla evolucion progresiva",
  fields:[sym("type","Tipo de entrenador","RIVAL1"),text("name","Nombre del rival","Silver"),
   num("stage","Número de encuentro (0 primero)",0,0,100),num("variable","Variable del inicial (0,1,2)",7,1,99999)],
  build:v=>ruby("TrainerBattle.start("+symbol(v.type)+", "+q(v.name)+", "+integer(v.stage,0,100)+" * 3 + $game_variables["+integer(v.variable,1,99999)+"])"),
  next:["give_item","badge_reward"],source:"rival"}
);

export const BY_ID=new Map(ACTIONS.map(x=>[x.id,x]));
export const CATEGORIES=[...new Set(ACTIONS.map(x=>x.category))];
export const SOURCES="https://la-base-de-sky-wiki-1070f3.gitlab.io/pages/";
export function defaults(action){return Object.fromEntries(action.fields.map(f=>[f.key,f.value]));}
export function validate(action,values){
 const warnings=[],errors=[];
 if(!action)errors.push("Acción desconocida");
 else {
  for(const f of action.fields){
   if(f.type==="symbol")try{symbol(values[f.key]);}catch(e){errors.push(f.label+": "+e.message);}
   if(f.type==="number")try{integer(values[f.key],f.min??-999999,f.max??999999);}catch(e){errors.push(f.label+": "+e.message);}
   if(f.type==="text"&&!String(values[f.key]??"").trim())warnings.push(f.label+" está vacío.");
  }
 }
 return {errors,warnings};
}
export function buildAction(id,values){
 const action=BY_ID.get(id);if(!action)throw Error("Acción no encontrada: "+id);
 const check=validate(action,values);if(check.errors.length)throw Error(check.errors.join("; "));
 return action.build(values);
}
const NORMALIZE=s=>String(s??"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
const EXPAND={curar:"heal",sanar:"heal",medicina:"give_item",premio:"give_item",regalo:"gift",combate:"trainer wild",enemigo:"trainer",captura:"wild",interruptor:"switch",pokemon:"pokemon especie equipo",ocultar:"selfswitch",dialogo:"talk",hablar:"talk",escena:"tint wait",teletransporte:"transfer",npc:"talk"};
export function smartSearch(query,catalog=ACTIONS){
 const q=NORMALIZE(query).trim();
 if(!q)return catalog.map(action=>({action,score:0}));
 const tokens=q.split(/\s+/).filter(Boolean);
 const expanded=tokens.flatMap(t=>[t,...(EXPAND[t]||"").split(" ").filter(Boolean)]);
 return catalog.map(action=>{
  const title=NORMALIZE(action.title), id=NORMALIZE(action.id.replace(/_/g," ")), body=NORMALIZE([action.category,action.description,action.keywords].join(" "));
  let score=0;for(const token of expanded){if(title.includes(token))score+=7;if(id.includes(token))score+=5;if(body.includes(token))score+=2;}
  if(title.includes(q))score+=14;if(action.keywords.includes(q))score+=5;
  return{action,score};
 }).filter(x=>x.score>0).sort((a,b)=>b.score-a.score||a.action.title.localeCompare(b.action.title));
}
