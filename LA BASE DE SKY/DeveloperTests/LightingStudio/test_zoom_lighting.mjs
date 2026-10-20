// Run from LA BASE DE SKY with:
// node --experimental-default-type=module DeveloperTests/LightingStudio/test_zoom_lighting.mjs
import assert from 'node:assert/strict';
import {toScreen,screenRadius,hitTest} from '../../Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/map_overlay.js';
import {nativeScreenRect,nativeScreenToTile} from '../../Plugins/MakerStudio/003_Editor/Mods/com.lbds.animated-props/overlay-transform.js';
import {setMaskImage,getMaskImage,removeMaskImage,cacheSize,drawLights} from '../../Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/render.js';

// Maker Studio's renderInfo has tileSize already scaled by zoom. Match autotiles
// over different zooms and arbitrary camera pixel offsets.
for(const [zoom,tileSize] of [[.5,16],[.75,24],[1,32],[1.5,48],[2,64]]) {
 for(const [viewX,viewY] of [[0,0],[125,73],[534,281]]) {
  const info={zoom,tileSize,viewportX:viewX,viewportY:viewY,canvasWidth:960,canvasHeight:720};
  const point=toScreen(12.5,8.5,info),native=nativeScreenRect(12.5,8.5,1,1,info);
  assert.deepEqual(point,{x:native.x,y:native.y},'Zoom applied twice / drift from native autotile');
  assert.equal(screenRadius(96,info),3*tileSize,'Radius does not match tile scale');
  const back=nativeScreenToTile(point.x,point.y,info);
  assert.deepEqual(back,{x:12,y:8},'Click location no longer corresponds to native tile');
 }
}
// Mask hit testing should follow its rectangular/rotated footprint, not an
// unrelated circular light radius.
const mask={id:'mask',x:8,y:5,type:'mask',widthPx:160,heightPx:96,
  rotation:0,radiusPx:16,enabled:true};
assert.equal(hitTest([mask],{x:9.9,y:5},null)?.light.id,'mask');
assert.equal(hitTest([mask],{x:14,y:9},null),null);
const rotated={...mask,rotation:90,widthPx:160,heightPx:64};
assert.equal(hitTest([rotated],{x:8,y:6.7},null)?.light.id,'mask');

// A source image change is localized and does not clear the rest of the
// map's rasterized chunks or graphics cache.
const before=cacheSize();
const image={width:64,height:32};
setMaskImage('cave.png',image);
assert.equal(getMaskImage('cave.png'),image);
setMaskImage('cave.png',{width:32,height:32});
assert.equal(getMaskImage('cave.png').width,32);
removeMaskImage('cave.png');
assert.equal(getMaskImage('cave.png'),null);
assert.deepEqual(cacheSize(),before);
console.log('Lighting Studio: 15 native-autotile zoom / selection / mask cache regressions passed');
