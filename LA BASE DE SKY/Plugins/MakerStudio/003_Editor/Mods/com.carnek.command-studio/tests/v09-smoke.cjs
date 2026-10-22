"use strict";
const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const base=path.resolve(__dirname,"..");
function requireSource(name,exports){
 const src=fs.readFileSync(path.join(base,name),"utf8")
  .replace(/^\s*import\s+.*\n/gm,"")
  .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
  .replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(src+";return {"+exports.join(",")+"};")();
}
for(const f of ["event-browser.js","friendly-ui.js","message-ui.js","skin-preview.js","next-style.js"]){
 assert.doesNotThrow(()=>requireSource(f,[]),"Sintaxis "+f);
}
const writer=requireSource("event-writer.js",["availableInsertionPoints","applyInsertion","previewInsertion"]);
const gift=requireSource("pokemon-gift.js",["giftFields","giftDefaults","giftCheck","buildGiftRuby"]);
const text=requireSource("text-tools.js",["checkText","autocorrectText","buildMessageEventCommands"]);
const audit=requireSource("function-audit.js",["classifyReference"]);
assert.ok(gift.giftFields(true).length>=35);
const options=gift.giftDefaults(true);
options.species="RIOLU";options.level=5;options.shiny="super";options.nature="JOLLY";options.move1="TACKLE";options.ivHP=31;options.evATTACK=252;
const generated=gift.buildGiftRuby(options,true);
assert.match(generated,/pkmn = Pokemon.new\(:RIOLU, 5\)/);
assert.match(generated,/pkmn.super_shiny = true/);
assert.match(generated,/pkmn.iv\[:HP\] = 31/);
assert.ok(generated.indexOf("if pbAddPokemon")<generated.indexOf("$game_self_switches",generated.indexOf("if pbAddPokemon")));
assert.ok(gift.giftCheck({...options,evDEFENSE:252,evSPEED:252}).length,"EV overflow must be blocked");
const correction=text.autocorrectText("Hola \\PN, aqui hay una pocion <c=FF9900>tambien</c>.");
assert.equal(correction.result,"Hola \\PN, aquí hay una poción <c=FF9900>también</c>.");
const namebox=text.buildMessageEventCommands("Hola",{"speaker":"\\PN"});
assert.equal(namebox[0].code,355);
assert.match(namebox[0].parameters[0],/NameBox.load/);
assert.equal(namebox.at(-1).parameters[0],"NameBox.dispose");
const list=[
 {code:101,indent:0,parameters:["Hola"]},{code:401,indent:0,parameters:["más"]},
 {code:111,indent:0,parameters:[12,"true"]},
 {code:355,indent:1,parameters:["puts 1"]},{code:655,indent:1,parameters:["puts 2"]},
 {code:411,indent:0,parameters:[]},{code:101,indent:1,parameters:["No"]},
 {code:412,indent:0,parameters:[]},{code:0,indent:0,parameters:[]}
];
const slots=writer.availableInsertionPoints(list);
assert.ok(!slots.some(p=>p.index===1),"Do not split continuous text");
assert.ok(!slots.some(p=>p.index===4),"Do not split continuous script");
assert.ok(slots.some(p=>p.index===5&&p.indent===1),"Insert inside branch");
let state={id:5,pages:[{list:JSON.parse(JSON.stringify(list))},{list:[{code:101,indent:0,parameters:["no tocar"]},{code:0,indent:0,parameters:[]}]}]};
const ctx={events:{getFull:()=>JSON.parse(JSON.stringify(state)),createCommand:(code,parameters)=>({code,parameters,indent:0}),
 validateEvent:()=>({valid:true,errors:[]}),update:(map,event)=>state=event}};
writer.applyInsertion(ctx,{mapId:7,eventId:5,pageIndex:0,position:5,commands:[{code:101,parameters:["Insertado"],indent:0}]});
assert.equal(state.pages[0].list[5].indent,1);
assert.equal(state.pages[1].list[0].parameters[0],"no tocar");
assert.throws(()=>writer.previewInsertion(ctx,{mapId:7,eventId:5,pageIndex:0,position:1,commands:[{code:101,parameters:["X"],indent:0}]}));
assert.equal(audit.classifyReference({template:"pbJukebox()","note":"Sistema opcional"},null).state,"plugin");
console.log("Command Studio 0.9 smoke OK: eventos seguros, regalo configurable, entrega única, NameBox, corrección y detección.");
