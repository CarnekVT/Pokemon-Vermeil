// Native RPG Maker XP command serializer, extracted from Command Studio 0.2.0.
const integer=(v,min=0,max=999999)=>Math.max(min,Math.min(max,Number.isFinite(Number(v))?Math.trunc(Number(v)):min));
const escaped=(s)=>JSON.stringify(String(s??""));
const asCommands=(entries)=>entries.map(({code,parameters=[],indent=0})=>({code,indent,parameters}));
function ncmd(code,parameters=[],indent=0){return{code,parameters,indent};}
function scriptCommands(source){
  return String(source).replace(/\r/g,"").split("\n").map((line,i)=>ncmd(i?655:355,[line]));
}
function textCommands(source,first,other){
  return String(source).replace(/\r/g,"").split("\n").map((line,i)=>ncmd(i?other:first,[line]));
}
const FIELD_DEFS={
  103:[["variable","Variable","number",1],["digits","Cifras","number",2]],
  105:[["variable","Guardar tecla en variable","number",1]],
  106:[["frames","Fotogramas","number",20]],
  111:[["condition","Condición Ruby (debe devolver true/false)","textarea","$game_switches[1]"]],
  112:[],
  113:[],115:[],116:[],
  117:[["common","ID de evento común","number",1]],
  118:[["label","Nombre de etiqueta","text","INICIO"]],
  119:[["label","Etiqueta destino","text","INICIO"]],
  121:[["first","Interruptor inicial","number",1],["last","Interruptor final","number",1],["enabled","Valor","select","0",[["0","ON"],["1","OFF"]]]],
  122:[["first","Variable inicial","number",1],["last","Variable final","number",1],["op","Operación","select","0",[["0","Asignar"],["1","Sumar"],["2","Restar"],["3","Multiplicar"],["4","Dividir"],["5","Módulo"]]],["value","Constante","number",1]],
  123:[["letter","Interruptor local","select","A",[["A","A"],["B","B"],["C","C"],["D","D"]]],["enabled","Valor","select","0",[["0","ON"],["1","OFF"]]]],
  124:[["seconds","Segundos","number",60],["action","Temporizador","select","0",[["0","Iniciar"],["1","Detener"]]]],
  125:[["amount","Cantidad de oro","number",100]],
  126:[["id","ID objeto (BD RMXP)","number",1],["quantity","Cantidad","number",1]],
  201:[["map","ID del mapa","number",1],["x","Casilla X","number",10],["y","Casilla Y","number",10],["direction","Mirada","select","2",[["0","Conservar"],["2","Abajo"],["4","Izquierda"],["6","Derecha"],["8","Arriba"]]],["fade","Fundido","select","0",[["0","Normal"],["1","Sin fundido"]]]],
  207:[["target","Objetivo","number",-1],["animation","ID animación","number",1]],
  223:[["r","Rojo (-255 a 255)","number",0],["g","Verde (-255 a 255)","number",0],["b","Azul (-255 a 255)","number",0],["gray","Gris (0 a 255)","number",0],["frames","Duración (frames)","number",20]],
  225:[["power","Potencia","number",5],["speed","Velocidad","number",5],["frames","Duración","number",20]],
  231:[["id","ID de imagen","number",1],["file","Archivo de Graphics/Pictures","text","imagen"],["x","X","number",0],["y","Y","number",0],["opacity","Opacidad","number",255]],
  235:[["id","ID de imagen","number",1]],
  236:[["type","Clima","select","1",[["0","Ninguno"],["1","Lluvia"],["2","Tormenta"],["3","Nieve"]]],["strength","Intensidad (0 a 9)","number",5],["frames","Duración","number",20]],
  241:[["file","Nombre del archivo BGM","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  245:[["file","Nombre del archivo BGS","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  249:[["file","Nombre del archivo ME","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  250:[["file","Nombre del archivo SE","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  242:[["seconds","Segundos de fundido","number",5]],
  246:[["seconds","Segundos de fundido","number",5]],
  102:[["options","Opciones (una por línea; máximo cuatro)","textarea","Sí\nNo"]],
  104:[["position","Posición ventana","select","2",[["0","Arriba"],["1","Centro"],["2","Abajo"]]]]
};
const SIMPLE_NO_PARAMS=new Set([0,112,113,115,116,210,221,247,248,251,351,352,353,354]);
const audio=(v)=>({__class:"RPG::AudioFile",name:String(v.file||""),volume:integer(v.volume,0,100),pitch:integer(v.pitch,50,150)});
function compileNative(code,v,custom) {
  const num=(k,min=0,max=999999)=>integer(v[k],min,max);
  switch(code){
    case 101:return textCommands(v.text||"",101,401);
    case 108:return textCommands(v.text||"",108,408);
    case 355:return scriptCommands(v.script||"");
    case 102:{
      const choices=String(v.options||"Sí\nNo").split(/\r?\n/).map(x=>x.trim()).filter(Boolean).slice(0,4);
      if(!choices.length)throw new Error("Incluye al menos una elección.");
      return [ncmd(102,[choices,0]),...choices.map((x,i)=>ncmd(402,[i,x])),ncmd(404,[])];
    }
    case 111:return[ncmd(111,[12,String(v.condition||"true")]),ncmd(411),ncmd(412)];
    case 112:return[ncmd(112),ncmd(413)];
    case 103:return[ncmd(code,[num("variable",1),num("digits",1,8)])];
    case 104:return[ncmd(code,[num("position",0,2),0])];
    case 105:return[ncmd(code,[num("variable",1)])];
    case 106:return[ncmd(code,[num("frames",0,9999)])];
    case 117:return[ncmd(code,[num("common",1)])];
    case 118:case 119:return[ncmd(code,[String(v.label||"")])];
    case 121:return[ncmd(code,[num("first",1),num("last",1),num("enabled",0,1)])];
    case 122:return[ncmd(code,[num("first",1),num("last",1),num("op",0,5),0,Number(v.value)||0])];
    case 123:return[ncmd(code,[String(v.letter||"A"),num("enabled",0,1)])];
    case 124:return[ncmd(code,[num("action",0,1),num("seconds",0,9999)])];
    case 125:return[ncmd(code,[0,0,num("amount",0)])];
    case 126:return[ncmd(code,[num("id",1),0,0,num("quantity",0)])];
    case 201:return[ncmd(code,[0,num("map",1),num("x"),num("y"),num("direction",0,8),num("fade",0,1)])];
    case 207:return[ncmd(code,[num("target",-1,9999),num("animation",1)])];
    case 223:return[ncmd(code,[{__class:"Tone",values:[num("r",-255,255),num("g",-255,255),num("b",-255,255),num("gray",0,255)]},num("frames",0)])];
    case 225:return[ncmd(code,[num("power",1,9),num("speed",1,9),num("frames",0)])];
    case 231:return[ncmd(code,[num("id",1),String(v.file||""),0,0,num("x"),num("y"),100,100,num("opacity",0,255),0])];
    case 235:return[ncmd(code,[num("id",1)])];
    case 236:return[ncmd(code,[num("type",0,3),num("strength",0,9),num("frames",0)])];
    case 241:case 245:case 249:case 250:return[ncmd(code,[audio(v)])];
    case 242:case 246:return[ncmd(code,[num("seconds",0)])];
    default:
      if(SIMPLE_NO_PARAMS.has(code))return[ncmd(code)];
      if(!custom.trim())throw new Error("Este comando necesita parámetros JSON; revisa la estructura de RPG Maker XP.");
      const params=JSON.parse(custom);
      if(!Array.isArray(params))throw new Error("Los parámetros deben ser un arreglo JSON.");
      return[ncmd(code,params)];
  }
}

export const NATIVE_FIELDS=FIELD_DEFS;
export const NATIVE_SIMPLE=SIMPLE_NO_PARAMS;
export {compileNative};
