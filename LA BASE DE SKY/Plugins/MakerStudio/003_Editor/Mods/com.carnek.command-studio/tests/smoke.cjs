const fs=require("fs"),path=require("path"),assert=require("node:assert/strict");
const root=path.resolve(__dirname,"..");
function load(file,names){
 const code=fs.readFileSync(path.join(root,file),"utf8")
  .replace(/^\s*import\s+.*\n/gm,"")
  .replace(/\bexport\s+(?=(const|async function|function|class)\b)/g,"")
  .replace(/export\s*\{[^}]*\};?/g,"");
 return new Function(code+";\nreturn {"+names.join(",")+"};")();
}
(async function(){
 const wiki=load("wiki-catalog.js",["WIKI","buildWiki"]);
 const src=load("source-index.js",["scanProject","parseSignature","buildMethodCode","parseRubyFile"]);
 const nat=load("native-builder.js",["compileNative"]);
 const pbs=load("pbs-index.js",["classifySymbolHint"]);
 const catalog=load("catalog.js",["NATIVE"]);
 assert(wiki.WIKI.length>=60,"Faltan entradas Wiki");
 assert.equal(catalog.NATIVE.length,106);
 for(const entry of wiki.WIKI){
  const values=Object.fromEntries(entry.args.map(x=>[x[0],x[3]]));
  assert.ok(wiki.buildWiki(entry,values).length>0,"Plantilla vacía: "+entry.title);
 }
 assert.deepEqual(nat.compileNative(101,{text:"Hola\nAdiós"},"").map(x=>x.code),[101,401]);
 assert.deepEqual(nat.compileNative(355,{script:"pbAddPokemon(:PIKACHU,5)\npbWait(20)"},"").map(x=>x.code),[355,655]);
 assert.deepEqual(nat.compileNative(102,{options:"Sí\nNo"},"").map(x=>x.code),[102,402,402,404]);
 assert.deepEqual(nat.compileNative(111,{condition:"true"},"").map(x=>x.code),[111,411,412]);
 assert.equal(pbs.classifySymbolHint("Especie"),"pokemon");
 const parsed=src.parseSignature("species, level=5, can_run: true");
 assert.deepEqual(parsed.map(x=>x.name),["species","level","can_run"]);
 const m=src.parseRubyFile("Data/Scripts/Example.rb","def pbCustom(species, level=5)\nend");
 assert.equal(m.length,1);
 assert.equal(src.buildMethodCode(m[0],{species:{value:"PIKACHU",type:"symbol"},level:{value:"20",type:"integer",enabled:true}}),
  "pbCustom(:PIKACHU, 20)");
 const dirs={"Data/Scripts":["001_Base"],"Data/Scripts/001_Base":["001.rb"],"Plugins":["com.plugin.one"],"Plugins/com.plugin.one":["plugin.rb"]};
 const files={"Data/Scripts/001_Base/001.rb":"def pbExample\nend","Plugins/com.plugin.one/plugin.rb":"def pbPluginTest(a, b=1)\nend"};
 const ctx={fs:{
  listProjectDir:async p=>dirs[p]||[],
  readProjectFile:async p=>{if(!files[p])throw Error(p);return files[p];}
 }};
 const res=await src.scanProject(ctx);
 assert.equal(res.report.read,2);
 assert.equal(res.report.found,2);
 assert.equal(res.report.complete,true);
 console.log("Command Studio smoke: OK — "+wiki.WIKI.length+" Wiki, "+catalog.NATIVE.length+" RMXP, 2 archivos indexados");
})().catch(e=>{console.error(e);process.exitCode=1;});
