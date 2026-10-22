"use strict";
const fs=require("node:fs"),path=require("node:path"),assert=require("node:assert/strict");
const base=path.resolve(__dirname,"..");
const load=(file,vars)=>{
 const js=fs.readFileSync(path.join(base,file),"utf8")
  .replace(/^\s*import\s+.*\n/gm,"")
  .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
  .replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(js+";return {"+vars.join(",")+"};")();
};
const parser=load("source-index.js",["inferType","parseSignature"]);
assert.equal(parser.inferType(undefined,undefined),"expression");
assert.equal(parser.inferType(null,null),"expression");
assert.equal(parser.inferType("level",undefined),"integer");
assert.equal(parser.parseSignature("species, level = 5, options: nil").length,3);
const catalog=load("messages-catalog.js",["DIRECTIVES","d"]);
assert.ok(catalog.DIRECTIVES.length>=65);
assert.equal(catalog.d("Diálogo",undefined,"\\PN","").id,"msg-Diálogo-");
const preview=load("visual-message.js",["previewData"]);
assert.ok(preview.previewData("Hola \\PN <c=F04E5B>mundo</c>").parts.length>0);
for(const name of ["message-ui.js","event-browser.js","smart-ui.js","friendly-ui.js","index.js"]){
 assert.doesNotThrow(()=>load(name,[]),"Invalid module syntax: "+name);
}
const editor=fs.readFileSync(path.join(base,"friendly-ui.js"),"utf8");
assert.match(editor,/No se pudo abrir esta sección/);
const entry=fs.readFileSync(path.join(base,"index.js"),"utf8");
assert.match(entry,/Error al iniciar/);
console.log("Command Studio 0.9.2 PASS: undefined-safe text normalization, Ruby parser, message catalog and diagnostic fallback");
