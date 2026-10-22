// Text safety: control sequences and Essentials markup are protected from editing.
const CONTROL=/(\\(?:[A-Za-z@!.\|^]+(?:\[[^\]\r\n]*\])?|[0-9]+)|<\/?[A-Za-z][^>\r\n]*>|&(?:amp|lt|gt|quot|apos);)/g;
const DICTIONARY={
 "pokemon":"Pokémon","pokemons":"Pokémon","pokenon":"Pokémon","pokemón":"Pokémon",
 "pokebola":"Poké Ball","pokeball":"Poké Ball","pokebolas":"Poké Balls",
 "tambien":"también","mas":"más","facil":"fácil","dificil":"difícil",
 "aqui":"aquí","alli":"allí","ahi":"ahí","aca":"acá","despues":"después",
 "rapido":"rápido","quizas":"quizás","asi":"así","siempre":"siempre",
 "dialogo":"diálogo","dialogos":"diálogos","opcion":"opción","opciones":"opciones",
 "mision":"misión","misiones":"misiones","evolucion":"evolución",
 "canion":"cañón","senal":"señal","energia":"energía","tecnologia":"tecnología",
 "animacion":"animación","musica":"música","también":"también",
 "tendre":"tendré","sera":"será","estas":"estás","estare":"estaré",
 "habra":"habrá","podras":"podrás","sabras":"sabrás",
 "vamonos":"vámonos","sigeme":"sígueme","proxima":"próxima",
 "pocion":"poción","superpocion":"superpoción","maxima":"máxima",
 "campéon":"campeón","campeon":"campeón","cuestion":"cuestión"
};
const NO_AUTO=new Set(["mas","estas","sera","si","tu","el","solo","aun"]);
function protect(text){
 const output=[];let start=0;
 for(const m of String(text??"").matchAll(CONTROL)){
  if(m.index>start)output.push({kind:"prose",start,end:m.index,value:text.slice(start,m.index)});
  output.push({kind:"code",start:m.index,end:m.index+m[0].length,value:m[0]});
  start=m.index+m[0].length;
 }
 if(start<text.length)output.push({kind:"prose",start,end:text.length,value:text.slice(start)});
 return output;
}
export function checkText(text,extraWords=[]){
 const allow=new Set(extraWords.map(s=>s.toLocaleLowerCase("es")));
 const issues=[];
 for(const p of protect(String(text??""))){
  if(p.kind!=="prose")continue;
  const words=p.value.matchAll(/[\p{L}]+/gu);
  for(const match of words){
   const original=match[0],low=original.toLocaleLowerCase("es");
   if(allow.has(low)||NO_AUTO.has(low)||!DICTIONARY[low])continue;
   const suggestion=DICTIONARY[low];
   if(original.toLocaleLowerCase("es")===suggestion.toLocaleLowerCase("es"))continue;
   const replacement=/^\p{Lu}/u.test(original)?suggestion[0].toUpperCase()+suggestion.slice(1):suggestion;
   issues.push({start:p.start+match.index,end:p.start+match.index+original.length,original,suggestion:replacement,why:"Ortografía y acentuación"});
  }
 }
 return issues;
}
export function applyCorrection(text,issue){
 if(text.slice(issue.start,issue.end)!==issue.original)throw Error("El texto cambió. Revisa la corrección.");
 return text.slice(0,issue.start)+issue.suggestion+text.slice(issue.end);
}
export function autocorrectText(text,extraWords=[]){
 const changes=checkText(text,extraWords);
 let output=String(text);
 for(const issue of changes.slice().reverse())output=applyCorrection(output,issue);
 return{result:output,changes};
}
export function lintMessage(text){
 const warnings=[];
 const s=String(text||"");
 for(const tag of ["c","c3","b","i","u"]){
  const opens=[...s.matchAll(new RegExp("<"+tag+"(?:=[^>]+)?>","gi"))].length;
  const closes=[...s.matchAll(new RegExp("</"+tag+">","gi"))].length;
  if(opens!==closes)warnings.push("Revisa la etiqueta <"+tag+">: "+opens+" aperturas y "+closes+" cierres.");
 }
 if(s.split("\n").some(line=>line.length>130))warnings.push("Hay líneas largas que podrían desbordar el cuadro de diálogo.");
 return warnings;
}
export function buildMessageEventCommands(text,options={}){
 const arr=[],name=String(options.speaker||"").trim();
 if(name){
  if(name.length>80||/[\r\n]/.test(name))throw Error("Nombre de hablante demasiado largo.");
  const escaped=name.replace(/\\/g,"\\\\").replace(/'/g,"\\\\'");
  arr.push({code:355,indent:0,parameters:["NameBox.load('"+escaped+"')"]});
 }
 for(const [i,line] of String(text??"").replace(/\r/g,"").split("\n").entries())
  arr.push({code:i?401:101,indent:0,parameters:[line]});
 if(name)arr.push({code:355,indent:0,parameters:["NameBox.dispose"]});
 return arr;
}
