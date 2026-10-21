const fs=require("node:fs"),path=require("node:path"),assert=require("node:assert/strict");
const base=path.resolve(__dirname,"..");
function load(names,returnNames){
 const combined=names.map(name=>fs.readFileSync(path.join(base,name),"utf8")
  .replace(/^\s*import\s+.*\n/gm,"")
  .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
  .replace(/export\s*\{[^}]*\};?/g,"")).join("\n");
 return new Function(combined+"\nreturn {"+returnNames.join(",")+"};")();
}
const v=load(["visual-message.js"],["COLOR_PRESETS","colorTag","setMessagePosition","messagePosition","previewData","normalizedHex"]);
const c=load(["messages-catalog.js"],["DIRECTIVES","codeFor"]);
assert.equal(v.COLOR_PRESETS.length,12);
assert.equal(v.colorTag("#F04E5B","Hola"),"<c=F04E5B>Hola</c>");
assert.equal(v.colorTag("88CCFF","Hola","#102030"),"<c3=88CCFF,102030>Hola</c3>");
assert.equal(v.setMessagePosition("Hola","wu"),"\\wuHola");
assert.equal(v.setMessagePosition("\\wdHola","wm"),"\\wmHola");
assert.equal(v.messagePosition("\\wmHola"),"wm");
assert.deepEqual(v.previewData("Hola <c=F04E5B>rojo</c> \\PN").parts.map(x=>x.text),["Hola ","rojo"," NOMBRE"]);
assert.equal(v.previewData("\\wuTexto").position,"wu");
const indexed=c.DIRECTIVES.find(d=>d.kind==="color-index");
assert.equal(c.codeFor(indexed,"0"),"\\c[0]");
assert.equal(c.codeFor(indexed,"12"),"\\c[12]");
assert.throws(()=>c.codeFor(indexed,"13"));
for(const file of ["fullscreen.js","visual-style.js","message-ui.js","friendly-ui.js"]){
 const code=fs.readFileSync(path.join(base,file),"utf8")
 .replace(/^\s*import\s+.*\n/gm,"")
 .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
 .replace(/export\s*\{[^}]*\};?/g,"");
 assert.doesNotThrow(()=>new Function(code),"Error sintáctico en "+file);
}
console.log("Command Studio visual smoke OK: RGB, sombra, posición, vista previa, 13 índices de color y módulos.");
