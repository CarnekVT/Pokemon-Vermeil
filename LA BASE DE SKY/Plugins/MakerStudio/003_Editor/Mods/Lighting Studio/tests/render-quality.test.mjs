// node tests/render-quality.test.mjs
// Tests are headless; they do not replace real Maker Studio or mkxp testing.
import assert from 'node:assert/strict';
import {normalizeLight,normalizeProject,normalizeNormals,defaultMap} from '../model.js';
import {falloff,pixelGridDimensions,drawLights,clearLightCache,cacheSize} from '../render.js';

class FakeCanvas {
  constructor(){this.width=0;this.height=0;this.ctx=new FakeContext(this)}
  getContext(){return this.ctx}
}
class FakeContext {
  constructor(canvas){this.canvas=canvas;this.draws=0;this.frames=0}
  save(){} restore(){} translate(){} rotate(){} clearRect(){} fillRect(){}
  drawImage(){this.draws++}
  createImageData(w,h){return {data:new Uint8ClampedArray(w*h*4),width:w,height:h}}
  putImageData(image){this.frames++}
}
const originalDocument=globalThis.document;
globalThis.document={createElement:()=>new FakeCanvas()};
try {
  const smooth=normalizeLight({type:'cone',radiusPx:140,angle:65,centerStrength:1,coneFeather:.25});
  const ellipse=normalizeLight({type:'ellipse',widthPx:180,heightPx:90,centerStrength:1});
  assert.equal(smooth.pixel.enabled,false);
  assert.ok(falloff(smooth,.5,0) > falloff(smooth,.5,.25));
  assert.ok(falloff(ellipse,0,0)>falloff(ellipse,.9,0));
  assert.deepEqual(pixelGridDimensions(normalizeLight({type:'cone',radiusPx:96,
    pixel:{enabled:true,size:6,steps:6}})),{w:32,h:32});

  // Reuse the per-map chunks when neither map data nor camera projection changed.
  clearLightCache();
  const lightA=normalizeLight({id:'a',x:10,y:7,type:'cone',radiusPx:96,blendMode:'union'});
  const lightB=normalizeLight({id:'b',x:12,y:7,type:'ellipse',widthPx:160,heightPx:90,blendMode:'union'});
  const project={mapId:42,revision:1,x:x=>x*32,y:y=>y*32,scale:()=>1};
  const canvas=new FakeCanvas(),g=canvas.getContext('2d');
  drawLights(g,[lightA,lightB],project,640,480,0,'union');
  const first=cacheSize();
  assert.ok(first.views>0,'Union must store at least one world chunk');
  drawLights(g,[lightA,lightB],project,640,480,0,'union');
  assert.ok(cacheSize().views>=first.views,'Stable map data must reuse chunks');

  const normals=normalizeNormals({enabled:true,strength:1.5,tilesets:[{
    source:'Forest',normal:'Forest_n',invertY:true
  }],characters:[{source:'Hero',normal:'Hero_n'}]});
  assert.equal(normals.tilesets[0].invertY,true);
  assert.equal(normals.characters[0].normal,'Hero_n');
  assert.equal(normals.strength,1.5);
  assert.equal(normalizeNormals({characters:[{source:'../escape',normal:'bad'}]}).characters.length,0);
  const restored=normalizeProject({schema:1,maps:{'12':{ambient:{darkness:0},lights:[],
    normalMaps:normals}}}).maps[12];
  assert.equal(restored.normalMaps.tilesets[0].normal,'Forest_n');
  assert.equal(defaultMap().normalMaps.enabled,false,'Old maps must stay unshaded');
  console.log('Lighting Studio render and normal-binding regressions: passed');
} finally {
  globalThis.document=originalDocument;
  clearLightCache();
}
