const fs=require("fs"),path=require("path"),assert=require("node:assert/strict");
const root=path.resolve(__dirname,"..");
function load(file,names){
 const code=fs.readFileSync(path.join(root,file),"utf8").replace(/^\s*import\s+.*\n/gm,"").replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"").replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(code+"\nreturn {"+names.join(",")+"};")();
}
(async()=>{
 const core=load("smart-core.js",["ACTIONS","defaults","buildAction","smartSearch","validate"]);
 const writer=load("event-writer.js",["applyInsertion","previewInsertion","isCompatible"]);
 const picker=load("picker-commands.js",["registerPickerCommands"]);
 const ui=load("smart-ui.js",[]);
 const wiki=load("wiki-catalog.js",["WIKI"]);
 assert.ok(core.ACTIONS.length>=25);
 assert.ok(wiki.WIKI.length>=60);
 for(const a of core.ACTIONS){
  const v=core.defaults(a),cmds=core.buildAction(a.id,v);
  assert.ok(cmds.length>0,a.id);
  assert.ok(cmds.every(c=>Number.isInteger(c.code)&&Array.isArray(c.parameters)),a.id);
 }
 assert.equal(core.smartSearch("curar equipo")[0].action.id,"heal");
 assert.equal(core.smartSearch("entrenador derrotado")[0].action.id,"trainer_once");
 const initial={id:3,name:"NPC",x:4,y:5,pages:[
  {trigger:0, list:[{code:101,parameters:["Original"],indent:0},{code:0,parameters:[],indent:0}]},
  {trigger:0,list:[{code:101,parameters:["Página 2"],indent:0},{code:0,parameters:[],indent:0}]}
 ]};
 let current=JSON.parse(JSON.stringify(initial)), updates=0;
 const ctx={events:{
  list:()=>[{id:3,name:"NPC",x:4,y:5,pages:2}],
  getFull:()=>JSON.parse(JSON.stringify(current)),
  createCommand:(code,parameters=[])=>({code,parameters,indent:0}),
  validateEvent:ev=>({valid:ev.pages.every(p=>p.list.every(x=>x.code>=0)),errors:[]}),
  update:(mapId,ev)=>{assert.equal(mapId,17);current=ev;updates++;}
 }};
 assert.equal(writer.isCompatible(ctx),true);
 const addition=core.buildAction("talk",{text:"¡Hola!\n¿Cómo estás?"});
 const preview=writer.previewInsertion(ctx,{mapId:17,eventId:3,pageIndex:0,position:"end",commands:addition});
 assert.equal(preview.added,2);
 assert.equal(current.pages[0].list[0].parameters[0],"Original","La vista previa no modifica el evento");
 writer.applyInsertion(ctx,{mapId:17,eventId:3,pageIndex:0,position:"end",commands:addition});
 assert.equal(updates,1);
 assert.equal(current.pages[0].list[0].parameters[0],"Original");
 assert.equal(current.pages[0].list.at(-1).code,401);
 assert.deepEqual(current.pages[1],initial.pages[1],"Página 2 intacta");
 const cond=core.buildAction("gift_item_once",core.defaults(core.ACTIONS.find(x=>x.id==="gift_item_once")));
 assert.doesNotThrow(()=>writer.previewInsertion(ctx,{mapId:17,eventId:3,pageIndex:1,position:"start",commands:cond}));
 assert.throws(()=>writer.applyInsertion(ctx,{mapId:17,eventId:3,pageIndex:99,position:"end",commands:addition}));
 const regs=[];
 picker.registerPickerCommands({events:{registerCommand:def=>{regs.push(def);return{};}}});
 assert.equal(regs.length,5);
 for(const def of regs){const params=Object.fromEntries((def.fields||[]).map(f=>[f.key,f.default]));
  const code=def.script(params);assert.ok(typeof code==="string"&&code.length>0);
  assert.deepEqual(def.parse(code),params,"Round trip "+def.id);
 }
 console.log("Command Studio 0.4 smoke OK:",core.ACTIONS.length,"actions,",wiki.WIKI.length,"Wiki entries,",regs.length,"native picker commands; event insert validated");
})().catch(e=>{console.error(e);process.exitCode=1});
