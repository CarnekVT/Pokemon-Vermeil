const assert=require("node:assert/strict");
const fs=require("fs"),path=require("path"),root=path.resolve(__dirname,"..");
function grab(file,names){
 const src=fs.readFileSync(path.join(root,file),"utf8");
 const code=src.replace(/^\s*import\s+.*\n/gm,"").replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"").replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(code+";return {"+names.join(",")+"};")();
}
const messages=grab("messages-catalog.js",["DIRECTIVES","codeFor","previewPlain"]);
const actions=grab("smart-core.js",["ACTIONS","defaults","buildAction"]);
const wiki=grab("wiki-catalog.js",["WIKI","buildWiki"]);
const writer=grab("event-writer.js",["applyInsertion","isCompatible"]);
assert.equal(messages.DIRECTIVES.length,65);
assert.ok(wiki.WIKI.length>=76);
assert.ok(actions.ACTIONS.length>=29);
const special=["\\PN","\\PM","\\v[1]","\\!","\\wt[20]","\\ts[3]","\\ff[Hero]","\\se[Door exit]","<c=FFB700>texto</c>"];
for(const code of special)assert.ok(messages.DIRECTIVES.some(x=>x.token===code),code);
assert.equal(messages.previewPlain("Hola, \\PN"),"Hola, NOMBRE");
for(const t of messages.DIRECTIVES)assert.ok(messages.codeFor(t).length>0);
const problem=[];
for(const action of actions.ACTIONS){
 try{const list=actions.buildAction(action.id,actions.defaults(action));assert.ok(list.length&&list.every(x=>Number.isInteger(x.code)&&Array.isArray(x.parameters)));}
 catch(e){problem.push(action.id+": "+e.message);}
}
assert.deepEqual(problem,[]);
for(const w of wiki.WIKI)assert.ok(wiki.buildWiki(w,Object.fromEntries(w.args.map(x=>[x[0],x[3]]))).length);
let original={id:3,pages:[{list:[{code:101,parameters:["Original"],indent:0},{code:0,parameters:[],indent:0}]},{list:[{code:101,parameters:["No tocar"],indent:0},{code:0,parameters:[],indent:0}]}]};
let current=JSON.parse(JSON.stringify(original));
const ctx={events:{list:()=>[{id:3,name:"NPC"}],getFull:()=>JSON.parse(JSON.stringify(current)),createCommand:(code,params)=>({code,parameters:params,indent:0}),validateEvent:()=>({valid:true,errors:[]}),update:(_m,e)=>current=e}};
assert.equal(writer.isCompatible(ctx),true);
writer.applyInsertion(ctx,{mapId:2,eventId:3,pageIndex:0,position:"end",commands:[{code:101,indent:0,parameters:["Nuevo"]}]});
assert.equal(current.pages[0].list[0].parameters[0],"Original");
assert.deepEqual(current.pages[1],original.pages[1]);
console.log("Command Studio 0.5 PASS: "+actions.ACTIONS.length+" acciones, "+messages.DIRECTIVES.length+" controles de mensaje, "+wiki.WIKI.length+" recetas.");
