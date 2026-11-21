// node "LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/Battle Animation Studio/tests/catalogs_nitro.test.mjs"
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";
const root=new URL("../",import.meta.url);
const names=["animation_catalogs.js","model.js","category_starters.js","multi_system.js","nitro_script_bridge.js"];
const src=(await Promise.all(names.map(name=>readFile(new URL(name,root),"utf8"))))
    .map(code=>code.replace(/^import [^\n]+;$/gm,"").replace(/^export /gm,"")).join("\n");
const lib=vm.runInNewContext("(()=>{\n"+src+"\nreturn {BAS_ANIMATION_CATALOGS,normalizeBasCatalogType,createAnimation,normalizeProject,applyBasCategoryStarter,buildMultiSystemRegistry,parseNitroAnimationText,createBasFromNitroText};})()",{
    structuredClone:globalThis.structuredClone
});
const catalog=lib.BAS_ANIMATION_CATALOGS;
assert.equal(catalog.length,13);
const animations=catalog.map(type=>{
    const a=lib.createAnimation("Example "+type.type,{catalogType:type.type,move:"EXAMPLE_"+type.type.toUpperCase()});
    lib.applyBasCategoryStarter(a);
    assert.equal(a.source.catalogType,type.type);
    if(!["move","common","custom"].includes(type.type)){
        assert.equal(a.tracks[0].clips.length,1);
        assert.equal(a.tracks[0].clips[0].graphic.source,"procedural");
        assert.match(a.tracks[0].clips[0].graphic.proceduralColor,/^rgba\(/);
    }
    return a;
});
const p=lib.normalizeProject({format:"vermeil-battle-animation-studio",version:1,animations});
const maps=lib.buildMultiSystemRegistry(p.animations);
assert.equal(Object.keys(maps).length,13);
for(const category of catalog)assert.equal(maps[category.mode].size,1);
assert.equal(lib.normalizeBasCatalogType("unknown"),"move");
const script=`a010_486:
loadparticlefromspa 0, 499
waitparticle
addparticle 0, 2, 3
playsepan 1911, -117
wait 2
unloadparticle 0
waitstate
end`;
const parsed=lib.parseNitroAnimationText(script);
assert.equal(parsed.frameCount,2);
assert.deepEqual(Array.from(parsed.spaIds),[499]);
assert.equal(parsed.particleSpawns,1);
assert.equal(parsed.seReferences[0].pan,-117);
assert(parsed.issues.some(i=>i.code==="asynchronous-wait"));
const result=lib.createBasFromNitroText(script,{id:"NITRO_486",placeholders:true});
assert.equal(result.animation.source.catalogType,"subanimation");
assert.equal(result.animation.source.runtimeEnabled,false);
assert.equal(result.animation.tracks[0].clips.length,1);
const original=JSON.parse(await readFile(new URL("../../../../../PBS/AnimationStudio/animations.json",root),"utf8"));
assert.equal(original.animations.length,22);
const normalizedOriginal=lib.normalizeProject(original);
assert.equal(normalizedOriginal.animations.length,22);
assert(original.animations.every((a,i)=>a.source.catalogType===normalizedOriginal.animations[i].source.catalogType));
console.log("13 catalogs, 10 procedural starters, Nitro script timing/slots, and legacy project: PASS");
