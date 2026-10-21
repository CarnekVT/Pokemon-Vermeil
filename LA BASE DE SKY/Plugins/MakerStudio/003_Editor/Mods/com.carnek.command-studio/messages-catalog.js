// Command Studio – message directives verified against:
// Essentials Docs /Messages, LBDS /mensajes and Vermeil Data/Scripts/018_Objects and windows/012_Messages.rb.
// Message directives are NOT Ruby function calls. They belong inside a message string.
export const SOURCES={
 essentials:"https://essentialsdocs.fandom.com/wiki/Messages",
 lbds:"https://la-base-de-sky-wiki-1070f3.gitlab.io/pages/mensajes.html",
 local:"Data/Scripts/018_Objects and windows/012_Messages.rb"
};
const d=(category,title,token,description,opts={})=>({id:"msg-"+category+"-"+title.toLowerCase().replace(/\W+/g,"-"),category,title,token,description,
 type:"insert",level:"beginner",source:"essentials",...opts});
export const DIRECTIVES=[
 d("Variables","Nombre del jugador","\\PN","Se sustituye por el nombre del jugador.",{level:"beginner"}),
 d("Variables","Dinero actual","\\PM","Muestra el dinero del jugador dentro del texto."),
 d("Variables","Valor de una variable","\\v[1]","Muestra el contenido de una variable de RPG Maker.",{placeholder:"1",parameter:"Número de variable",kind:"positive-integer"}),
 d("Variables","Nombre de un actor RMXP","\\n[1]","Muestra el nombre de un actor de la base RPG Maker (IDs 1–8).",{parameter:"Número de actor",kind:"actor-index"}),
 d("Variables","Letra según sexo del jugador","\\@","Usa 'o' o 'a' según el personaje jugador.",{source:"local"}),
 d("Variables","Terminación femenina opcional","\\@a","Añade 'a' únicamente para un personaje jugador femenino.",{source:"local"}),
 d("Formato","Salto de línea","\\n","Fuerza un salto dentro del mismo mensaje."),
 d("Formato","Negrita","<b>texto</b>","Resalta una palabra con negrita.",{wrap:true}),
 d("Formato","Cursiva","<i>texto</i>","Aplica cursiva a un fragmento.",{wrap:true}),
 d("Formato","Subrayado","<u>texto</u>","Subraya un fragmento.",{wrap:true}),
 d("Formato","Tachado","<s>texto</s>","Tacha un fragmento.",{wrap:true}),
 d("Formato","Contorno","<outln>texto</outln>","Dibuja contorno alrededor del texto.",{wrap:true}),
 d("Formato","Contorno grueso","<outln2>texto</outln2>","Usa un contorno más grueso.",{wrap:true}),
 d("Formato","Cambiar fuente","<fn=Pokemon GB>texto</fn>","Selecciona temporalmente una fuente instalada.",{parameter:"Nombre de fuente",kind:"tag-arg"}),
 d("Formato","Tamaño de fuente","<fs=22>texto</fs>","Modifica el tamaño de fuente.",{parameter:"Tamaño",kind:"font-size"}),
 d("Formato","Opacidad","<o=255>texto</o>","Modifica la opacidad del texto (0–255).",{parameter:"Opacidad",kind:"opacity"}),
 d("Colores","Azul","\\b","Color tradicional del texto masculino."),
 d("Colores","Rojo","\\r","Color tradicional del texto femenino."),
 d("Colores","Color según jugador","\\pg","Azul o rojo según el sexo del jugador."),
 d("Colores","Color contrario al jugador","\\pog","Color opuesto al usado para el jugador."),
 d("Colores","Elegir color (0–12)","\\c[3]","Cambia al color numerado, definido por la ventana.",{parameter:"Índice de color",kind:"color-index"}),
 d("Colores","Color base y sombra 15-bit","\\[043c3aff]","Colores de texto y sombra codificados en hexadecimal 15-bit.",{level:"advanced",parameter:"8 dígitos hex",kind:"hex8"}),
 d("Colores","Color específico RGB","<c=FFB700>texto</c>","Color hexadecimal RGB, opcionalmente con transparencia.",{level:"advanced",parameter:"RRGGBB o RRGGBBAA",kind:"hex-color",wrap:true}),
 d("Colores","RGB y sombra","<c3=FFB700,404040>texto</c3>","Dos colores hexadecimales (base y sombra).",{level:"advanced",parameter:"RRGGBB,RRGGBB",kind:"hex-pair",wrap:true}),
 d("Colores","Colores 15-bit sobre tramo","<c2=043c3aff>texto</c2>","Color 15-bit de texto y sombra aplicado a un tramo.",{level:"advanced",parameter:"8 dígitos hex",kind:"hex8",wrap:true}),
 d("Alineación","Centrar párrafo","<ac>texto</ac>","Centra un tramo de texto.",{wrap:true}),
 d("Alineación","Izquierda","<al>texto</al>","Alinea un tramo a la izquierda.",{wrap:true}),
 d("Alineación","Derecha","<ar>texto</ar>","Alinea un tramo a la derecha.",{wrap:true}),
 d("Alineación","Texto a la derecha en línea","<r>","Alinea a la derecha desde este punto."),
 d("Ventana","Ventana arriba","\\wu","Coloca la ventana en la parte superior."),
 d("Ventana","Ventana al centro","\\wm","Coloca la ventana en el centro."),
 d("Ventana","Ventana abajo","\\wd","Coloca la ventana abajo."),
 d("Ventana","Cambiar marco","\\w[narration]","Cambia el marco desde Graphics/Windowskins.",{parameter:"Nombre de windowskin",kind:"name"}),
 d("Ventana","Cartel","\\sign[sign]","Ventana tipo cartel con apertura y cierre.",{parameter:"Nombre de windowskin",kind:"name"}),
 d("Ventana","Número de líneas","\\l[3]","Modifica cuántas líneas muestra la ventana.",{parameter:"Número de líneas",kind:"positive-integer"}),
 d("Ventana","Abrir con animación","\\op","Desliza la ventana al entrar."),
 d("Ventana","Cerrar con animación","\\cl","Desliza la ventana al terminar."),
 d("Ventana","Cerrar con sonido","\\cl[Door exit]","Cierra con un sonido.",{parameter:"Archivo SE",kind:"name"}),
 d("Velocidad","Velocidad de texto","\\ts[3]","Valor mayor = texto más lento.",{parameter:"Velocidad",kind:"nonnegative-integer"}),
 d("Velocidad","Texto instantáneo","\\ts[]","Muestra instantáneamente."),
 d("Velocidad","Pausa interactiva","\\!","Muestra una pausa para que el jugador confirme.",{source:"local"}),
 d("Velocidad","Pausa breve (0,25 s)","\\.","Espera aproximadamente un cuarto de segundo."),
 d("Velocidad","Pausa larga (1 s)","\\|","Espera aproximadamente un segundo."),
 d("Velocidad","Pausa en fotogramas","\\wt[20]","Espera la duración indicada /20 segundos.",{parameter:"Fotogramas a 20 fps",kind:"nonnegative-integer"}),
 d("Velocidad","Esperar y cerrar solo","\\wtnp[20]","Espera un intervalo y continúa sin esperar confirmación.",{parameter:"Fotogramas a 20 fps",kind:"nonnegative-integer"}),
 d("Velocidad","Continuar sin pausa final","\\^","Al terminar el texto, continúa automáticamente.",{source:"local"}),
 d("Sonido","Reproducir efecto SE","\\se[Door exit]","Reproduce un archivo en Audio/SE.",{parameter:"Nombre del SE",kind:"name"}),
 d("Sonido","Reproducir ME","\\me[Item get]","Reproduce música de efecto.",{parameter:"Nombre del ME",kind:"name"}),
 d("Extras","Mostrar dinero aparte","\\G","Abre una ventana temporal con dinero."),
 d("Extras","Mostrar monedas","\\CN","Abre una ventana con monedas."),
 d("Extras","Mostrar puntos de batalla","\\pt","Muestra el saldo de puntos de batalla.",{source:"local"}),
 d("Extras","Imagen al lado del texto","\\f[Officer]","Muestra una imagen de Graphics/Pictures.",{parameter:"Nombre de imagen",kind:"name"}),
 d("Extras","Cara 96×96","\\ff[Hero]","Muestra un rostro desde Graphics/Faces.",{parameter:"Nombre de rostro",kind:"name"}),
 d("Extras","Cara con variante","\\ff[Hero,2]","Extrae otro cuadro de la cuadrícula de rostros.",{parameter:"Nombre, índice",kind:"face-variant"}),
 d("Extras","Icono en la frase","<icon=POTION>","Icono dentro del mensaje desde Graphics/Icons.",{parameter:"Nombre de icono",kind:"name"}),
 d("Extras","Mensaje de énfasis","\\sh","Usa el marco especial de exclamación si existe.",{source:"local"}),
 d("Avanzado","Elecciones compactas","\\ch[1,-1,Sí,No]","Sintaxis avanzada de opciones embebidas en el mensaje.",{source:"local",level:"advanced",parameter:"Variable,cancelar,opciones",kind:"expression"})
];

