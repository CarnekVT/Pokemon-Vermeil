"use strict";
const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const root=path.resolve(__dirname,"..");
const read=file=>fs.readFileSync(path.join(root,file),"utf8");
const strip=s=>s.replace(/^\s*import\s+.*\n/gm,"")
 .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
 .replace(/export\s*\{[^}]*\};?/g,"");
function extract(file,names){return new Function(strip(read(file))+";return {"+names.join(",")+"};")();}
const core=extract("smart-core.js",["ACTIONS","BY_ID","defaults","buildAction","validate","smartSearch"]);
const wiki=extract("wiki-catalog.js",["WIKI","buildWiki"]);
const texts=extract("messages-catalog.js",["DIRECTIVES","GROUPS","codeFor","SOURCES"]);
const gift=extract("pokemon-gift.js",["enhancePokemonActions","POKEMON_GROUPS","giftCheck"]);
const visual=extract("visual-message.js",["COLOR_PRESETS","colorTag","renderMessagePreview","normalizedHex","setMessagePosition","messagePosition","colorType","WINDOW_COLOR_HINTS"]);
assert.ok(core.ACTIONS.length>=39);
assert.ok(wiki.WIKI.length>=134);
assert.ok(texts.DIRECTIVES.length>=65);
for(const a of core.ACTIONS)assert.ok(core.buildAction(a.id,core.defaults(a)).length,a.id);
for(const script of ["friendly-ui.js","message-ui.js","ux-style.js"]){
 assert.doesNotThrow(()=>new Function(strip(read(script))),script+" must compile");
}
class MockNode{
 constructor(tag){this.tagName=tag;this.children=[];this.style={};this.dataset={};this.listeners={};this.className="";this.value="";this.selectionStart=0;this.selectionEnd=0;this.disabled=false;this.attrs={};
 const classes=new Set();this.classList={toggle:(x,on)=>on?classes.add(x):classes.delete(x),add:x=>classes.add(x),remove:x=>classes.delete(x),contains:x=>classes.has(x)};}
 set textContent(v){this._text=String(v);this.children=[];}
 get textContent(){return this._text??this.children.map(x=>x.textContent).join("");}
 get childNodes(){return this.children;}get firstChild(){return this.children[0]||null;}
 append(...nodes){this.children.push(...nodes);}replaceChildren(...nodes){this.children=[];this.append(...nodes);}
 addEventListener(type,fn){(this.listeners[type]??=[]).push(fn);}removeEventListener(type,fn){this.listeners[type]=(this.listeners[type]||[]).filter(x=>x!==fn);}
 dispatchEvent(e){for(const f of this.listeners[e.type]||[])f(e);this["on"+e.type]?.(e);}
 setAttribute(key,val){this.attrs[key]=val;}
 setRangeText(text,start,end){this.value=this.value.slice(0,start)+text+this.value.slice(end);this.selectionStart=this.selectionEnd=start+text.length;}
 setSelectionRange(start,end){this.selectionStart=start;this.selectionEnd=end;}
 querySelectorAll(tag){return walk(this).filter(x=>x.tagName===tag);}focus(){}
}
function walk(node){return[node,...node.children.flatMap(walk)];}
const doc={createElement:tag=>new MockNode(tag),addEventListener(){},removeEventListener(){}};
const win={addEventListener(){},removeEventListener(){}};
const props={...core,...wiki,...texts,...gift,availableInsertionPoints:()=>[{index:0},{index:1}],describeCommand:()=>"Texto",createEventBrowser:()=>({dispose(){},refresh(){}}),classifyReference:()=>({state:"pending",label:"Pendiente",reason:""}),auditProject:async()=>({indexed:{methods:[],report:{found:0,errors:[]}}}),loadPBS:async()=>({ids:{}}),classifySymbolHint:()=>"",
 activeMapId:()=>1,isCompatible:()=>true,eventChoices:()=>[{id:2,name:"Profesor",x:2,y:5}],
 pageChoices:()=>[{index:0,count:2}],applyInsertion:()=>({inserted:1}),
 mountAdvanced:()=>()=>{},mountVisualMessageEditor:({host})=>host.append(new MockNode("fake-message")),
 installWorkspaceFullscreen:()=>()=>{},EXTRA_CSS:"",UX_CSS:"",NEXT_CSS:""};
const propNames=Object.keys(props);
const beginner=new Function("document","window",...propNames,strip(read("friendly-ui.js"))+";return {mountFriendly};")(doc,win,...propNames.map(k=>props[k]));
const host=new MockNode("host"),ctx={editor:{activeMapId:()=>1},ui:{showToast:()=>{}}};
const clean=beginner.mountFriendly(ctx,host);
const buttons=()=>walk(host).filter(x=>x.tagName==="button");
function tap(match){const b=buttons().find(x=>match(x));assert.ok(b,"Button missing");b.onclick();}
assert.equal(walk(host).filter(x=>x.className==="tile").length,6,"Only six starter tasks");
assert.equal(walk(host).filter(x=>x.className==="csb-task-result").length,0,"No long list until expanded");
tap(x=>x.textContent.includes("Explorar más tareas"));
assert.equal(walk(host).filter(x=>x.className==="csb-task-result").length,10,"Paginated task list");
tap(x=>x.textContent.includes("Ocultar tareas"));
tap(x=>x.className==="tile");
assert.ok(walk(host).some(x=>x.tagName==="h3"&&x.textContent.includes("NPC con diálogo")));
tap(x=>x.textContent.includes("Ver resultado"));
assert.ok(walk(host).some(x=>x.tagName==="h3"&&x.textContent.includes("Comprueba y añade")));
tap(x=>x.textContent.includes("Enciclopedia"));
assert.equal(walk(host).filter(x=>String(x.className).startsWith("csb-ref-item")).length,12,"Paginated wiki");
tap(x=>String(x.className).startsWith("csb-ref-item"));
assert.ok(buttons().some(x=>x.textContent.includes("Configurar esta función")));
clean();
const messageModule=new Function("document","Event",
 [read("messages-catalog.js"),read("visual-message.js"),read("text-tools.js"),read("message-ui.js")].map(strip).join("\n")+
 ";return mountVisualMessageEditor;")(doc,class Event{constructor(type){this.type=type}});
const hostMessage=new MockNode("host");let result="",commands=null;
messageModule({host:hostMessage,initialText:"¡Hola!",onTextChange:v=>result=v,onInsert:v=>commands=v,renderTarget:()=>{}});
const b=()=>walk(hostMessage).filter(x=>x.tagName==="button");
function click(accept){const item=b().find(accept);assert.ok(item,"UI control missing");item.onclick();}
const input=walk(hostMessage).find(x=>x.tagName==="textarea");
input.setSelectionRange(0,6);
click(x=>x.title?.startsWith("Color Rojo"));
assert.ok(result.includes("<c=F04E5B>¡Hola!</c>"));
click(x=>x.textContent.includes("Ventana"));
click(x=>x.dataset?.pos==="wu");
assert.ok(result.startsWith("\\wu"));
click(x=>x.textContent.includes("Pausas"));
click(x=>x.textContent==="Insertar ajuste");
assert.ok(result.includes("</c>\\wt[20]"),"Inserting after position change preserves tags");
click(x=>x.textContent.includes("Más efectos"));
assert.equal(walk(hostMessage).filter(x=>x.className==="csb-effect-row").length,10);
click(x=>x.textContent.includes("Añadir mensaje al evento"));
assert.ok(commands?.length);
console.log("Command Studio UX smoke passed: 6 starter tasks, 10 paged tasks, 12 wiki cards, 4 visual tool tabs, safe message editing");
