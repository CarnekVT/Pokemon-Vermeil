// RMXP event opcodes, including continuation and structural instructions.
// A visible item does not imply the stock command is supported by Essentials.
const entries = [
["Mensajes","101|Mostrar texto|mensaje diálogo hablar texto;401|Continuar texto|línea mensaje;102|Mostrar elecciones|opciones elegir;402|Rama de elección|opción rama;403|Cancelar elección|cancelar;404|Fin de elecciones|cerrar;103|Introducir número|número entrada;104|Opciones de texto|posición ventana;105|Entrada de botón|tecla botón;108|Comentario|anotación;408|Continuar comentario|nota"],
["Flujo y lógica","106|Esperar|pausa fotogramas;111|Condición|if script variable interruptor;411|Si no (Else)|alternativa;412|Fin de condición|fin if;112|Bucle|repetir loop;413|Fin del bucle|repeat;113|Romper bucle|break;115|Terminar evento|salir;116|Borrar evento temporalmente|erase;117|Llamar evento común|common event;118|Etiqueta|label;119|Ir a etiqueta|jump"],
["Variables e interruptores","121|Controlar interruptores|switch on off;122|Controlar variables|variable sumar restar;123|Interruptor local|self switch A B C D;124|Temporizador|timer;125|Cambiar dinero|oro;126|Cambiar objetos|inventario;127|Cambiar armas|armas;128|Cambiar armaduras|armaduras;129|Cambiar grupo|party;131|Cambiar apariencia de ventana|windowskin;132|BGM de batalla|música combate;133|ME de victoria|música victoria;134|Permitir guardar|save;135|Permitir menú|menu;136|Permitir encuentros|wild encounters"],
["Mapa y movimiento","201|Transferir jugador|teleport coordenadas;202|Mover evento de lugar|posición evento;203|Desplazar mapa|scroll;204|Configuración de mapa|panorama niebla;205|Tono de niebla|fog tone;206|Opacidad de niebla|fog opacity;207|Mostrar animación|animation;208|Transparencia del jugador|transparent;209|Ruta de movimiento|move route;509|Continuación de movimiento|move route;210|Esperar ruta|wait"],
["Pantalla e imágenes","221|Preparar transición|transition;222|Ejecutar transición|transition;223|Tono de pantalla|color noche;224|Destello de pantalla|flash;225|Sacudir pantalla|shake;231|Mostrar imagen|picture;232|Mover imagen|picture;233|Rotar imagen|picture;234|Tono de imagen|picture tone;235|Borrar imagen|erase picture;236|Clima|weather lluvia nieve"],
["Audio","241|Reproducir BGM|música fondo;242|Desvanecer BGM|fade;245|Reproducir BGS|ambiente;246|Desvanecer BGS|fade;247|Guardar BGM/BGS|guardar música;248|Restaurar BGM/BGS|restaurar música;249|Reproducir ME|jingle;250|Reproducir SE|efecto sonido;251|Detener SE|stop"],
["Batalla y BD RMXP","301|Procesar batalla|battle;601|Rama victoria|win;602|Rama huida|escape;603|Rama derrota|lose;604|Fin de batalla|battle end;302|Abrir tienda|shop;605|Continuar mercancías|shop;303|Introducir nombre|name input;311|Cambiar HP|health;312|Cambiar SP|mana;313|Cambiar estado|state;314|Recuperar todo|heal;315|Cambiar experiencia|exp;316|Cambiar nivel|level;317|Cambiar parámetros|stats;318|Cambiar habilidad|skill;319|Cambiar equipo|equipment;320|Cambiar nombre|actor;321|Cambiar clase|class;322|Cambiar gráfico|sprite;331|HP enemigo|enemy health;332|SP enemigo|enemy mana;333|Estado enemigo|enemy status;334|Curar enemigo|heal enemy;335|Aparecer enemigo|enemy appear;336|Transformar enemigo|transform;337|Animación de batalla|battle anim;338|Infligir daño|damage;339|Forzar acción|action;340|Cancelar batalla|abort;351|Abrir menú|menu;352|Pantalla de guardar|save;353|Game Over|gameover;354|Volver al título|title"],
["Ruby / estructurales","355|Ejecutar script|ruby rgss pb;655|Continuar script|multilínea;0|Fin de lista|interno"]
];
export const INTERNAL=new Set([0,401,402,403,404,408,411,412,413,509,601,602,603,604,605,655]);
export const NATIVE=entries.flatMap(([category,raw])=>raw.split(";").map(part=>{
  const [code,title,aliases=""]=part.split("|");return {kind:"native",id:"n"+code,code:Number(code),title,category,aliases, internal:INTERNAL.has(Number(code))};
}));
export const RECIPES=[
["Cura del equipo","Equipo","pbHealAll","Cura al equipo completo."],
["Entregar Pokémon","Pokémon","pbAddPokemon(:RIOLU, 5)","Especie y nivel."],
["Dar objeto","Objetos","pbReceiveItem(:POTION, 1)","Objeto y cantidad."],
["Quitar objeto","Objetos","pbTakeItem(:POTION, 1)","Comprobar disponibilidad antes de usar."],
["Combate salvaje","Combates","WildBattle.start(:PIKACHU, 5)","Inicia un combate salvaje."],
["Combate entrenador","Combates","TrainerBattle.start(:YOUNGSTER, \"Luis\")","Entrenador existente en PBS."],
["Mensaje Pokémon","Textos","pbMessage(_INTL(\"¡Hola!\"))","Muestra un mensaje Essentials."],
["Mostrar elección","Textos","pbShowCommands(_INTL(\"Elige\"), [_INTL(\"Sí\"), _INTL(\"No\")], -1)","Devuelve índice de respuesta; revisar firma en base usada."],
["Cambiar interruptor local","Eventos","pbSetSelfSwitch(@event_id, \"A\", true)","Usar solo desde un evento válido."],
["Nombre del jugador","Datos","$player.name","Leer nombre del jugador."],
["Tamaño del equipo","Datos","$player.party.length","Leer cantidad de Pokémon."],
["Dinero del jugador","Datos","$player.money","Consultar saldo."],
["Guardar variable","Eventos","$game_variables[1] = 10","Asignación por ID."],
["Activar interruptor","Eventos","$game_switches[1] = true","Activar interruptor global."],
["Esperar fotogramas","Eventos","pbWait(20)","Esperar, sujeto al contexto y versión."],
["Nombre de Pokémon","Datos","GameData::Species.get(:PIKACHU).name","Consultar nombre localizado."],
["Dato de objeto","Datos","GameData::Item.get(:POTION).name","Consultar nombre de objeto."],
["Anuncio de depuración","Debug","p \"Command Studio\"","Solo pruebas."],
].map(([title,category,code,description],i)=>({kind:"recipe",id:"r"+i,title,category,code,description}));
