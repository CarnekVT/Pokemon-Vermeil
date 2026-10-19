// Run with Node.js: node tests/cone-falloff.test.mjs
// No Maker Studio or Pokémon Essentials environment is required.
import assert from 'node:assert/strict';
import { falloff, pixelGridDimensions } from '../render.js';
import { normalizeLight, normalizeProject } from '../model.js';

const cone = normalizeLight({
  type: 'cone', angle: 70, centerStrength: .8,
  coneFeather: .28, fadeStart: .58,
  pixel: { enabled: true, size: 6, steps: 6 }
});
const light = (x, y) => falloff(cone, x, y);
assert.equal(light(-.1, 0), 0, 'The cone must not illuminate behind its source');
assert.ok(light(0, 0) > .7, 'The source must stay at the sprite center');
assert.ok(light(.5, 0) > light(.5, .25), 'Side feather should reduce brightness');
assert.ok(light(.5, .25) > light(.5, .33), 'Side feather must fade gradually');
assert.ok(light(.7, 0) > light(.95, 0), 'The end of the cone must fade');
assert.equal(light(.5, .5), 0, 'Outside the aperture must stay dark');
assert.ok(light(.5, -.25) === light(.5, .25), 'The cone should be symmetric');
assert.deepEqual(pixelGridDimensions(cone), { w: 32, h: 32 });
assert.equal(normalizeLight({type:'cone'}).coneFeather, .28, 'Legacy maps retain their defaults');
const restored = normalizeProject({ schema:1, maps: { 4: {
  ambient: { darkness:0 }, lights: [{ id:'test', type:'cone', coneFeather:.6 }]
} } }).maps[4].lights[0];
assert.equal(restored.coneFeather, .6, 'Save and reload must preserve cone edge feather');
console.log('Lighting Studio cone falloff: 10 tests passed');
