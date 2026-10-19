// Run with Node 22+: node tests/automatic-normals-and-cache.test.mjs
import assert from 'node:assert/strict';
import {normalCandidate,normalizeProject,defaultProject,assetName} from '../model.js';
import {drawLights,cacheSize,clearLightCache,invalidateLightRegions} from '../render.js';

const project=defaultProject();
project.normalSettings.enabled=true;
assert.equal(normalCandidate(project.normalSettings,'characters','Graphics/Characters/Followers/VENUSAUR.png'),
 'Graphics/LightingStudio/Normals/Characters/Followers/VENUSAUR_n.png');
assert.equal(normalCandidate(project.normalSettings,'characters','Graphics/Characters/Player_Alt'),
 'Graphics/LightingStudio/Normals/Characters/Player_Alt_n.png');
assert.equal(normalCandidate(project.normalSettings,'characters','../invalid'),null);
assert.equal(assetName('Followers/VENUSAUR'),'Followers/VENUSAUR');
assert.equal(assetName('../../invalid'),'');
assert.equal(normalCandidate({...project.normalSettings,auto:{characters:false}},'characters','Followers/VENUSAUR'),null);

const legacy=normalizeProject({schema:1,maps:{
  '1':{normalMaps:{enabled:true,characters:[{source:'Followers/VENUSAUR',normal:'Custom_Follower'}]},lights:[]}
}});
assert.equal(legacy.normalSettings.characters[0].normal,'Custom_Follower');
assert.equal(normalCandidate(legacy.normalSettings,'characters','Followers/VENUSAUR'),
 'Graphics/LightingStudio/Normals/Characters/Custom_Follower.png');

class Canvas {
  constructor(){this.width=0;this.height=0;this.ctx=new Context(this)}
  getContext(){return this.ctx}
}
class Context {
  constructor(canvas){this.canvas=canvas}
  save(){} restore(){} translate(){} rotate(){} drawImage(){} clearRect(){} fillRect(){} putImageData(){}
  createImageData(w,h){return {data:new Uint8ClampedArray(w*h*4)}}
}
globalThis.document={createElement:()=>new Canvas()};
const common={type:'radial',radiusPx:64,softness:.75,intensity:.7,color:'#FFE0A0',
 enabled:true,blendMode:'union',pixel:{enabled:false},pulse:{enabled:false}};
const a={...common,id:'lamp1',x:4,y:4};
const b={...common,id:'lamp2',x:14,y:7};
const view={mapId:25,revision:1,x:x=>x*32,y:y=>y*32,scale:()=>1};
const ctx=new Context(new Canvas());
clearLightCache();
for(let i=0;i<10;i++)drawLights(ctx,[a,b],view,640,480,0,'union');
const cached=cacheSize().views;
assert.ok(cached>=5,'Chunks should cache unaffected map regions');
const removed=invalidateLightRegions(a,{...a,x:4.5});
assert.ok(removed>=1&&removed<cached,'Only the edited lamp region should be invalidated');
assert.equal(cacheSize().views,cached-removed);
drawLights(ctx,[{...a,x:4.5},b],view,640,480,0,'union');
assert.ok(cacheSize().views>=cached-removed,'Unchanged regions remain cached');
clearLightCache();
console.log('Automatic normal names + local lighting invalidation: passed');
