// node --experimental-default-type=module "DeveloperTests/LightingStudio/test_mask_editor.mjs"
import assert from 'node:assert/strict';
import {caveTemplate,blankMask,saveMaskPng} from "../../Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/mask_editor.js";

// Canvas RGBA shim for the pure cave-mask generator. No browser is required.
class FakeCanvas{
 constructor(){this.width=0;this.height=0;this.image=null;}
 getContext(){
  return {
   createImageData:(w,h)=>({width:w,height:h,data:new Uint8ClampedArray(w*h*4)}),
   putImageData:(image)=>{this.image=image;}
  };
 }
 toDataURL(){return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ";}
}
globalThis.document={createElement:(tag)=>{assert.equal(tag,'canvas');return new FakeCanvas();}};
globalThis.atob=globalThis.atob||((v)=>Buffer.from(v,'base64').toString('binary'));

const right=caveTemplate(128,64,'right'),left=caveTemplate(128,64,'left');
assert.equal(right.width,128);assert.equal(right.height,64);
const pixel=(c,x,y)=>[...c.image.data.slice((y*c.width+x)*4,(y*c.width+x)*4+4)];
assert.equal(pixel(right,40,32)[0],255,'white silhouette controls source');
assert.ok(pixel(right,45,32)[3]>150,'center of projected cave light is bright');
assert.equal(pixel(right,45,0)[3],0,'walls block illumination');
assert.ok(pixel(right,127,32)[3]<pixel(right,45,32)[3],'light fades with reach');
assert.ok(pixel(left,110,32)[3]>pixel(left,15,32)[3],'left-direction template is reversed');
assert.equal(blankMask(40,20).image,null,'blank mask has no painted pixels');

let wrote=null,mkdir=null;
const game={fs:{
 projectMkdir:async p=>{mkdir=p;},
 writeProjectBinaryFile:async(p,bytes)=>{wrote={p,bytes}}
}};
const save=await saveMaskPng(game,'cueva_salida.png',right,'Graphics/LightingStudio/Masks');
assert.equal(save.saved,true);
assert.equal(save.path,'Graphics/LightingStudio/Masks/cueva_salida.png');
assert.equal(mkdir,'Graphics/LightingStudio/Masks');
assert.ok(wrote.bytes instanceof Uint8Array);
assert.deepEqual(Array.from(wrote.bytes.slice(0,8)),[137,80,78,71,13,10,26,10]);
await assert.rejects(()=>saveMaskPng(game,'../escape.png',right,'Graphics/LightingStudio/Masks'));
console.log('Lighting Studio cave mask templates and PNG save contract passed');
