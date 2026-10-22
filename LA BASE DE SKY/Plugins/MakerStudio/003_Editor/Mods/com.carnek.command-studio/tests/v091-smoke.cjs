"use strict";
const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const root=path.resolve(__dirname,"..");
function load(file,vars){
 const src=fs.readFileSync(path.join(root,file),"utf8")
 .replace(/^\s*import\s+.*\n/gm,"")
 .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
 .replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(src+";return {"+vars.join(",")+"};")();
}
const skin=load("skin-preview.js",["skinLayout","drawSkin"]);
const sprites=load("sprite-crop.js",["spriteGrid","spriteCrop"]);
const messages=load("visual-message.js",["previewData"]);
for(const [w,h,expected] of [[192,128,"xp"],[128,128,"vx"],[96,48,"custom"],[80,48,"custom"],[80,80,"custom"],[48,48,"custom"]]){
 const layout=skin.skinLayout(w,h);
 assert.equal(layout?.format,expected,w+"x"+h);
 const calls=[];const ctx={drawImage:(...args)=>calls.push(args),clearRect(){},save(){},restore(){},set globalAlpha(v){},set imageSmoothingEnabled(v){}};
 skin.drawSkin(ctx,{width:w,height:h},400,110);
 assert.ok(calls.length>=9,"A background + 8 frame pieces must be drawn");
 if(w===96&&h===48)assert.deepEqual(calls[0].slice(1,5),[32,16,16,16],"HGSS source is 16x16 central tile");
}
assert.equal(sprites.spriteGrid(128,128,"NPC").cols,4);
assert.equal(sprites.spriteGrid(32,32,"$rock").cols,1);
const bytes=new Uint8Array(8*8*4);
bytes[(2*8+2)*4+3]=255;bytes[(5*8+6)*4+3]=255;
const box=sprites.spriteCrop({data:bytes,width:8,height:8},8,8);
assert.deepEqual([box.x,box.y,box.width,box.height],[2,2,5,4]);
const parts=messages.previewData("¡Hola! <c=FF0000>rojo</c> más").parts;
assert.equal(parts[0].explicit,false);
assert.equal(parts[1].explicit,true);
assert.equal(parts[2].explicit,false);
const browser=fs.readFileSync(path.join(root,"event-browser.js"),"utf8");
assert.match(browser,/groupCommands\(commands\)/);
assert.match(browser,/drawEventSprite/);
assert.match(browser,/createEventBrowser/);
const msgUI=fs.readFileSync(path.join(root,"message-ui.js"),"utf8");
assert.match(msgUI,/csb-name-editor/);
assert.match(msgUI,/Usar jugador/);
const fullscreen=fs.readFileSync(path.join(root,"fullscreen.js"),"utf8");
assert.doesNotMatch(fullscreen,/csb-fullscreen-controls/,"Duplicated fullscreen toolbar should be gone");
for(const file of ["event-browser.js","friendly-ui.js","message-ui.js","fullscreen.js","skin-preview.js","sprite-crop.js","next-style.js"]){
 assert.doesNotThrow(()=>load(file,[]),"Syntax "+file);
}
console.log("Command Studio 0.9.1 tests PASS: XP, VX, HGSS, choice skins, sprite trimming, namebox visibility, compact event cards");