DIRECTIVES.push(
 d("Formato","Barra invertida literal","\\\\","Introduce el carácter de barra invertida en lugar de iniciar un control."),
 d("Formato","Apóstrofe HTML","&apos;","Inserta un apóstrofe en una cadena de texto."),
 d("Formato","Menor que HTML","&lt;","Inserta el símbolo menor que."),
 d("Formato","Mayor que HTML","&gt;","Inserta el símbolo mayor que."),
 d("Formato","Ampersand HTML","&amp;","Inserta el símbolo &."),
 d("Formato","Comillas HTML","&quot;","Inserta comillas dobles."),
 d("Formato","Salto de línea HTML","<br />","Fuerza una nueva línea usando etiqueta."),
 d("Velocidad","Pausa interactiva alternativa","\\1","Código alternativo de pausa, recogido en Essentials Docs y el preprocess del juego.",{level:"advanced",source:"local"})
);

export const GROUPS=[...new Set(DIRECTIVES.map(x=>x.category))];
export function codeFor(d,value=null,selectedText="texto"){
 let result=d.token;
 if(value!==null&&d.parameter){
  const v=String(value).trim();
  if(!v)throw Error("Introduce "+d.parameter+".");
  if(["positive-integer","nonnegative-integer","color-index","actor-index","opacity","font-size"].includes(d.kind)){
   if(!/^\d+$/.test(v))throw Error("Introduce un número entero.");
   const n=Number(v),min=d.kind==="nonnegative-integer"?0:1,max=d.kind==="color-index"?12:d.kind==="actor-index"?8:d.kind==="opacity"?255:d.kind==="font-size"?99:99999;
   if(n<min||n>max)throw Error("Valor fuera del rango permitido: "+min+"–"+max+".");
  }
  if(d.kind==="hex8"&&!/^[0-9a-fA-F]{8}$/.test(v))throw Error("Debe contener exactamente 8 caracteres hexadecimales.");
  if(d.kind==="hex-color"&&!/^(?:[a-fA-F0-9]{6}|[a-fA-F0-9]{8})$/.test(v))throw Error("Color hex de 6 u 8 dígitos.");
  if(d.kind==="hex-pair"&&!/^[a-fA-F0-9]{6,8},[a-fA-F0-9]{6,8}$/.test(v))throw Error("Utiliza DOS colores RGB hex separados por coma.");
  if(d.kind==="name"&&/[\[\]\r\n]/.test(v))throw Error("Nombre de archivo inválido.");
  if(d.kind==="tag-arg")result=result.replace("Pokemon GB",v);
  else if(d.kind==="font-size")result=result.replace("=22","="+v);
  else if(d.kind==="opacity")result=result.replace("=255","="+v);
  else if(d.kind==="hex-pair")result=result.replace("FFB700,404040",v);
  else if(d.kind==="hex-color")result=result.replace("FFB700",v);
  else if(d.kind==="hex8")result=result.replace("043c3aff",v);
  else if(d.kind==="face-variant")result="\\ff["+v+"]";
  else if(d.kind==="expression")result="\\ch["+v+"]";
  else result=result.replace(/\[[^\]]*\]/,"["+v+"]").replace(/<icon=[^>]*>/,"<icon="+v+">");
 }
 if(d.wrap)result=result.replace(/texto/,String(selectedText||"texto"));
 return result;
}
export function previewPlain(text){
 return String(text||"")
 .replace(/\\pn/gi,"NOMBRE")
 .replace(/\\pm/gi,"$1,000")
 .replace(/\\v\[\d+\]/gi,"[variable]")
 .replace(/\\n(?!\[)/gi,"\n")
 .replace(/\\(?:wu|wm|wd|op|cl|pg|pog|b|r|g|cn|pt|sh|ts\[[^\]]*]|w\[[^\]]*]|l\[[^\]]*]|wt(?:np)?\[[^\]]*]|se\[[^\]]*]|me\[[^\]]*]|ff?\[[^\]]*]|\!|\.|\||\^)/gi,"")
 .replace(/<\/?(?:b|i|u|s|outln2?|ac|al|ar|fn[^>]*|fs[^>]*|o[^>]*|c2?[^>]*|c3[^>]*)>/gi,"")
 .replace(/<icon=[^>]*>/gi,"[icono]");
}
