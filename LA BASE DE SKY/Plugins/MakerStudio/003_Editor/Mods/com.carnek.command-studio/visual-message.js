// Visual helpers for Essentials message editing. Read-only DOM preview (does not run Ruby).
export const COLOR_PRESETS=[
 {name:"Blanco",value:"#FFFFFF"},{name:"Negro",value:"#202331"},
 {name:"Rojo",value:"#F04E5B"},{name:"Azul",value:"#4298EF"},
 {name:"Verde",value:"#47B88B"},{name:"Amarillo",value:"#FFCF59"},
 {name:"Naranja",value:"#FE995D"},{name:"Morado",value:"#AD7FE8"},
 {name:"Rosa",value:"#F29DC8"},{name:"Celeste",value:"#6BD4E5"},
 {name:"Gris",value:"#A8AFB9"},{name:"Dorado",value:"#E9B95B"}
];
export function normalizedHex(value){
  const s=String(value||"").trim().replace(/^#/,"").toUpperCase();
  if(!/^[\dA-F]{6}$/.test(s))throw Error("El color necesita seis dígitos hexadecimales.");
  return s;
}
export function colorTag(value,text="texto",shadow=null){
  const main=normalizedHex(value);
  const chosen=String(text||"texto");
  if(shadow)return "<c3="+main+","+normalizedHex(shadow)+">"+chosen+"</c3>";
  return "<c="+main+">"+chosen+"</c>";
}
export function messagePosition(text){
 const prefix=String(text||"").match(/^\\(wu|wm|wd)/i);
 return prefix?prefix[1].toLowerCase():"wd";
}
export function setMessagePosition(text,position){
 if(!["wu","wm","wd"].includes(position))throw Error("Posición desconocida.");
 const rest=String(text||"").replace(/^\\(?:wu|wm|wd)/i,"");
 return "\\\\".replace(/\\\\/g,"\\")+position+rest;
}
export function colorType(directive){
 if(!directive)return "none";
 if(directive.kind==="color-index")return "index";
 if(directive.kind==="hex-color")return "rgb";
 if(directive.kind==="hex-pair")return "rgb-shadow";
 if(directive.kind==="hex8")return "legacy";
 return "none";
}
const MARKUP=/(<\/?c(?:3)?(?:=[^>]*?)?>|<br\s*\/?>|\\(?:v\[\d+\]|n\[[1-8]\]|ff?\[[^\]]*\]|w(?:tnp|t)?\[[^\]]*\]|ts\[[^\]]*\]|se\[[^\]]*\]|me\[[^\]]*\]|(?:wu|wm|wd|pn|pm|pg|pog|cn|pt|op|cl|sh)|c\[\d+\]|b|r|n|\.|\||!|\^)|<[^>]+>)/gi;
export const WINDOW_COLOR_HINTS=["#FFFFFF","#7D83DA","#E4787E","#62B8D8","#80BF92","#F8BC5C","#B289CB","#DCB39A","#919FB4","#6AD0BD","#EA8BBB","#C4C4C4","#202737"];
export function previewData(source){
 const text=String(source??""),parts=[];
 let pos=messagePosition(text),color="#FFFFFF",shadow="",screen="normal",explicit=false;
 const badges=[],unknownTokens=new Set();
 function push(value){
   if(!value)return;
   const last=parts[parts.length-1];
   if(last&&last.color===color&&last.shadow===shadow&&last.screen===screen&&last.explicit===explicit)last.text+=value;
   else parts.push({text:value,color,shadow,screen,explicit});
 }
 const split=text.split(MARKUP);
 for(const token of split){
   if(!token)continue;
   if(!/^(?:<|\\)/.test(token)){push(token);continue;}
   const lower=token.toLowerCase();
   let m=token.match(/^<c(?:=)([0-9a-f]{6,8})>$/i);
   if(m){color="#"+m[1].slice(0,6);shadow="";explicit=true;continue;}
   m=token.match(/^<c3=([0-9a-f]{6,8}),([0-9a-f]{6,8})>$/i);
   if(m){color="#"+m[1].slice(0,6);shadow="#"+m[2].slice(0,6);explicit=true;continue;}
   if(/^<\/c(?:3)?>$/i.test(token)){color="#FFFFFF";shadow="";explicit=false;continue;}
   m=token.match(/^\\c\[(\d+)\]$/i);
   if(m){color=WINDOW_COLOR_HINTS[Number(m[1])%WINDOW_COLOR_HINTS.length];explicit=true;badges.push("Color numerado: depende del marco");continue;}
   if(/^\\b$/i.test(token)){color="#5BA4FA";explicit=true;continue;}
   if(/^\\r$/i.test(token)){color="#F16D82";explicit=true;continue;}
   if(/^\\pg$/i.test(token)||/^\\pog$/i.test(token)){color="#E28CA6";badges.push("Color según jugador");continue;}
   if(/^\\pn$/i.test(token)){push("NOMBRE");continue;}
   if(/^\\pm$/i.test(token)){push("₽ 1.000");continue;}
   if(/^\\v\[\d+\]$/i.test(token)){push("VALOR");continue;}
   if(/^\\n$/i.test(token)||/^<br\s*\/?>$/i.test(token)){push("\n");continue;}
   if(/^\\n\[[1-8]\]$/i.test(token)){push("ACTOR");continue;}
   m=token.match(/^\\w(u|m|d)$/i);
   if(m){pos="w"+m[1].toLowerCase();continue;}
   if(/^\\(?:ff?|se|me|ts|w(?:tnp|t)?)\[/i.test(token)){
    const label=/^\\ff?\[/i.test(token)?"Rostro":/^\\se\[/i.test(token)?"Sonido SE":/^\\me\[/i.test(token)?"Fanfarria":/^\\ts\[/i.test(token)?"Velocidad":"Espera";
    badges.push(label+" "+token);continue;
   }
   if(/^\\(?:!|\.|\||\^)$/i.test(token)){badges.push("Pausa "+token);continue;}
   if(/^<b>$/i.test(token)){screen="bold";continue;}
   if(/^<\/b>$/i.test(token)){screen="normal";continue;}
   if(/^<(?:i|u|s|ac|al|ar|o|fs|fn|c2)/i.test(token)){unknownTokens.add(token);continue;}
   if(/^<icon=/i.test(token)){push("▧");badges.push("Icono");continue;}
   if(/^\\(?:cn|pt|g)$/i.test(token)){badges.push("Ventana auxiliar");continue;}
   if(/^\\(?:cl|op|sh)$/i.test(token)){badges.push("Transición de mensaje");continue;}
   unknownTokens.add(token);
 }
 return {position:pos,parts,badges:[...new Set(badges)].slice(0,5),
   unsupported:[...unknownTokens].slice(0,6),
   approximated:badges.some(x=>x.includes("depende")||x.includes("jugador"))};
}
export function renderMessagePreview(host,text){
 host.replaceChildren();
 const data=previewData(text);
 const stage=document.createElement("div");stage.className="csb-dialog-stage "+data.position;
 stage.setAttribute("aria-label","Previsualización esquemática de la ventana en el mapa");
 const wallpaper=document.createElement("div");wallpaper.className="csb-dialog-scenery";
 const windowBox=document.createElement("div");windowBox.className="csb-dialog-window";
 const title=document.createElement("small");title.textContent="VISTA ORIENTATIVA";title.className="csb-dialog-label";windowBox.append(title);
 const content=document.createElement("div");content.className="csb-dialog-letters";
 for(const segment of data.parts){
   const span=document.createElement("span");span.textContent=segment.text;
   span.style.color=segment.color;
   if(!segment.explicit)span.dataset.csbDefault="1";
   if(segment.shadow)span.style.textShadow="1px 1px 0 "+segment.shadow;
   if(segment.screen==="bold")span.style.fontWeight="bold";
   content.append(span);
 }
 if(!data.parts.length)content.textContent="Escribe un mensaje para verlo aquí";
 windowBox.append(content);stage.append(wallpaper,windowBox);host.append(stage);
 const summary=document.createElement("div");summary.className="csb-preview-badges";
 for(const label of data.badges){const item=document.createElement("span");item.textContent=label;summary.append(item);}
 host.append(summary);
 return data;
}
