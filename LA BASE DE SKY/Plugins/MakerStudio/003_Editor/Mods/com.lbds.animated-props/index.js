import {collisionCells, drawCollisionCells} from './collision-overlay.js';
import {phaseFromId,animationFrame,normalizeParallel,placementFrame,expectedTrackDimensions} from './animation-mixer.js';
import {imageUsage,safePngFilename,projectGraphicPath,graphicEntries} from './asset-library.js';
import {pngFingerprint,projectPngAbsolute,checkPngUpdates} from './image-reload.js';
import {lineCells,rectangleCells,brushFootprint,floodCells,strokeCells} from './stroke-engine.js';
import {occupiedPropCells,matchPropCells,changeSelection} from './prop-tools.js';
import { isMapPointer, normalizedViewport } from './map-canvas.js';
import { overlayCanvasRect, nativeScreenRect } from './overlay-transform.js';
import { getProfile, dueTick, frameAt } from './performance.js';
import { visibleFrameSignature } from './frame-clock.js';
import { createSpatialIndex, queryVisible, viewportCacheKey } from './spatial-index.js';
import {resolveTile} from './pointer-router.js';
import {pickProp, movable, tileFromRenderedCanvas} from './interaction.js';
import {paintableLayers, layerInfo, choosePaintLayer, adjacentPaintLayer} from './paint-layers.js';
import { regionFromPoints, tileAtClientPoint, upperTileMask } from './selection-and-layers.js';
import { subtractPlacementArea, activeLayerPlacementAt, scanNativeRefs, nativeRefsAsPlacements } from './placement-integration.js';
import {
  FILE, ART_DIR, defaultData, makeDefinition, normalizeData, cleanSheet,
  validatePosition, placementAt, getPlacedCell, cropFor, slug
} from './core.js';

const TOOL = 'lbds-animated-props.brush';
const PREVIEW_INTERVAL_MS = 33; // cheap scheduler; actual map redraw is profile-limited
// Independent prop offsets never change after placement; memoize their phases.
const PLACEMENT_PHASES=new Map(),PLACEMENT_PHASE_LIMIT=16000;
function cachedPlacementPhase(id,frames){
  const key=String(id)+'|'+String(frames);
  const found=PLACEMENT_PHASES.get(key);
  if(found!==undefined)return found;
  const phase=phaseFromId(id,frames);
  if(PLACEMENT_PHASES.size>=PLACEMENT_PHASE_LIMIT)PLACEMENT_PHASES.clear();
  PLACEMENT_PHASES.set(key,phase);
  return phase;
}
const CANVAS_SELECTOR = '[data-ms-part="canvas"]';
const PANEL = 'lbds-animated-props.library';
const CSS = `
.ap-root {min-width:0;}
.ap-cols>.ap-card{max-height:min(75vh,850px);overflow-y:auto;min-width:0;scrollbar-width:thin;}
.ap-visual-stage{min-height:270px;display:flex;flex-direction:column;gap:8px;}
.ap-visual-stage .ap-anim-stage{min-height:220px;max-height:410px;overflow:auto;display:flex;align-items:center;justify-content:center;background:repeating-conic-gradient(#27323a 0% 25%,#36424d 0% 50%) 0/20px 20px;}
.ap-visual-stage .ap-anim-canvas{image-rendering:pixelated;}
.ap-settings-section{border-top:1px solid var(--border);padding-top:12px;margin-top:14px;}
.ap-track-head{display:flex;justify-content:space-between;gap:10px;align-items:center;margin:8px 0 5px;}
.ap-track-title{font-weight:750;font-size:13px;}
.ap-secondary-note{font-size:11px;line-height:1.4;color:var(--text-secondary)}
.ap-parallel-frame.active{border-color:#a78bfa;box-shadow:inset 0 -3px 0 #a78bfa;}
.ap-preview-toolbar{position:sticky;top:0;background:var(--bg-secondary);z-index:1;padding:5px;}
.ap-control-heading{font-size:12px;letter-spacing:.035em;text-transform:uppercase;color:var(--text-secondary);margin:6px 0;}
.ap-tool-dock{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
.ap-timeline{min-height:85px;}
.ap-list {max-height:280px;}

.ap-root {display:flex;flex-direction:column;gap:12px;height:100%;box-sizing:border-box;overflow:auto;padding:10px;color:var(--text-primary);font:13px inherit;}
.ap-header {display:flex;gap:6px;align-items:center;flex-wrap:wrap;}
.ap-row {display:flex;align-items:center;gap:8px;flex-wrap:wrap;}
.ap-btn {cursor:pointer;background:var(--bg-tertiary);color:var(--text-primary);border:1px solid var(--border);border-radius:6px;padding:6px 10px;font:inherit;}
.ap-btn.primary {background:var(--accent);color:var(--accent-text);border-color:var(--accent)}
.ap-btn:disabled {opacity:.5;cursor:default}
.ap-list {display:flex;flex-direction:column;gap:3px;max-height:195px;overflow:auto}
.ap-list button {text-align:left;white-space:normal;}
.ap-list button.active {border-color:var(--accent);background:var(--bg-hover)}
.ap-card {background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:10px;min-width:0}
.ap-note {color:var(--text-secondary);line-height:1.4;font-size:12px}
.ap-fields {display:grid;grid-template-columns:repeat(2,minmax(100px,1fr));gap:8px}
.ap-label {display:flex;flex-direction:column;gap:3px;font-size:12px;color:var(--text-secondary)}
.ap-input {box-sizing:border-box;max-width:100%;width:100%;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:5px;font:inherit}
.ap-grid {display:grid;gap:1px;width:max-content;border:1px solid var(--border);background:var(--border);max-width:100%;}
.ap-cell {display:grid;place-items:center;width:32px;height:32px;background:var(--bg-tertiary);color:#fff;text-shadow:0 1px 2px #000,1px 0 2px #000;font:bold 12px monospace;border:none;cursor:pointer}
.ap-cell.block {box-shadow:inset 0 0 0 2px #ff6565}.ap-cell.partial {box-shadow:inset 0 0 0 2px #ffbd66}.ap-cell.active {box-shadow:inset 0 0 0 2px var(--accent)}
.ap-status {border:1px solid var(--accent);border-radius:6px;background:var(--bg-secondary);padding:8px;font-size:12px;line-height:1.5}
.ap-status strong {color:var(--text-primary)}
.ap-placed-list {display:flex;flex-direction:column;gap:5px;max-height:190px;overflow:auto;margin-top:6px}
.ap-placed-row {display:flex;align-items:center;gap:4px;justify-content:space-between;border:1px solid var(--border);padding:5px;border-radius:5px;flex-wrap:wrap}
.ap-placed-row.active {border-color:var(--accent)}
.ap-numeric {width:90px;max-width:100%}
.ap-preview {image-rendering:pixelated;max-height:230px;max-width:100%;object-fit:contain;background:repeating-conic-gradient(#7772 0% 25%,#fff1 0% 50%) 0 / 24px 24px}
.ap-anim-stage {display:flex;align-items:flex-start;justify-content:flex-start;min-height:120px;max-height:390px;overflow:auto;background:repeating-conic-gradient(#adb4c522 0% 25%,#4441 0% 50%) 0 / 20px 20px;border:1px solid var(--border);border-radius:8px;padding:12px}
.ap-anim-canvas {image-rendering:pixelated;max-width:none;max-height:none;object-fit:contain;flex:none}
.ap-mini-canvas {image-rendering:pixelated;display:block;width:100%;max-width:420px;height:auto;background:#15212b;border:1px solid var(--border);border-radius:7px;cursor:crosshair}
.ap-lib-entry {display:flex!important;align-items:center;gap:9px}
.ap-thumb {width:54px;height:54px;flex:none;background:repeating-conic-gradient(#8883 0% 25%,#aaa2 0% 50%) 0 / 16px 16px;border-radius:4px;image-rendering:pixelated}
.ap-lib-name {white-space:pre-line;line-height:1.4}
.ap-diagnostics {font:11px monospace;white-space:pre-wrap;line-height:1.55;color:var(--text-secondary)}
.ap-playing {font-variant-numeric:tabular-nums;font-size:12px;color:var(--text-secondary)}
.ap-warning {color:#f9ac69;font-size:12px}
.ap-button-row {display:flex;gap:5px;flex-wrap:wrap;margin:7px 0}
.ap-switch {display:grid;grid-template-columns:1fr 1fr;gap:5px;margin:8px 0}
.ap-switch .active {outline:2px solid var(--accent);outline-offset:-2px}
.ap-mode-select {border:2px solid var(--accent)!important}
.ap-edit-help {padding:7px;background:var(--bg-tertiary);border-radius:5px;margin:4px 0}
.ap-sheet-region {position:relative;display:block;touch-action:none;user-select:none;cursor:crosshair;max-width:none;flex:none;image-rendering:pixelated;background:repeating-conic-gradient(#8883 0% 25%,#aaa2 0% 50%) 0 / 16px 16px}
.ap-sheet-wrap {border:1px solid var(--border);overflow:auto;max-height:370px;max-width:100%;overscroll-behavior:contain;position:relative}
.ap-layer-label {display:flex;gap:5px;align-items:center}
.ap-tab-title {font-weight:600}
.ap-workspace-head {display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap;padding:10px 11px;border:1px solid var(--border);border-radius:8px;background:var(--bg-secondary)}
.ap-studio-title {font-weight:750;letter-spacing:.03em;font-size:14px}
.ap-subtitle {font-size:11px;color:var(--text-secondary)}
.ap-chip {font-size:11px;border-radius:5px;padding:3px 6px;background:var(--bg-tertiary);border:1px solid var(--border)}
.ap-preview-toolbar {display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin:8px 0}
.ap-preview-toolbar .ap-input {width:auto;min-width:95px}
.ap-timeline {display:flex;gap:5px;overflow-x:auto;overscroll-behavior-x:contain;max-width:100%;padding:7px 1px 11px;scrollbar-width:thin}
.ap-frame {display:flex;align-items:center;flex-direction:column;gap:4px;flex:0 0 72px;cursor:pointer;background:var(--bg-tertiary);border:2px solid var(--border);padding:5px;border-radius:7px;color:var(--text-primary);font:11px monospace}
.ap-frame.active {border-color:var(--accent);background:var(--bg-hover);box-shadow:inset 0 -3px 0 var(--accent)}
.ap-frame canvas {image-rendering:pixelated;max-width:60px;height:54px;object-fit:contain}
.ap-progress {height:4px;background:var(--border);overflow:hidden;border-radius:5px;margin-top:3px}
.ap-progress-fill {height:100%;width:0%;background:var(--accent)}
.ap-meter {font-size:11px;color:var(--text-secondary);font-variant-numeric:tabular-nums}
.ap-workspace-grid {display:grid;grid-template-columns:minmax(0,1fr);gap:10px}
.ap-perf-card {border:1px solid var(--border);padding:8px;border-radius:7px;background:var(--bg-tertiary)}


/* Studio UX v0.5.8: final authoritative layout overrides legacy rules. */
.ap-root{gap:12px;padding:14px;overflow:auto;min-height:0;}
.ap-workspace-head{padding:12px 16px;border-radius:10px;}
.ap-studio-title{font-size:16px;}
.ap-header{gap:7px;align-items:center;}
.ap-header .ap-btn{min-height:32px;}
.ap-cols{display:grid;grid-template-columns:clamp(235px,21%,295px) minmax(410px,1fr) clamp(325px,29%,410px);gap:14px;align-items:start;min-width:1050px;}
.ap-cols>.ap-card{overflow:auto;min-width:0;max-height:none;min-height:570px;padding:15px;box-sizing:border-box;}
.ap-library{display:flex;flex-direction:column;gap:10px;}
.ap-list{max-height:250px;gap:8px;padding:2px;}
.ap-lib-entry{padding:9px!important;border-radius:9px;min-height:68px;}
.ap-thumb{width:64px;height:64px;}
.ap-lib-name{font-size:12px;}
.ap-visual-stage{min-height:540px;gap:10px;}
.ap-visual-stage .ap-anim-stage{min-height:300px;max-height:520px;}
.ap-inspector{display:flex;flex-direction:column;gap:12px;}
.ap-inspector-tabs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin-bottom:3px;}
.ap-inspector-tabs .ap-btn{padding:11px 8px;text-align:center;min-height:44px;font-weight:650;}
.ap-inspector-tabs .ap-btn.active{background:var(--accent);color:var(--accent-text);border-color:var(--accent);}
.ap-inspector-content{display:flex;flex-direction:column;gap:12px;min-width:0;}
.ap-inspector-content .ap-fields{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;}
.ap-asset-track{display:flex;flex-direction:column;gap:9px;padding:13px;background:var(--bg-tertiary);border:1px solid var(--border);border-radius:10px;}
.ap-track-banner{display:flex;align-items:center;justify-content:space-between;gap:12px;}
.ap-track-banner strong{font-size:14px;}
.ap-track-preview{height:160px;display:flex;justify-content:center;align-items:center;background:repeating-conic-gradient(#172530 0 25%,#263744 0 50%) 0/22px 22px;border:1px solid var(--border);border-radius:8px;overflow:hidden;}
.ap-track-preview img{max-width:100%;max-height:100%;object-fit:contain;image-rendering:pixelated;}
.ap-track-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;}
.ap-track-actions .ap-btn{min-height:37px;white-space:normal;}
.ap-asset-note{overflow-wrap:anywhere;font-size:12px;}
.ap-asset-library-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(185px,1fr));gap:13px;align-items:stretch;}
.ap-asset-file{display:flex;flex-direction:column;gap:8px;border:1px solid var(--border);border-radius:10px;background:var(--bg-secondary);padding:11px;min-width:0;}
.ap-asset-file .ap-track-preview{height:155px;}
.ap-asset-file .ap-asset-name{font-weight:650;font-size:12px;overflow-wrap:anywhere;min-height:32px;}
.ap-asset-file .ap-btn{width:100%;}
.ap-asset-toolbar{position:sticky;top:0;z-index:4;background:var(--bg-primary);padding:12px 4px;display:flex;gap:8px;flex-wrap:wrap;align-items:center;border-bottom:1px solid var(--border);margin-bottom:12px;}
.ap-chip{white-space:normal;}
.ap-root.ap-compact .ap-cols{grid-template-columns:minmax(0,1fr);min-width:0;}
.ap-root.ap-compact .ap-cols>.ap-card{min-height:0;max-height:none;}
.ap-cols.ap-region-mode .ap-visual-stage{display:none;}
.ap-cols.ap-region-mode .ap-inspector{grid-column:2 / 4;}
.ap-cols.ap-region-mode .ap-sheet-wrap{max-height:560px;}
.ap-root.ap-compact .ap-cols.ap-region-mode .ap-inspector{grid-column:auto;}
.ap-warning-action{border-color:#cd685c;color:#ff9b92;}
.ap-deletion-hint{color:var(--text-secondary);font-size:11px;line-height:1.5;}
.ap-asset-modal-root{padding:12px;max-height:78vh;overflow:auto;background:var(--bg-primary);color:var(--text-primary);font:13px inherit;}
.ap-perf-card{padding:9px;}
@media(max-width:1200px){.ap-cols{grid-template-columns:220px minmax(400px,1fr) 335px;min-width:970px;}}


/* Native-style tools for Animated Props; toolbar changes don't rebuild the Studio. */
.ap-tool-palette{display:flex;flex-wrap:wrap;gap:5px;align-items:center;padding:9px;border:1px solid var(--border);border-radius:9px;background:var(--bg-secondary)}
.ap-tool-choice{min-width:37px;min-height:37px;font-size:18px;border:1px solid var(--border);border-radius:6px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer}
.ap-tool-choice.active{outline:2px solid var(--accent);background:var(--bg-hover)}
.ap-tool-options{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:5px 1px}

/* v0.6.2: ONE spatial workspace instead of vertically stacked duplications. */
.ap-root.ap-studio-v062{display:flex;flex-direction:column;overflow:hidden;gap:9px;padding:11px;height:100%;min-height:500px;container-type:inline-size;}
.ap-studio-v062 .ap-studio-command{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap;border-bottom:1px solid var(--border);padding:4px 1px 10px;flex-shrink:0}
.ap-studio-v062 .ap-studio-identity{display:flex;flex-direction:column;gap:2px;min-width:175px}
.ap-studio-v062 .ap-studio-identity strong{font-size:15px;letter-spacing:.04em}
.ap-studio-v062 .ap-command-actions{display:flex;flex:1;justify-content:flex-end;align-items:center;gap:5px;flex-wrap:wrap}
.ap-studio-v062 .ap-command-actions .ap-btn{padding:7px 10px;white-space:nowrap;min-height:35px}
.ap-studio-v062 .ap-perf-card{display:flex;align-items:center;gap:8px;padding:0;border:0;background:transparent}
.ap-studio-v062 .ap-performance-select{max-width:120px;width:auto;min-width:110px}
.ap-studio-v062 .ap-perf-title{font-size:11px;color:var(--text-secondary)}
.ap-studio-v062 .ap-tool-workbench{display:flex;flex-direction:column;gap:7px;padding:11px 12px;border:1px solid var(--border);border-radius:11px;background:var(--bg-secondary);flex-shrink:0}
.ap-studio-v062 .ap-tool-main,.ap-studio-v062 .ap-tool-groups{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}
.ap-studio-v062 .ap-tool-intro{display:flex;flex-direction:column;gap:3px}
.ap-studio-v062 .ap-tool-intro small{color:var(--text-secondary);font-size:11px}
.ap-studio-v062 .ap-editor-mode{display:flex;gap:4px;flex-wrap:wrap}
.ap-studio-v062 .ap-quick-layer{display:flex;align-items:center;gap:8px;font-size:12px;color:var(--text-secondary)}
.ap-studio-v062 .ap-quick-layer .ap-input{width:155px;min-width:115px}
.ap-studio-v062 .ap-mode-switch{min-height:32px;font-weight:650}
.ap-studio-v062 .ap-mode-switch.active{border-color:var(--accent);box-shadow:inset 0 0 0 1px var(--accent)}
.ap-studio-v062 .ap-tool-groups{justify-content:flex-start;align-items:flex-start;border-top:1px solid var(--border);padding-top:8px;gap:18px}
.ap-studio-v062 .ap-tools-group{display:flex;flex-direction:column;gap:5px}
.ap-studio-v062 .ap-tools-caption{font-size:10px;text-transform:uppercase;color:var(--text-secondary);letter-spacing:.08em}
.ap-studio-v062 .ap-tools-buttons{display:flex;flex-wrap:wrap;gap:6px}
.ap-studio-v062 .ap-tool-choice{display:flex;flex-direction:column;justify-content:center;align-items:center;gap:3px;min-width:76px;min-height:58px;padding:7px 8px;font:inherit;font-size:12px;border:1px solid var(--border);border-radius:8px;white-space:normal}
.ap-studio-v062 .ap-tool-choice .ap-tool-icon{font-size:21px;line-height:1.2}
.ap-studio-v062 .ap-tool-choice .ap-tool-name{font-size:11px;font-weight:600;white-space:nowrap}
.ap-studio-v062 .ap-tool-choice.active{outline:none;border-color:var(--accent);box-shadow:inset 0 -3px 0 var(--accent);background:var(--bg-hover)}
.ap-studio-v062 .ap-tool-choice:hover{border-color:var(--accent)}
.ap-studio-v062 .ap-tool-advanced{min-width:165px;align-self:center;position:relative}
.ap-studio-v062 .ap-tool-advanced summary,.ap-studio-v062 .ap-tool-extras summary{cursor:pointer;color:var(--text-secondary);font-size:12px}
.ap-studio-v062 .ap-tool-advanced[open]{align-self:stretch}
.ap-studio-v062 .ap-tools-advanced{display:flex;flex-direction:column;gap:6px;padding:10px 0 1px}
.ap-studio-v062 .ap-tool-context{display:flex;gap:9px 15px;align-items:center;flex-wrap:wrap;border-top:1px solid var(--border);padding-top:7px;min-height:32px}
.ap-studio-v062 .ap-context-tool{font-size:12px;white-space:nowrap}
.ap-studio-v062 .ap-context-help{font-size:12px;color:var(--text-secondary);flex:1;min-width:240px}
.ap-studio-v062 .ap-context-options{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.ap-studio-v062 .ap-tool-size-options{display:flex;gap:7px;align-items:center}
.ap-studio-v062 .ap-tool-size-options label,.ap-studio-v062 .ap-size-label{font-size:11px;white-space:nowrap}
.ap-studio-v062 .ap-size-range{width:75px;min-width:0;accent-color:var(--accent)}
.ap-studio-v062 .ap-shape-select{width:105px}
.ap-studio-v062 .ap-tool-match-options,.ap-studio-v062 .ap-tool-extras{font-size:12px}
.ap-studio-v062 .ap-tool-extras-inner{display:flex;flex-direction:column;gap:10px;padding:10px 0}
.ap-studio-v062 .ap-cols{display:grid;grid-template-columns:minmax(210px,250px) minmax(0,1fr) minmax(285px,350px);gap:10px;align-items:stretch;min-width:0;min-height:0;flex:1;overflow:hidden}
.ap-studio-v062 .ap-cols>.ap-card{max-height:none;min-height:0;overflow-y:auto;overflow-x:hidden;padding:13px;scrollbar-width:thin}
.ap-studio-v062 .ap-list{max-height:min(42vh,380px);gap:6px}
.ap-studio-v062 .ap-lib-entry{min-height:76px;text-align:left;padding:8px!important}
.ap-studio-v062 .ap-thumb{width:64px;height:64px}
.ap-studio-v062 .ap-visual-stage{min-height:0;gap:6px}
.ap-studio-v062 .ap-visual-stage .ap-anim-stage{min-height:280px;max-height:min(56vh,540px);flex:1}
.ap-studio-v062 .ap-visual-stage .ap-preview-toolbar{position:static;padding:2px 0;margin:0}
.ap-studio-v062 .ap-inspector{min-height:0}
.ap-studio-v062 .ap-inspector-content{gap:11px}
.ap-studio-v062 .ap-map-controls{padding:9px 7px;border:1px solid var(--border);border-radius:7px}
.ap-studio-v062 .ap-map-controls>summary{cursor:pointer;font-weight:650;font-size:12px}
.ap-studio-v062 .ap-map-content{margin-top:12px;display:flex;flex-direction:column;gap:8px}
.ap-studio-v062 .ap-map-content .ap-status{overflow-wrap:anywhere}
.ap-studio-v062 .ap-map-content .ap-placed-row{font-size:11px}
.ap-studio-v062 .ap-debug-panel>summary{font-size:11px;color:var(--text-secondary);cursor:pointer}
.ap-studio-v062 .ap-cols.ap-region-mode{grid-template-columns:minmax(210px,250px) minmax(0,1fr)}
.ap-studio-v062 .ap-cols.ap-region-mode .ap-inspector{grid-column:2}
.ap-studio-v062 .ap-cols.ap-region-mode .ap-visual-stage{display:none}
.ap-studio-v062 .ap-cols.ap-region-mode .ap-sheet-wrap{max-height:calc(100vh - 310px)}
.ap-studio-v062 .ap-workspace-head{display:none}
.ap-studio-v062 .ap-tool-size-options[hidden],.ap-studio-v062 .ap-tool-match-options[hidden]{display:none!important}
.ap-studio-v062.ap-compact{overflow:auto;container-type:normal}
.ap-studio-v062.ap-compact .ap-cols{display:grid;grid-template-columns:minmax(0,1fr);overflow:visible;flex:none}
.ap-studio-v062.ap-compact .ap-cols>.ap-card{overflow:visible;min-height:0;max-height:none}
.ap-studio-v062.ap-compact .ap-visual-stage{order:1}
.ap-studio-v062.ap-compact .ap-inspector{order:2}
.ap-studio-v062.ap-compact .ap-library{order:3}
.ap-studio-v062.ap-compact .ap-cols.ap-region-mode .ap-inspector{grid-column:auto}
@container (max-width: 1140px){.ap-studio-v062 .ap-tool-choice{min-width:67px;padding:6px}.ap-studio-v062 .ap-tool-groups{gap:10px}}

.ap-studio-v062 .ap-layer-isolate{display:flex;align-items:center;gap:4px;white-space:nowrap;font-size:12px;cursor:pointer}
.ap-studio-v062 .ap-layer-count{background:var(--bg-tertiary);border-radius:5px;padding:3px 7px;white-space:nowrap;font-size:11px}
`;
let state = null;
const SELECT_ZOOMS = [0.5, 0.75, 1, 1.5, 2];

const el = (tag, text, attrs={}) => {
  const e = document.createElement(tag);
  if (text != null) e.textContent = text;
  for (const [k,v] of Object.entries(attrs)) e[k] = v;
  return e;
};
const btn = (label, cb, primary=false) => {
  const b = el('button',label,{type:'button',className:`ap-btn${primary?' primary':''}`});
  b.addEventListener('click', async () => { try { await cb(); } catch(e) { problem(e); } });
  return b;
};
function problem(e) {
  const msg=String(e?.message||e);
  state?.ctx.log.error(msg);
  state?.ctx.ui.showToast({message:msg,level:'error',durationMs:5500});
}
function toast(msg) { state.ctx.ui.showToast({message:msg,level:'info'}); }
function getDef() { return state?.data.definitions.find(d=>d.id===state.selected) || null; }
function selectedCrop(d=getDef()) {return d?cropFor(d,state?.crops?.get(d.id)):null;}
// A layer click must not reconstruct metadata and extended-layer options for
// every sprite on every frame. Invalidate on map/layer structure changes only.
function layerSnapshot(mapId=activeMap()){
 if(!state||mapId==null)return {rows:[],info:null,paint:[],byIndex:new Map()};
 if(!state.layerMetaByMap)state.layerMetaByMap=new Map();
 const cached=state.layerMetaByMap.get(mapId);
 if(cached)return cached;
 let rows=[];try{rows=state.ctx.map.layers(mapId)||[];}catch{}
 const info=state.ctx.map.info(mapId);
 const paint=paintableLayers(rows,info);
 const byIndex=new Map(paint.map(l=>[l.index,l]));
 const entry={rows,info,paint,byIndex};
 state.layerMetaByMap.set(mapId,entry);
 return entry;
}
function invalidateLayerMetadata(mapId=null){
 if(!state?.layerMetaByMap)return;
 if(mapId==null)state.layerMetaByMap.clear();else state.layerMetaByMap.delete(mapId);
}
function mapLayers(mapId=activeMap()){return layerSnapshot(mapId).rows;}
function paintLayers(mapId=activeMap()){return layerSnapshot(mapId).paint;}
function selectedPaintLayer(mapId=activeMap()) {
 if(mapId==null)return null;
 const preferred=state.paintLayer?.mapId===mapId?state.paintLayer.index:null;
 const snapshot=layerSnapshot(mapId);
 return choosePaintLayer(snapshot.rows,snapshot.info,preferred,state.ctx.editor.activeLayerIndex());
}
// Cache sorted placement ordering and definition lookup until JSON changes.
function renderEntries(mapId){
 if(!state?.renderIndex)state.renderIndex=new Map();
 const list=state.data.placements[String(mapId)]||[];
 const cached=state.renderIndex.get(mapId);
 if(cached?.list===list)return cached;
 const defs=new Map(state.data.definitions.map(d=>[d.id,d]));
 const ordered=[...list].sort((a,b)=>(a.layer||0)-(b.layer||0)).map(p=>({p,d:defs.get(p.defId)})).filter(x=>x.d);
 const entry={list,ordered,defs,spatial:createSpatialIndex(ordered)};state.renderIndex.set(mapId,entry);
 return entry;
}
function invalidateRenderIndex(){
 if(!state)return;
 state.renderIndex?.clear();state.visibleCandidates=null;
}
function setPaintLayer(mapId,index,applyEditor=false){
 const layer=paintLayers(mapId).find(l=>l.index===index);
 if(!layer)throw Error(`La capa ${index+1} no está registrada como capa normal o extendida.`);
 state.paintLayer={mapId,index};
 state.propSelection=null;
 // An index can also be used by a virtual shadow row in some builds.
 // In that case leave the native focus alone and keep the mod's tile-layer
 // choice independently, otherwise setActiveLayer may select the shadow UI.
 const clashesWithShadow=mapLayers(mapId).some(l=>l.index===index&&l.kind==='shadow');
 if(applyEditor&&!clashesWithShadow)try{state.ctx.editor.setActiveLayer(index);}catch(err){state.ctx.log.warn(`No se cambió la capa del panel nativo: ${err}`);}
 syncLayerUI();redraw(true);
}
function layerProps(mapId,layer){
 return layerInfo(mapLayers(mapId),layer,state?.ctx.map.info(mapId))||{visible:true,opacity:1,name:`Capa ${layer+1}`};
}
function toolActive(){return !!state&&state.ctx.editor.activeTool()===TOOL;}
function nativeTiles(){state.propsToolArmed=false;state.ctx.editor.setTool('brush');state.hover=null;status('Tiles normales: pincel nativo activo.');refresh();redraw();}
function activateProps(){selectTool();refresh();}
function setMode(mode){
 state.actionMode=mode==='select'?'select':'paint';state.drag=null;
 selectTool();refresh();redraw();
}
function getSelectedPlacement(mapId=activeMap()){
 return (state?.data.placements[String(mapId)]||[]).find(p=>p.id===state.selectedPlacedId)||null;
}
async function deleteSelected(){
 const mapId=activeMap(),p=getSelectedPlacement(mapId);
 if(!p){status('Selecciona un prop primero.');return false;}
 checkpoint();state.data.placements[String(mapId)].splice(state.data.placements[String(mapId)].indexOf(p),1);
 state.selectedPlacedId='';state.drag=null;
 await persist();status(`Objeto eliminado de (${p.x},${p.y}).`);refresh();redraw();return true;
}
async function relocateSelected(mapId,x,y){
 const p=getSelectedPlacement(mapId);
 if(!p)throw Error('Selecciona un objeto del mapa antes de moverlo.');
 const info=state.ctx.map.info(mapId);
 if(!movable(state.data,info,mapId,p.id,x,y))throw Error('La nueva posición queda fuera del mapa.');
 if(p.x===x&&p.y===y)return false;
 checkpoint();p.x=x;p.y=y;state.coords={x,y};state.drag=null;
 await persist();status(`Objeto movido a (${x},${y}) · capa ${p.layer+1}.`);
 refresh();redraw();return true;
}
function beginEdit(mapId,x,y){
 const p=pickProp(state.data,mapId,x,y,selectedPaintLayer(mapId));
 state.selectedPlacedId=p?.id||'';
 if(!p){state.drag=null;status('No hay un prop en esa celda.');refresh();redraw();return false;}
 const def=state.data.definitions.find(d=>d.id===p.defId);
 if(def){state.selected=def.id;state.crops.set(def.id,cropFor(def,p.crop));}
 state.drag={mapId,id:p.id,startX:x,startY:y,originX:p.x,originY:p.y,x:p.x,y:p.y};
 state.coords={x:p.x,y:p.y};status(`Seleccionado ${def?.name||p.defId}. Arrastra para moverlo.`);
 refresh();redraw();return true;
}
function updateEdit(mapId,x,y){
 const drag=state?.drag;
 if(!drag||drag.mapId!==mapId)return false;
 const nx=drag.originX+x-drag.startX,ny=drag.originY+y-drag.startY;
 if(drag.x===nx&&drag.y===ny)return false;
 if(!movable(state.data,state.ctx.map.info(mapId),mapId,drag.id,nx,ny))return false;
 drag.x=nx;drag.y=ny;redraw();return true;
}
async function finishEdit(){
 const drag=state?.drag;
 if(!drag)return false;
 state.drag=null;
 return relocateSelected(drag.mapId,drag.x,drag.y);
}
function switchToNativeOnPaletteChange(){if(toolActive())nativeTiles();}

function redraw(immediate=false,invalidateCache=true) {
 if(!state)return;
 if(invalidateCache)state.compositeRevision=(state.compositeRevision||0)+1;
 if(immediate){
   // Layer switches must not wait for thumbnail/panel rebuilding.
   if(state.drawPending && state.drawRaf!=null && typeof cancelAnimationFrame==='function')cancelAnimationFrame(state.drawRaf);
   state.drawPending=false;state.drawRaf=null;
   try{state.ctx.editor.requestRedraw?.();}catch(err){state.ctx.log.warn(`Render: ${err}`);}
   return;
 }
 if(state.drawPending)return;
 state.drawPending=true;
 const owner=state;
 const run=()=>{
   if(!state||state!==owner)return;
   owner.drawPending=false;owner.drawRaf=null;
   try{owner.ctx.editor.requestRedraw?.();}catch(err){owner.ctx.log.warn(`Render: ${err}`);}
 };
 if(typeof requestAnimationFrame==='function')state.drawRaf=requestAnimationFrame(run);
 else queueMicrotask(run);
}
function updateLayerCount(){
 if(!state?.host)return;
 const id=activeMap(),index=selectedPaintLayer(id);
 const count=state.data.placements[String(id)]?.filter(p=>p.layer===index).length||0;
 for(const target of state.host.querySelectorAll?.('.ap-layer-count')||[])target.textContent=`${count} props`;
}
function syncLayerUI(){
 if(!state)return;
 const id=activeMap(),index=selectedPaintLayer(id);
 for(const selector of state.host?.querySelectorAll?.('.ap-paint-layer')||[]){
   if(index!=null && selector.value!==String(index))selector.value=String(index);
 }
 updateLayerCount();syncStatus();
}
function invalidateLayerMask(mapId=null){
 if(!state)return;
 if(mapId==null){state.layerMasks.clear();return;}
 const prefix=`${mapId}:`;
 for(const key of state.layerMasks.keys())if(key.startsWith(prefix))state.layerMasks.delete(key);
}
function cachedHigherMask(mapId,p,crop,layers){
 if(!state.maskHigherTiles)return {all:true};
 const key=`${mapId}:${p.id}:${p.layer}:${p.x}:${p.y}:${crop.w}:${crop.h}`;
 const found=state.layerMasks.get(key);
 if(found)return found;
 const mask=upperTileMask(state.ctx.map,mapId,p.layer,p.x,p.y,crop.w,crop.h,layers);
 if(state.layerMasks.size>5000)state.layerMasks.clear();
 state.layerMasks.set(key,mask);
 return mask;
}
function tickVisuals(){
  if(!state || (typeof document!=='undefined' && document.hidden))return;
  const now=performance.now(), profile=getProfile(state.perfMode);
  const mapId=activeMap();
  if(state.showOverlay && mapId!=null && profile.mapFps>0 &&
     (state.lastMapTick==null || dueTick(now,state.lastMapTick,profile.mapFps))){
    state.lastMapTick=now;
    const info=state.lastRenderInfo?.mapId===mapId?state.lastRenderInfo:null;
    if(!info)return; // no viewport to animate yet; never query the whole map
    const render=renderEntries(mapId),geo=viewportCacheKey(mapId,info);
    const cached=state.visibleCandidates;
    const visible=cached?.geo===geo&&cached?.render===render ?
      cached.entries : queryVisible(render.spatial,info);
    if(!cached || cached.geo!==geo || cached.render!==render)
      state.visibleCandidates={geo,render,entries:visible};
    const key=visibleFrameSignature(visible,now,{epoch:state.animEpoch||0,mode:state.perfMode,paused:!!state.playback?.paused,pausedParallelFrame:state.playback?.parallelFrame||0});
    if(key!==state.lastMapFrameKey){
      state.lastMapFrameKey=key;
      // No animated visual is visible? Never schedule a map redraw merely
      // because the animation timer is alive.
      if(key)redraw(false,false);
    }
  }
  const def=getDef();
  if(state.host && state.host.isConnected!==false && def &&
     (state.lastPreviewTick==null || dueTick(now,state.lastPreviewTick,profile.previewFps))){
    state.lastPreviewTick=now;
    const key=`${def.id}:${selectedFrame(def)}:${parallelFrame(def,now)}`;
    if(key!==state.lastPreviewKey){
      state.lastPreviewKey=key;
      paintPanelPreview();
    }
  }
}
function frameFor(def,clockMs=performance.now()){
 return frameAt(def,clockMs,state?.animEpoch||0,state?.perfMode||'balanced');
}
function selectedFrame(def) {
  if (!state.playback.paused) return frameFor(def);
  return Math.min(Math.max(0,state.playback.frame),Math.max(0,def.frames-1));
}
function paintPanelPreview() {
  const host=state?.host,def=getDef();if(!host||!def)return;
  const canvas=host.querySelector('.ap-anim-canvas');
  if(!canvas || typeof canvas.getContext!=='function')return;
  const ctx=canvas.getContext('2d'); if(!ctx)return;
  const w=def.width*32,h=def.height*32;
  if(canvas.width!==w) canvas.width=w;
  if(canvas.height!==h)canvas.height=h;
  ctx.clearRect(0,0,w,h);
  const image=state.images.get(def.sheet),frame=selectedFrame(def);
  if(image?.ok&&image.img){ctx.imageSmoothingEnabled=false;
    ctx.drawImage(image.img,frame*w,0,w,h,0,0,w,h);
  }else{
    ctx.fillStyle='rgba(40,155,205,.13)';ctx.fillRect(0,0,w,h);
    ctx.fillStyle='#a9c8d8';ctx.font='14px sans-serif';ctx.fillText('PNG no cargado',10,20);
  }
  if(def.parallel?.enabled){
    const secondary=state.images.get(def.parallel.sheet);
    if(!secondary && def.parallel.sheet)void preloadImage(def.parallel.sheet);
    if(secondary?.ok&&secondary.img&&secondary.img.width===expectedTrackDimensions(def,def.parallel).width&&secondary.img.height===expectedTrackDimensions(def,def.parallel).height){
      ctx.save();ctx.globalAlpha=def.parallel.opacity/100;
      ctx.drawImage(secondary.img,parallelFrame(def)*w,0,w,h,0,0,w,h);ctx.restore();
    }
  }
  if(state.previewOnion && def.frames>1){
    // Draw neighboring frames as transparent ghosts in the inspector.
    ctx.save();ctx.globalAlpha=.16;
    const prev=(frame+def.frames-1)%def.frames,next=(frame+1)%def.frames;
    if(image?.ok&&image.img){
      ctx.drawImage(image.img,prev*w,0,w,h,-3,0,w,h);
      ctx.drawImage(image.img,next*w,0,w,h,3,0,w,h);
    }
    ctx.restore();
  }
  if(state.previewGrid){
    ctx.save();ctx.strokeStyle='rgba(255,255,255,.35)';ctx.lineWidth=1;
    for(let x=1;x<def.width;x++){ctx.beginPath();ctx.moveTo(x*32+.5,0);ctx.lineTo(x*32+.5,h);ctx.stroke();}
    for(let y=1;y<def.height;y++){ctx.beginPath();ctx.moveTo(0,y*32+.5);ctx.lineTo(w,y*32+.5);ctx.stroke();}
    ctx.restore();
  }
  if(state.previewCrop){
    const c=selectedCrop(def);ctx.save();ctx.strokeStyle='#f4d35e';ctx.lineWidth=2;
    ctx.strokeRect(c.x*32+1,c.y*32+1,c.w*32-2,c.h*32-2);ctx.restore();
  }
  canvas.style.width=`${w*(state.previewZoom||1)}px`;
  canvas.style.height=`${h*(state.previewZoom||1)}px`;
  updateTimelineFrame(def,frame);
  const info=host.querySelector('.ap-playing');
  if(info) info.textContent=`${state.playback.paused?'PAUSA':'REPRODUCIENDO'} · fotograma ${frame+1}/${def.frames} · ${def.fps} FPS`;
  const input=host.querySelector('.ap-scrub');
  if(input && !state.playback.paused) input.value=String(frame);
}
function updateTimelineFrame(def,frame){
 const host=state?.host;if(!host)return;
 for(const button of host.querySelectorAll('.ap-frame')){
   button.classList.toggle('active',Number(button.dataset.frame)===frame);
   button.setAttribute('aria-pressed',String(Number(button.dataset.frame)===frame));
 }
 for(const button of host.querySelectorAll('.ap-parallel-frame')){button.classList.toggle('active',Number(button.dataset.frame)===parallelFrame(def));}
 const clock=host.querySelector('.ap-playhead-clock');
 if(clock)clock.textContent=`${((frame/Math.max(1,def.fps))).toFixed(2)} s / ${(def.frames/Math.max(1,def.fps)).toFixed(2)} s`;
 const progress=host.querySelector('.ap-progress-fill');
 if(progress)progress.style.width=`${100*(frame+1)/Math.max(1,def.frames)}%`;
}
function paintTimelineFrames(){
 const host=state?.host,def=getDef();if(!host||!def)return;
 const cache=state.images.get(def.sheet);if(!cache?.ok||!cache.img)return;
 const w=def.width*32,h=def.height*32;
 for(const canvas of host.querySelectorAll('.ap-frame canvas')){
  const frame=Number(canvas.parentElement?.dataset.frame);if(!Number.isInteger(frame))continue;
  const c=canvas.getContext('2d');if(!c)continue;
  const scale=Math.min(56/w,50/h);c.clearRect(0,0,60,54);c.imageSmoothingEnabled=false;
  c.drawImage(cache.img,frame*w,0,w,h,(60-w*scale)/2,(54-h*scale)/2,w*scale,h*scale);
 }
}
function paintThumbnails(){
  const host=state?.host;if(!host)return;
  const elements=host.querySelectorAll?.('.ap-thumb')||[];
  for(const canvas of elements){
    if(typeof canvas.getContext!=='function')continue;
    const d=state.data.definitions.find(v=>v.id===canvas.dataset?.defid);if(!d)continue;
    const ctx=canvas.getContext('2d');if(!ctx)continue;
    ctx.clearRect(0,0,66,66);
    const pic=state.images.get(d.sheet);
    if(pic?.ok&&pic.img){
      const w=d.width*32,h=d.height*32,scale=Math.min(66/w,66/h);
      ctx.imageSmoothingEnabled=false;
      ctx.drawImage(pic.img,0,0,w,h,(66-w*scale)/2,(66-h*scale)/2,w*scale,h*scale);
    } else {ctx.fillStyle='#2b485c';ctx.fillRect(4,4,58,58);}
  }
}
function activeMap() { return state?.ctx.editor.activeMapId(); }
function status(message) {
  if (!state) return;
  state.lastAction = message;
  syncStatus();
}
function syncStatus() {
  if (!state?.host) return;
  const host=state.host, mapId=activeMap(), tool=state.ctx.editor.activeTool(), active=tool===TOOL;
  const a=host.querySelector('.ap-tool-status');
  if (a) a.textContent=mapId==null?'Sin mapa abierto':`Mapa ${mapId} · Modo ${active?'PROP ANIMADO':'TILES NORMALES'} · Capa activa ${(selectedPaintLayer(mapId)??-1)+1} · ${getDef()?.name||'sin prop'}`;
  const b=host.querySelector('.ap-last-action');
  if (b) b.textContent=state.lastAction || 'Selecciona un objeto y activa el pincel.';
  const c=host.querySelector('.ap-hover');
  if (c) c.textContent=state.hover&&state.hover.mapId===mapId?`Cursor (${state.hover.x}, ${state.hover.y}) · ${selectedCrop()?.w??0}×${selectedCrop()?.h??0} tiles`:'Cursor fuera del mapa';
  const diag=host.querySelector('.ap-input-diagnostic');
  if (diag)diag.textContent=`Lienzo integrado: ${state.canvasViews?.size||0} · clics: ${state.pointerEvents} · dibujo: ${state.overlayCalls}\nPNG: ${state.images.get(getDef()?.sheet)?.ok?'OK':state.images.get(getDef()?.sheet)?.error||'pendiente'} · ${state.lastPointer||'sin clics'} · coord:${state.pointerOrigin||'esperando'}`;
}
function ensureMap() {
  const id=activeMap();
  if (!Number.isInteger(id)) throw new Error('Abre un mapa antes de colocar un objeto animado.');
  return id;
}
function selectTool() {
  state.propsToolArmed=true;
  if (!getDef()) throw new Error('Selecciona un objeto en la biblioteca.');
  ensureMap();
  state.ctx.editor.setTool(TOOL);
  const ok=state.ctx.editor.activeTool()===TOOL;
  status(ok?(state.actionMode==='select'?'Edición activa: clic selecciona y arrastra para mover.':'Pincel listo: clic izquierdo coloca · Ctrl+clic elimina.'):'La herramienta no quedó seleccionada; utiliza el menú contextual del mapa.');
  toast(ok?(state.actionMode==='select'?'Edición de props activa.':'Pincel activo: haz clic en el mapa.'):'No se activó la herramienta.');
  redraw();
}

const clone=(v)=>JSON.parse(JSON.stringify(v));
function checkpoint() {
  state.undo.push(clone(state.data));
  if (state.undo.length>40) state.undo.shift();
  state.redo.length=0;
}
function undo() {
  if (!state?.undo?.length) return;
  state.redo.push(clone(state.data)); state.data=state.undo.pop();invalidateRenderIndex();
  if (!getDef()) state.selected=state.data.definitions[0]?.id || '';
  refresh(); redraw(); void persist().catch(problem);
}
function redo() {
  if (!state?.redo?.length) return;
  state.undo.push(clone(state.data)); state.data=state.redo.pop();invalidateRenderIndex();
  if (!getDef()) state.selected=state.data.definitions[0]?.id || '';
  refresh(); redraw(); void persist().catch(problem);
}
// Native Maker Studio undo groups only track native map edits. Animated Props
// writes a separate JSON file, so intercept Undo only when this mod owns the
// active tool AND a local snapshot is available. Other tools remain untouched.
export function shouldHandleHistoryKey(event, active, hasUndo, hasRedo){
  if(!active||!event||!(event.ctrlKey||event.metaKey)||event.altKey)return null;
  const target=event.target;
  if(target?.isContentEditable||target?.closest?.('input,textarea,select,[contenteditable="true"],[role="textbox"]'))return null;
  const key=String(event.key||'').toLowerCase();
  if(key==='z' && !event.shiftKey && hasUndo)return 'undo';
  if(((key==='z'&&event.shiftKey)||key==='y') && hasRedo)return 'redo';
  return null;
}
function installHistoryKeys(){
  if(typeof window==='undefined'||typeof window.addEventListener!=='function')return;
  const onKey=e=>{
    if(handlePropToolKey(e))return;
    const action=shouldHandleHistoryKey(e,toolActive(),!!state?.undo?.length,!!state?.redo?.length);
    if(!action)return;
    e.preventDefault?.();e.stopPropagation?.();e.stopImmediatePropagation?.();
    if(action==='undo')undo();else redo();
  };
  window.addEventListener('keydown',onKey,true);
  state.historyKeyCleanup=()=>window.removeEventListener?.('keydown',onKey,true);
}
async function persist() {
  if (state.readError) throw new Error('El archivo JSON está dañado. No se sobrescribirá automáticamente.');
  invalidateRenderIndex();
 const snapshot=clone(normalizeData(state.data));
  const content=JSON.stringify(snapshot,null,2)+'\n';
  // Serialize writes: two paint operations cannot race and overwrite each other.
  state.writer=state.writer.catch(()=>{}).then(async()=>{
    await state.ctx.fs.projectMkdir('Data/AnimatedProps');
    await state.ctx.fs.writeProjectFile(FILE,content);
  });
  await state.writer;
}
async function loadData() {
  const fs=state.ctx.fs;
  if (!(await fs.projectExists(FILE))) return defaultData();
  const raw=await fs.readProjectFile(FILE);
  return normalizeData(JSON.parse(raw));
}
function pathFor(sheet) { return `${ART_DIR}/${cleanSheet(sheet)}`; }
function imageUrl(sheet) {
  const c=state.images.get(sheet);
  return c && c.ok ? c.url : null;
}
async function preloadImage(sheet, force=false) {
  cleanSheet(sheet);
  if (state.images.has(sheet) && !force) return state.images.get(sheet)?.promise;
  const existing=state.images.get(sheet);
  if (existing?.url?.startsWith('blob:')) URL.revokeObjectURL(existing.url);
  const c={img:null,url:null,ok:false,promise:null}; state.images.set(sheet,c);
  c.promise=(async()=>{
    try {
      const invoke=window.__TAURI__?.core?.invoke;
      if (!invoke) throw new Error('Esta versión no expone la API de lectura binaria de Tauri.');
      const projectRoot=state.ctx.editor.gameRoot();
      if(!projectRoot)throw new Error('Maker Studio no informa la raíz del proyecto; abre un proyecto antes de importar PNG.');
      const root=projectRoot.replace(/[\\/]+$/,'');
      const sep=root.includes('\\')?'\\':'/';
      const rel=pathFor(sheet);
      if(!(await state.ctx.fs.projectExists(rel)))throw new Error(`No existe ${rel}; importa el PNG o copia el recurso al proyecto.`);
      const abs=`${root}${sep}${ART_DIR.replaceAll('/',sep)}${sep}${sheet}`;
      // Método soportado por la API publicada de Maker Studio.
      // Algunas instalaciones restringen el protocolo blob:; cuando falla,
      // intentar el asset URL de Tauri (si está disponible).
      let binaryError=null;
      try {
        const bytes=await invoke('read_binary_file',{path:abs});
        state.imageStamps.set(sheet,pngFingerprint(bytes));
        const url=URL.createObjectURL(new Blob([Uint8Array.from(bytes)],{type:'image/png'}));
        const img=new Image();
        try{
          await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(new Error('No se pudo decodificar el PNG con blob URL.'));img.src=url;});
          c.img=img;c.url=url;c.ok=true;
        }catch(e){URL.revokeObjectURL(url);throw e;}
      }catch(e){binaryError=e;}
      if(!c.ok){
        const toAsset=window.__TAURI__?.core?.convertFileSrc;
        if(typeof toAsset!=='function')throw binaryError||new Error('No se pudo acceder a la imagen.');
        const url=toAsset(abs);
        const img=new Image();
        try{
          await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(new Error('El protocolo de assets tampoco permite abrir este PNG.'));img.src=url;});
          c.img=img;c.url=url;c.ok=true;
        }catch(e){throw new Error(`${binaryError?.message||binaryError||'Lectura PNG fallida'}; alternativa asset: ${e.message}`);}
      }
    } catch(e){c.error=String(e.message||e);}
    refreshPreview();
    redraw();
    paintPanelPreview();paintThumbnails();paintTimelineFrames();
    return c;
  })();
  return c.promise;
}
async function refreshGraphics({force=false,fullScan=false}={}){
  if(!state||state.reloadingGraphics)return [];
  const s=state;s.reloadingGraphics=true;
  try{
    const current=activeMap(),names=new Set();
    const used=new Set((s.data.placements[String(current)]||[]).map(p=>p.defId));
    for(const d of s.data.definitions){
      if(d.id===s.selected || used.has(d.id)){
        if(d.sheet)names.add(d.sheet);
        if(d.parallel?.enabled&&d.parallel.sheet)names.add(d.parallel.sheet);
      }
    }
    if(force){
      for(const name of names)await preloadImage(name,true);
      s.lastMapFrameKey=null;
      refreshPreview();paintPanelPreview();paintThumbnails();paintTimelineFrames();redraw();
      return [...names];
    }
    const invoke=window.__TAURI__?.core?.invoke,root=s.ctx.editor.gameRoot?.();
    if(!invoke||!root)return [];
    const selected=s.data.definitions.find(d=>d.id===s.selected);
    const priority=[selected?.sheet,selected?.parallel?.enabled?selected.parallel.sheet:null].filter(Boolean);
    const other=[...names].filter(n=>!priority.includes(n));
    const offset=s.scanCursor%Math.max(1,other.length);
    const sampled=force||fullScan? [...names]:[...priority,...Array.from({length:Math.min(3,other.length)},(_,i)=>other[(offset+i)%other.length])];
    s.scanCursor+=3;
    const modified=await checkPngUpdates({names:sampled,stamps:s.imageStamps,
      read:name=>invoke('read_binary_file',{path:projectPngAbsolute(root,ART_DIR,name)}),
      onChanged:async name=>{await preloadImage(name,true);}});
    if(modified.length){
      s.lastMapFrameKey=null;
      refreshPreview();paintPanelPreview();paintThumbnails();paintTimelineFrames();redraw();
      if(s.host)status(`PNG actualizado: ${modified.join(', ')}`);
    }
    return modified;
  }finally{if(state===s)s.reloadingGraphics=false;}
}
function refreshPreview() {
  if (!state?.host) return;
  const preview=state.host.querySelector('.ap-preview');
  if (!preview) return;
  const d=getDef(), url=d && imageUrl(d.sheet);
  preview.hidden=!url;
  if (url) { preview.src=url; preview.title='Spritesheet original (todos los fotogramas)'; }
  const indicator=state.host.querySelector('.ap-preview-status');
  if(indicator&&d){
    const pic=state.images.get(d.sheet);
    const expectedWidth=d.width*32*d.frames, expectedHeight=d.height*32;
    if (!pic) indicator.textContent='Esperando lectura del PNG…';
    else if(pic.error) indicator.textContent=`No se pudo leer ${d.sheet}: ${pic.error}`;
    else if(pic.ok){
      const actual=`${pic.img.width}×${pic.img.height}`;
      indicator.textContent=pic.img.width===expectedWidth&&pic.img.height===expectedHeight?
        `Gráfico correcto: ${actual} px`:`AVISO: gráfico ${actual} px, esperado ${expectedWidth}×${expectedHeight} px`;
    } else indicator.textContent='Cargando PNG…';
  }
}
async function importPNG(target='primary') {
  const ctx=state.ctx;
  const picks=await ctx.ui.showFilePicker?.({filters:[{name:'PNG',extensions:['png']}]});
  if (!picks?.length) return;
  const src=picks[0];
  const sheet=cleanSheet(src.replaceAll('\\','/').split('/').pop());
  const dest=pathFor(sheet);
  if (await ctx.fs.projectExists(dest)) {
    const ok=await ctx.ui.showConfirmDialog({title:'Sobrescribir gráfico',message:`Ya existe ${sheet}. ¿Reemplazarlo?`});
    if (!ok) return;
  }
  const invoke=window.__TAURI__?.core?.invoke;
  if (!invoke) throw new Error('La importación requiere la API nativa de Maker Studio.');
  await ctx.fs.projectMkdir(ART_DIR);
  const root=ctx.editor.gameRoot().replace(/[\\/]+$/,'');
  const sep=root.includes('\\')?'\\':'/';
  await invoke('copy_file',{src,dst:`${root}${sep}${ART_DIR.replaceAll('/',sep)}${sep}${sheet}`});
  if (getDef()) { checkpoint(); if(target==='parallel'){getDef().parallel={...getDef().parallel,sheet,enabled:true};}else{getDef().sheet=sheet;} await persist(); }
  await preloadImage(sheet,true);
  refresh(); toast(`Gráfico importado: ${sheet}`);
}
async function place(mapId,x,y,remove=false) {
  if (!Number.isInteger(mapId)||!Number.isInteger(x)||!Number.isInteger(y))
    throw new Error('Mapa y coordenadas deben ser números enteros.');
  if (state.readError) throw new Error('No se puede editar mientras objects.json tenga errores.');
  const info=state.ctx.map.info(mapId);
  if (!info) throw new Error(`No está abierto el mapa ${mapId}.`);
  if (x<0||y<0||x>=info.width||y>=info.height)
    throw new Error(`(${x},${y}) está fuera del mapa (${info.width}×${info.height}).`);
  const key=String(mapId);
  const list=state.data.placements[key] ||= [];
  const layer=selectedPaintLayer(mapId);
  if(layer==null)throw new Error('No hay capas normales ni extendidas disponibles para pintar.');
  const candidate=layerProps(mapId,layer);
  if(candidate.visible===false)throw new Error('La capa de props seleccionada está oculta.');
  // La selección del mod es independiente de las subfilas virtuales de sombras.
  // Nunca se convierten sus índices en capas de tiles.
  if (remove) {
    const found=activeLayerPlacementAt(state.data,mapId,x,y,layer);
    if (!found) {status(`No hay un prop en la capa ${layer+1} en (${x},${y}).`);return false;}
    checkpoint();
    const index=list.indexOf(found),definition=state.data.definitions.find(d=>d.id===found.defId);
    list.splice(index,1,...subtractPlacementArea(found,definition,{x,y,w:1,h:1},()=>`cut_${Date.now().toString(36)}_${++state.serial}`));
    status(`Celda eliminada en (${x}, ${y}) · capa ${layer+1}.`);
  } else {
    const d=getDef();if(!d) throw new Error('Selecciona un objeto en la biblioteca.');
    const crop=selectedCrop(d);
    const loaded=await preloadImage(d.sheet);
    if(!loaded?.ok)throw new Error(`No se ha podido cargar Graphics/AnimatedProps/${d.sheet}: ${loaded?.error||'error de PNG'}`);
    if(loaded.img.width!==d.width*32*d.frames||loaded.img.height!==d.height*32)
      throw new Error(`Dimensiones incompatibles: ${d.sheet} mide ${loaded.img.width}×${loaded.img.height}; esperado ${d.width*32*d.frames}×${d.height*32}.`);
    if(!validatePosition(d,x,y,info,crop))
      throw new Error(`${d.name} (${crop.w}×${crop.h}) no cabe en (${x},${y}); mapa ${info.width}×${info.height}.`);
    checkpoint();
    const area={x,y,w:crop.w,h:crop.h};
    const result=[];
    for(const old of list){
      if(old.layer!==layer){result.push(old);continue;}
      const oldDef=state.data.definitions.find(t=>t.id===old.defId);
      result.push(...subtractPlacementArea(old,oldDef,area,()=>`cut_${Date.now().toString(36)}_${++state.serial}`));
    }
    result.push({id:`${Date.now().toString(36)}_${(++state.serial).toString(36)}`,defId:d.id,x,y,layer,crop});
    state.data.placements[key]=result;
    status(`Pintado ${d.name}: (${x},${y}) · capa ${layer+1} · ${crop.w}×${crop.h} tiles.`);
  }
  // Keep viewport and library consistent even if the disk write takes time.
  paintBoundCanvases();redraw();refreshCounts();syncStatus();
  await persist();
  return true;
}
function attachLabel(parent,name,value,callback,type='text', min, max){
  const label=el('label',name,{className:'ap-label'});
  const input=el('input',null,{className:'ap-input',type,value:String(value)});
  if (min!=null) input.min=String(min);
  if (max!=null) input.max=String(max);
  input.addEventListener('change',async()=>{try{await callback(type==='number'?Number(input.value):input.value);}catch(e){problem(e);refresh();}});
  label.appendChild(input);parent.appendChild(label);return input;
}
async function newDefinition() {
  const name=await state.ctx.ui.showInputDialog({title:'Nuevo objeto animado',message:'Nombre (p. ej., Molino de viento)',defaultValue:'Molino de viento'});
  if (name===null)return;
  const id=slug(name);
  if (!id)throw Error('Escribe un nombre válido.');
  if (state.data.definitions.some(d=>d.id===id))throw Error(`Ya existe ${id}.`);
  const d=makeDefinition({id,name,sheet:`${id}.png`,width:4,height:4,frames:4,fps:6});
  checkpoint();state.data.definitions.push(d);state.selected=d.id;
  await persist();refresh();redraw();
}
async function deleteDefinition(){
  const d=getDef();if(!d)return;
  const affected=Object.values(state.data.placements).reduce((n,p)=>n+p.filter(x=>x.defId===d.id).length,0);
  const ok=await state.ctx.ui.showConfirmDialog({title:'Eliminar objeto',message:`Eliminar ${d.name} y sus ${affected} colocaciones en los mapas?`});
  if(!ok)return;
  checkpoint();state.data.definitions=state.data.definitions.filter(x=>x!==d);
  for(const key of Object.keys(state.data.placements))state.data.placements[key]=state.data.placements[key].filter(p=>p.defId!==d.id);
  state.selected=state.data.definitions[0]?.id||'';
  await persist();refresh();redraw();
}
async function editDefinition(patch){
  const d=getDef();if(!d)return;
  checkpoint();
  const width=patch.width??d.width,height=patch.height??d.height;
  const cells=[];
  for(let y=0;y<height;y++)for(let x=0;x<width;x++)
    cells.push(x<d.width&&y<d.height?d.cells[y*d.width+x]:{passage:0,priority:0,terrainTag:0});
  const next=makeDefinition({...d,...patch,cells});
  if(next.id!==d.id) throw Error('El ID de un objeto existente no se puede cambiar.');
  Object.assign(d,next);
  await persist();
  await preloadImage(d.sheet);
  if(d.parallel?.enabled&&d.parallel.sheet)await preloadImage(d.parallel.sheet);
  refresh();redraw();
}
async function migrateFromNative(){
  const mapId=ensureMap(),info=state.ctx.map.info(mapId);
  const refs=scanNativeRefs(state.ctx.map,mapId,info,mapLayers(mapId));
  if(!refs.length){toast('No quedan referencias LBDSAP_ en este mapa.');return;}
  const known=nativeRefsAsPlacements(refs,state.data.definitions,mapId);
  if(!known.placements.length){throw new Error(`${refs.length} autotiles antiguos encontrados, pero ninguno coincide con una celda válida del spritesheet configurado. No se cambió nada.`);}
  const confirm=await state.ctx.ui.showConfirmDialog({title:'Recuperar props anteriores',message:`Se encontraron ${refs.length} referencias 0.4.x, de las cuales ${known.placements.length} se pueden restaurar desde Graphics/AnimatedProps. Esta acción importará las celdas a objects.json. Las referencias viejas serán limpiadas del mapa (hay que guardar el mapa después). Haz copia de seguridad del mapa antes de continuar.`});
  if(!confirm)return;
  const mark=new Date().toISOString().replace(/[:.]/g,'-');
  const backupDir='Data/AnimatedProps/backups';
  await state.ctx.fs.projectMkdir(backupDir);
  await state.ctx.fs.writeProjectFile(`${backupDir}/before-native-map-${mapId}-${mark}.json`,JSON.stringify(state.data,null,2));
  await state.ctx.fs.writeProjectFile(`${backupDir}/native-refs-map-${mapId}-${mark}.json`,JSON.stringify(refs,null,2));
  checkpoint();
  const list=state.data.placements[String(mapId)]||[];
  const occupied=new Set(list.map(p=>`${p.layer}:${p.x}:${p.y}:${p.defId}:${JSON.stringify(p.crop||{})}`));
  let added=0;
  for(const p of known.placements){
    const key=`${p.layer}:${p.x}:${p.y}:${p.defId}:${JSON.stringify(p.crop||{})}`;
    if(!occupied.has(key)){list.push(p);occupied.add(key);added++;}
  }
  state.data.placements[String(mapId)]=list;
  await persist(); // XML/rxdata is NOT changed until JSON has been safely saved.
  const map=state.ctx.map;
  const restoredKeys=new Set(known.placements.map(p=>`${p.layer}:${p.x}:${p.y}`));
  map.beginUndoGroup?.('Limpiar referencias antiguas de Animated Props');
  try{
    for(const ref of refs){
      if(!restoredKeys.has(`${ref.layer}:${ref.x}:${ref.y}`))continue; // nunca borrar celdas sin correspondencia
      if(ref.layer<3){
        map.writeTile?.(mapId,ref.layer,ref.x,ref.y,0,'Eliminar autotile obsoleto');
        map.setNativeTileProperties?.(mapId,ref.layer,ref.x,ref.y,{autotileName:'',autotilePattern:0});
      } else map.writeTileData?.(mapId,ref.layer,ref.x,ref.y,{tileId:0,autotileName:''},'Eliminar autotile obsoleto');
    }
  }finally{map.endUndoGroup?.();}
  status(`Importadas ${added} celdas desde 0.4.x. Pulsa Ctrl+S para guardar el mapa. Copia de seguridad en ${backupDir}.`);
  refresh();paintBoundCanvases();redraw();
  toast(`Recuperadas ${added} celdas; ${known.invalid.length} celdas sin fuente válida. Guarda el mapa con Ctrl+S.`);
}

function refreshCounts() {
  const counter=state.host?.querySelector('.ap-count');
  if(!counter)return;
  const active=state.ctx.editor.activeMapId();
  counter.textContent=`Mapa ${active??'—'} · ${(state.data.placements[String(active)]||[]).length} objetos colocados`;
  updateLayerCount();
}
function renderPlacementControls(sidebar) {
  sidebar.append(el('h4','Colocación y objetos del mapa'));
  const layers=paintLayers();
  const activeLayer=selectedPaintLayer();
  const layerLine=el('div',null,{className:'ap-row'});
  layerLine.append(el('span','Capa de pintura del prop:'));
  const select=el('select',null,{className:'ap-input ap-paint-layer'});
  select.style.width='auto';
  for(const layer of layers){select.append(el('option',`${layer.index+1} · ${layer.name||'Capa'} (${layer.kind==='native'?'normal':'extendida'})${layer.visible===false?' [oculta]':''}`,{value:String(layer.index)}));}
  if(activeLayer!=null) select.value=String(activeLayer);
  select.onchange=()=>setPaintLayer(activeMap(),Number(select.value),true);
  if(layers.length)layerLine.append(select);
  else layerLine.append(el('span','No hay capas de tiles disponibles.'));
  sidebar.append(layerLine);
  const box=el('div',null,{className:'ap-status'});
  box.append(el('div','',{className:'ap-tool-status'}));
  box.append(el('div','',{className:'ap-hover'}));
  box.append(el('div','',{className:'ap-last-action'}));
  sidebar.append(box);
  const toggles=el('div',null,{className:'ap-row'});
  const check=el('input',null,{type:'checkbox',checked:state.showOverlay});
  check.onchange=()=>{state.showOverlay=check.checked;redraw();};
  const lab=el('label','Mostrar gráficos y límites en el mapa');lab.prepend(check);
  toggles.append(lab);sidebar.append(toggles);
  const cut=el('input',null,{type:'checkbox',checked:state.maskHigherTiles});
  cut.onchange=()=>{state.maskHigherTiles=cut.checked;invalidateLayerMask();redraw();};
  const cutLabel=el('label',' Respetar tiles de capas superiores (recorte por celda)');
  cutLabel.prepend(cut);sidebar.append(cutLabel);
  const coords=el('div',null,{className:'ap-row'});
  coords.append(el('span','Colocar en:'));
  const x=el('input',null,{className:'ap-input ap-numeric',type:'number',value:String(state.coords.x),min:'0',placeholder:'X'});
  const y=el('input',null,{className:'ap-input ap-numeric',type:'number',value:String(state.coords.y),min:'0',placeholder:'Y'});
  x.title='Coordenada X';y.title='Coordenada Y';
  x.onchange=()=>{state.coords.x=Number(x.value);};
  y.onchange=()=>{state.coords.y=Number(y.value);};
  coords.append('X:',x,'Y:',y);
  coords.append(btn('Colocar aquí',async()=>{
    const mapId=ensureMap();
    await place(mapId,Number(x.value),Number(y.value));
    toast(state.lastAction);
  },true));
  sidebar.append(coords);
  sidebar.append(el('p','Ancla: esquina superior izquierda. En modo Seleccionar / mover, arrastra un objeto directamente en el mapa.',{className:'ap-note'}));
  const selected=getSelectedPlacement(activeMap());
  const editor=el('div',null,{className:'ap-card'});
  editor.append(el('strong',selected?`Editar objeto: (${selected.x},${selected.y}) · L${selected.layer+1}`:'Selecciona un objeto en el mapa'));
  const editRow=el('div',null,{className:'ap-row'});
  const nx=el('input',null,{className:'ap-input ap-numeric',type:'number',value:String(selected?.x??0),min:'0'});
  const ny=el('input',null,{className:'ap-input ap-numeric',type:'number',value:String(selected?.y??0),min:'0'});
  nx.title='Nueva posición X';ny.title='Nueva posición Y';
  editRow.append('X:',nx,'Y:',ny);
  editRow.append(btn('Mover',()=>relocateSelected(activeMap(),Number(nx.value),Number(ny.value)),true));
  editRow.append(btn('Eliminar objeto',deleteSelected));
  for(const b of editRow.querySelectorAll?.('button')||[])b.disabled=!selected;
  editor.append(editRow);sidebar.append(editor);
  const active=activeMap();
  const placements=state.data.placements[String(active)]||[];
  const defs=new Map(state.data.definitions.map(d=>[d.id,d]));
  const rows=el('div',null,{className:'ap-placed-list'});
  if(!placements.length)rows.append(el('div','Aún no hay objetos colocados en este mapa.',{className:'ap-note'}));
  for(const p of [...placements].reverse()){
    const item=el('div',null,{className:'ap-placed-row'});
    const def=defs.get(p.defId);
    const crop=def?cropFor(def,p.crop):null;
    item.append(el('span',`${def?.name||p.defId} · (${p.x},${p.y}) · ${crop?.w||'?'}×${crop?.h||'?'} · capa ${p.layer+1}`));
    item.append(btn('Ver',()=>{
      state.selectedPlacedId=p.id;
      state.coords={x:p.x,y:p.y};
      if(def){state.selected=def.id;state.crops.set(def.id,cropFor(def,p.crop));}
      state.hover={mapId:active,x:p.x,y:p.y};
      state.actionMode='select';state.drag=null;
      state.ctx.editor.setTool(TOOL);
      status(`Seleccionado: ${def?.name||p.defId} en (${p.x},${p.y}). Puedes arrastrarlo o editar X/Y.`);
      refresh();redraw();
    }));
    item.append(btn('Actualizar región',async()=>{
      if(!def)return;
      checkpoint();p.crop=selectedCrop(def);
      if(!validatePosition(def,p.x,p.y,state.ctx.map.info(active),p.crop)){
        state.undo.pop();throw Error('La región elegida no cabe en la posición actual.');
      }
      await persist();refresh();redraw();
    }));
    item.append(btn('Capa ↑',async()=>{
      const next=adjacentPaintLayer(mapLayers(active),state.ctx.map.info(active),p.layer,1);
      if(next==null)return;
      checkpoint();p.layer=next;await persist();refresh();redraw();
    }));
    item.append(btn('Capa ↓',async()=>{
      const prev=adjacentPaintLayer(mapLayers(active),state.ctx.map.info(active),p.layer,-1);
      if(prev==null)return;
      checkpoint();p.layer=prev;await persist();refresh();redraw();
    }));
    item.append(btn('Eliminar',async()=>{
      const index=(state.data.placements[String(active)]||[]).findIndex(v=>v.id===p.id);
      if(index<0)return;
      checkpoint();state.data.placements[String(active)].splice(index,1);
      status(`Eliminado: ${def?.name||p.defId} en (${p.x},${p.y}).`);
      refresh();redraw();await persist();
    }));
    if(p.id===state.selectedPlacedId)item.classList.add('active');
    rows.append(item);
  }
  sidebar.append(rows);
  syncStatus();
}

function gridCellLabel(cell,mode){
  if(mode==='passage')return (cell.passage&15)===15?'✕':(cell.passage&15)?`0x${(cell.passage&15).toString(16)}`:'○';
  if(mode==='priority')return `P${cell.priority}`;
  if(mode==='terrainTag')return `T${cell.terrainTag}`;
  if(mode==='bush')return cell.passage&0x40?'B':'·';
  return cell.passage&0x80?'C':'·';
}
function renderGrid(host,d){
  const choices=el('div',null,{className:'ap-row'});
  const mode=el('select',null,{className:'ap-input'});mode.style.width='auto';
  for(const [id,label] of [['passage','Pasabilidad'],['priority','Prioridad'],['terrainTag','Terrain Tag'],['bush','Arbusto'],['counter','Mostrador']])
    mode.appendChild(el('option',label,{value:id}));
  mode.value=state.mode;
  mode.onchange=()=>{state.mode=mode.value;refresh();};
  choices.append('Editar:',mode);host.append(choices);
  const dir=el('div',null,{className:'ap-note'});
  dir.textContent='Pasabilidad: ○ libre, ✕ bloqueado; clic alterna. Shift+clic recorre máscaras direccionales 0–15 (abajo=1, izquierda=2, derecha=4, arriba=8).';
  host.append(dir);
  const grid=el('div',null,{className:'ap-grid'});grid.style.gridTemplateColumns=`repeat(${d.width},32px)`;
  for(let i=0;i<d.cells.length;i++){
    const cell=d.cells[i];const button=el('button',gridCellLabel(cell,state.mode),{type:'button',className:'ap-cell'});
    // Like the native tileset-property editor: visual cell underneath the marker.
    const url=imageUrl(d.sheet);
    if(url){
      const col=i%d.width,row=Math.floor(i/d.width);
      button.style.backgroundImage=`linear-gradient(rgba(15,30,40,.15),rgba(15,30,40,.15)),url("${url}")`;
      button.style.backgroundSize=`32px 32px, ${d.width*32*d.frames}px ${d.height*32}px`;
      button.style.backgroundPosition=`0px 0px, ${-col*32}px ${-row*32}px`;
      button.style.imageRendering='pixelated';
    }

    if((cell.passage&15)===15)button.classList.add('block');
    else if(cell.passage&15)button.classList.add('partial');
    button.title=`(${i%d.width}, ${Math.floor(i/d.width)}) · paso ${cell.passage&15} · prioridad ${cell.priority} · terreno ${cell.terrainTag}`;
    button.onclick=async(ev)=>{try{
      checkpoint();
      if(state.mode==='passage'){
        const raw=cell.passage&15;
        cell.passage=(cell.passage&~15) | (ev.shiftKey?((raw+1)&15):(raw===0?15:0));
      } else if(state.mode==='priority')cell.priority=(cell.priority+1)%6;
      else if(state.mode==='terrainTag'){
        const raw=await state.ctx.ui.showInputDialog({title:'Terrain Tag',message:'Número de terreno de la Base de Sky (0–999)',defaultValue:String(cell.terrainTag)});
        if(raw===null){state.undo.pop();return;}
        const n=Number(raw);if(!Number.isInteger(n)||n<0||n>999)throw Error('Terrain Tag debe ser un entero 0–999.');cell.terrainTag=n;
      } else if(state.mode==='bush')cell.passage^=0x40;
      else cell.passage^=0x80;
      await persist();refresh();redraw();
    }catch(e){problem(e);}};
    grid.appendChild(button);
  }
  const wrap=el('div');wrap.style.overflow='auto';wrap.appendChild(grid);host.append(wrap);
}
function updateRegionReadout(d, preview=null) {
  const c=preview||selectedCrop(d);
  const label=state.host?.querySelector('.ap-crop-label');
  if(label) label.textContent=`Selección: (${c.x},${c.y}) · ${c.w}×${c.h} tiles · ${c.w*32}×${c.h*32} px. Arrastra para marcar una región.`;
  const zoomLabel=state.host?.querySelector('.ap-selection-zoom');
  if(zoomLabel) zoomLabel.textContent=`Zoom ${Math.round((state.selectionZoom||1)*100)}%`;
}
function renderRegionSelector(container,d){
  const crop=selectedCrop(d);
  container.append(el('h4','Elegir parte del gráfico para pintar'));
  container.append(el('p','',{className:'ap-note ap-crop-label'}));
  const controls=el('div',null,{className:'ap-button-row'});
  // Do not recreate the panel when changing the selection. That used to reset
  // both the scroll position and the canvas pointer capture mid-drag.
  const reset=btn('Todo el objeto',()=>{
    const c={x:0,y:0,w:d.width,h:d.height};state.crops.set(d.id,c);
    updateRegionReadout(d);paintRegionSelection(image,d);redraw();
  });
  controls.append(reset);
  controls.append(el('span',`Zoom ${Math.round((state.selectionZoom||1)*100)}%`,{className:'ap-note ap-selection-zoom'}));
  for(const [label,z] of [['−',-1],['+',1]]){
    const b=btn(label,()=>{
      const at=SELECT_ZOOMS.indexOf(state.selectionZoom||1);
      state.selectionZoom=SELECT_ZOOMS[Math.max(0,Math.min(SELECT_ZOOMS.length-1,at+z))];
      resizeSelectionCanvas();updateRegionReadout(d);
    });
    b.title=label==='+'?'Acercar selector de tiles':'Alejar selector de tiles';
    controls.append(b);
  }
  container.append(controls);
  const wrap=el('div',null,{className:'ap-sheet-wrap'});
  const image=el('canvas',null,{className:'ap-sheet-region',width:d.width*32,height:d.height*32});
  image.draggable=false;
  const resizeSelectionCanvas=()=>{
    const zoom=state.selectionZoom||1;
    // Always scale BOTH dimensions equally, never CSS max-width only.
    image.style.width=`${Math.round(d.width*32*zoom)}px`;
    image.style.height=`${Math.round(d.height*32*zoom)}px`;
  };
  resizeSelectionCanvas();
  let start=null, pointerId=null, preview=null;
  const locate=e=>tileAtClientPoint(e,image.getBoundingClientRect(),d.width,d.height);
  const paintSelection=(c)=>{
    preview=c;state.selectionDrag={canvas:image,defId:d.id,crop:c};
    paintRegionSelection(image,d,c);updateRegionReadout(d,c);
  };
  const begin=(e)=>{
    if(e.button!==0||start)return;
    const here=locate(e);if(!here)return;
    e.preventDefault?.();e.stopPropagation?.();
    start=here;pointerId=e.pointerId;
    image.setPointerCapture?.(pointerId);
    paintSelection(regionFromPoints(here,here));
  };
  const previewDrag=(e)=>{
    if(!start||(e.pointerId!=null&&pointerId!=null&&e.pointerId!==pointerId))return;
    e.preventDefault?.();e.stopPropagation?.();
    const end=locate(e)||start;
    paintSelection(regionFromPoints(start,end));
  };
  const finish=(e)=>{
    if(!start||(e.pointerId!=null&&pointerId!=null&&e.pointerId!==pointerId))return;
    e.preventDefault?.();e.stopPropagation?.();
    const end=locate(e)||start;
    const c=regionFromPoints(start,end);
    state.crops.set(d.id,c);
    start=null;preview=null;state.selectionDrag=null;
    if(pointerId!=null&&image.hasPointerCapture?.(pointerId))image.releasePointerCapture(pointerId);
    pointerId=null;
    paintRegionSelection(image,d);updateRegionReadout(d);redraw();
    // No refresh(): the selector stays at its exact scroll and drag position.
  };
  const cancel=(e)=>{
    if(!start)return;
    start=null;pointerId=null;preview=null;state.selectionDrag=null;
    paintRegionSelection(image,d);updateRegionReadout(d);
  };
  image.addEventListener('pointerdown',begin);
  image.addEventListener('pointermove',previewDrag);
  image.addEventListener('pointerup',finish);
  image.addEventListener('pointercancel',cancel);
  image.addEventListener('lostpointercapture',cancel);
  wrap.append(image);container.append(wrap);
  updateRegionReadout(d);paintRegionSelection(image,d,crop);
}
function paintRegionSelection(canvas,d,preview=null){
  const g=canvas.getContext?.('2d');if(!g)return;
  const w=d.width*32,h=d.height*32;
  g.clearRect(0,0,w,h);
  const pic=state.images.get(d.sheet),frame=selectedFrame(d);
  if(pic?.ok&&pic.img){g.imageSmoothingEnabled=false;g.drawImage(pic.img,frame*w,0,w,h,0,0,w,h);}
  else{g.fillStyle='rgba(70,120,160,.4)';g.fillRect(0,0,w,h);}
  const c=preview||selectedCrop(d);
  g.fillStyle='rgba(0,0,0,.43)';
  g.fillRect(0,0,w,c.y*32);g.fillRect(0,(c.y+c.h)*32,w,h-(c.y+c.h)*32);
  g.fillRect(0,c.y*32,c.x*32,c.h*32);
  g.fillRect((c.x+c.w)*32,c.y*32,w-(c.x+c.w)*32,c.h*32);
  g.strokeStyle='#ffdb4a';g.lineWidth=2;g.strokeRect(c.x*32+1,c.y*32+1,c.w*32-2,c.h*32-2);
  g.strokeStyle='rgba(255,255,255,.42)';g.lineWidth=.6;
  for(let x=1;x<d.width;x++){g.beginPath();g.moveTo(x*32,0);g.lineTo(x*32,h);g.stroke();}
  for(let y=1;y<d.height;y++){g.beginPath();g.moveTo(0,y*32);g.lineTo(w,y*32);g.stroke();}
}
function parallelFrame(def,now=performance.now(),id=null){
  const track=def?.parallel;
  if(!track?.enabled)return 0;
  if(state?.perfMode==='static')return 0;
  if(state?.playback?.paused && id===null)return Math.min(track.frames-1,state.playback.parallelFrame||0);
  const cap=getProfile(state?.perfMode||'balanced').mapFps;
  const elapsed=Math.max(0,now-(state?.animEpoch||0));
  const quantized=cap>0?Math.floor(elapsed*cap/1000)/cap:0;
  const phase=(track.phase||0)+(id!==null&&def.timingMode==='independent'?cachedPlacementPhase(id,track.frames):0);
  return animationFrame(track,quantized,phase);
}
function renderParallelControls(host,d){
  const parallel=normalizeParallel(d.parallel);
  const wrap=el('section',null,{className:'ap-settings-section'});
  wrap.append(el('div','REPRODUCCIÓN Y PISTAS',{className:'ap-control-heading'}));
  const mode=btn(d.timingMode==='independent'?'◉ Copias desincronizadas':'◯ Copias sincronizadas',()=>editDefinition({timingMode:d.timingMode==='independent'?'synchronized':'independent'}));
  wrap.append(mode,el('p','Las copias desincronizadas arrancan en fases diferentes sin detener ni modificar la animación principal.',{className:'ap-secondary-note'}));
  const enable=btn(parallel.enabled?'☑ Pista paralela habilitada':'□ Añadir animación paralela',()=>{
    const next={...parallel,enabled:!parallel.enabled};
    if(next.enabled&&!next.sheet){next.sheet=d.sheet;next.frames=d.frames;next.fps=d.fps;}
    return editDefinition({parallel:next});
  });wrap.append(enable);
  if(parallel.enabled){
    const box=el('div',null,{className:'ap-fields'});
    const patch=(key,value)=>editDefinition({parallel:{...parallel,[key]:value}});
    attachLabel(box,'PNG paralelo',parallel.sheet,v=>patch('sheet',cleanSheet(v)));
    attachLabel(box,'Fotogramas secundarios',parallel.frames,v=>patch('frames',v),'number',1,64);
    attachLabel(box,'FPS secundarios',parallel.fps,v=>patch('fps',v),'number',1,60);
    attachLabel(box,'Opacidad %',parallel.opacity,v=>patch('opacity',v),'number',0,100);
    attachLabel(box,'Desfase inicial (frames)',parallel.phase,v=>patch('phase',v),'number',0,63);
    wrap.append(box);
    wrap.append(btn('Importar PNG de la pista B',()=>importPNG('parallel')));
    wrap.append(btn(parallel.loop?'↻ Secundaria en bucle':'→ Secundaria una vez',()=>patch('loop',!parallel.loop)));
    const size=expectedTrackDimensions(d,parallel);
    wrap.append(el('p',`PNG superpuesto: ${size.width}×${size.height} px en Graphics/AnimatedProps. Pista principal y paralela avanzan a la vez con relojes independientes.`,{className:'ap-secondary-note'}));
  }
  host.append(wrap);
}
function renderParallelTimeline(host,d){
  if(!d.parallel?.enabled)return;
  const p=d.parallel;
  const head=el('div',null,{className:'ap-track-head'});
  head.append(el('span','PISTA B · Animación paralela',{className:'ap-track-title'}),el('span',`${p.frames} fotogramas · ${p.fps} FPS · ${p.opacity}%`,{className:'ap-meter'}));
  host.append(head);
  const strip=el('div',null,{className:'ap-timeline ap-parallel-timeline'});
  for(let f=0;f<p.frames;f++){
    const button=el('button',null,{type:'button',className:'ap-frame ap-parallel-frame'});
    button.dataset.frame=String(f);
    button.append(el('span',`B${String(f+1).padStart(2,'0')}`),el('canvas',null,{width:60,height:54}));
    button.onclick=()=>{state.playback.paused=true;state.playback.parallelFrame=f;paintPanelPreview();};
    strip.append(button);
  }
  host.append(strip);
  host.append(el('p','La pista B se superpone a la principal. Puede tener otros fotogramas, FPS, fase y opacidad.',{className:'ap-secondary-note'}));
}
function paintGraphicThumb(canvas,img,frames=1){
  if(!canvas?.getContext||!img?.width||!img?.height)return;
  const ctx=canvas.getContext('2d');if(!ctx)return;
  const w=img.width/Math.max(1,frames),h=img.height;
  const scale=Math.min((canvas.width-12)/w,(canvas.height-12)/h);
  const dw=w*scale,dh=h*scale;
  ctx.clearRect(0,0,canvas.width,canvas.height);
  ctx.imageSmoothingEnabled=false;
  ctx.drawImage(img,0,0,w,h,(canvas.width-dw)/2,(canvas.height-dh)/2,dw,dh);
}
// Graphic asset workspace: images stay in Graphics/AnimatedProps and are
// protected against deletion as long as ANY definition references them.
function trackImageCard(container,d,track){
  const secondary=track==='B', info=secondary?normalizeParallel(d.parallel):null;
  const sheet=secondary?info.sheet:d.sheet;
  const card=el('section',null,{className:'ap-asset-track'});
  const banner=el('div',null,{className:'ap-track-banner'});
  banner.append(el('strong',secondary?'Pista B · Superpuesta':'Pista A · Principal'),el('span',secondary?(info.enabled?'Activa':'Desactivada'):'Obligatoria',{className:'ap-chip'}));
  card.append(banner);
  const preview=el('div',null,{className:'ap-track-preview'});
  const shot=el('canvas',null,{width:310,height:160});
  const renderShot=c=>{if(c?.ok&&c.img)paintGraphicThumb(shot,c.img,secondary?info.frames:d.frames);};
  const image=sheet&&state.images.get(sheet);
  if(image?.ok)renderShot(image);
  else if(sheet)void preloadImage(sheet).then(renderShot);
  preview.append(shot);card.append(preview);
  card.append(el('div',sheet||'Sin archivo asignado',{className:'ap-asset-note'}));
  const row=el('div',null,{className:'ap-track-actions'});
  row.append(btn('Explorar PNG',()=>openGraphicLibrary(track),true));
  row.append(btn('Importar nuevo',()=>importPNG(secondary?'parallel':'primary')));
  card.append(row);
  if(secondary){
    const secondaryRow=el('div',null,{className:'ap-track-actions'});
    secondaryRow.append(btn(info.enabled?'Desactivar pista B':'Activar pista B',()=>editDefinition({parallel:{...info,enabled:!info.enabled}})));
    secondaryRow.append(btn('Desvincular gráfico B',async()=>{
      const ok=await state.ctx.ui.showConfirmDialog({title:'Desvincular pista B',message:'Quitar el PNG secundario de este prop. El archivo seguirá en Graphics/AnimatedProps.'});
      if(ok)await editDefinition({parallel:{...info,enabled:false,sheet:''}});
    }));
    card.append(secondaryRow);
  }
  container.append(card);
}
async function availableGraphicNames(){
  // ctx.fs exposes only a scoped project directory listing; do not walk outside it.
  const entries=await state.ctx.fs.listProjectDir?.(ART_DIR);
  return graphicEntries(entries);
}
function openGraphicLibrary(track='A'){
  const ctx=state.ctx;
  if(!ctx.ui.showCustomDialog){throw new Error('Esta versión de Maker Studio no admite la biblioteca visual.');}
  const requested=track==='B'?'B':'A';
  let currentDef=state.selected;
  let dialog=null;
  dialog=ctx.ui.showCustomDialog({title:`Biblioteca de gráficos · Pista ${requested}`,width:'min(1100px,94vw)',height:'min(770px,89vh)',render(body){
    const style=el('style');style.textContent=CSS;
    const outer=el('div',null,{className:'ap-asset-modal-root'});
    body.append(style,outer);
    const toolbar=el('div',null,{className:'ap-asset-toolbar'});
    const search=el('input',null,{className:'ap-input',type:'search',placeholder:'Buscar gráficos PNG por nombre…'});
    search.style.flex='1';search.style.minWidth='230px';
    const count=el('span','Cargando…',{className:'ap-chip'});
    toolbar.append(search,btn('Importar PNG',async()=>{await importPNG(requested==='B'?'parallel':'primary');await renderList();}),count);
    outer.append(toolbar);
    const hint=el('p','Elige una imagen para esta pista. Puedes eliminar PNG sin uso; los archivos empleados por otros props están protegidos.',{className:'ap-note'});outer.append(hint);
    const grid=el('div',null,{className:'ap-asset-library-grid'});outer.append(grid);
    async function choose(name){
      const def=state.data.definitions.find(x=>x.id===currentDef);
      if(!def){toast('Selecciona un prop antes de asignar un PNG.');return;}
      if(requested==='B'){
        const p=normalizeParallel(def.parallel);
        await editDefinition({parallel:{...p,enabled:true,sheet:name}});
      }else{
        await editDefinition({sheet:name});
      }
      toast(`${name} asignado a la pista ${requested}.`);
      dialog?.close?.();
    }
    async function deleteUnused(name){
      const uses=imageUsage(state.data,name);
      if(uses.length){toast('No se elimina un PNG que sigue asignado a algún prop.');return;}
      const ok=ctx.ui.confirmDestructive?await ctx.ui.confirmDestructive({title:'Eliminar PNG del proyecto',message:`Se borrará Graphics/AnimatedProps/${name} del disco. Esta operación no puede deshacerse.`,confirmLabel:'Eliminar archivo'}):await ctx.ui.showConfirmDialog({title:'Eliminar PNG',message:`¿Eliminar definitivamente Graphics/AnimatedProps/${name}?`});
      if(!ok)return;
      // Revalidate AFTER confirmation to avoid deleting a newly referenced image.
      if(imageUsage(state.data,name).length)throw new Error('Este gráfico ahora está en uso y no puede eliminarse.');
      const invoke=window.__TAURI__?.core?.invoke;
      if(typeof invoke!=='function')throw new Error('Eliminar archivos requiere la API nativa de Maker Studio.');
      await invoke('delete_file',{path:projectGraphicPath(ctx.editor.gameRoot(),name)});
      const loaded=state.images.get(name);if(loaded?.url?.startsWith('blob:'))URL.revokeObjectURL(loaded.url);
      state.images.delete(name);toast(`Eliminado ${name}.`);await renderList();
    }
    async function renderList(){
      grid.replaceChildren();
      let names=[];
      try{names=await availableGraphicNames();}catch(e){grid.append(el('p',`No se pudo leer Graphics/AnimatedProps: ${String(e?.message||e)}`,{className:'ap-warning'}));return;}
      count.textContent=`${names.length} gráficos`;
      if(!names.length){grid.append(el('p','Todavía no hay PNG. Usa Importar PNG para añadir el primero.',{className:'ap-note'}));return;}
      const term=search.value.trim().toLocaleLowerCase();
      for(const name of names.filter(n=>n.toLocaleLowerCase().includes(term))){
        const used=imageUsage(state.data,name),tile=el('div',null,{className:'ap-asset-file'});
        const cover=el('div',null,{className:'ap-track-preview'});
        const img=el('canvas',null,{width:260,height:155});cover.append(img);tile.append(cover);
        tile.append(el('div',name,{className:'ap-asset-name'}));
        tile.append(el('span',used.length?`En uso: ${used.map(x=>x.name+' ('+x.track+')').join(', ')}`:'Sin uso · se puede borrar',{className:'ap-deletion-hint'}));
        tile.append(btn(`Asignar a pista ${requested}`,()=>choose(name),true));
        const deletion=btn(used.length?'En uso · protegido':'Eliminar PNG',()=>deleteUnused(name));
        deletion.disabled=used.length>0;deletion.classList.add('ap-warning-action');tile.append(deletion);
        grid.append(tile);
        const referenced=state.data.definitions.find(d=>d.sheet===name||d.parallel?.sheet===name);
        const frames=referenced?.sheet===name?referenced.frames:(referenced?.parallel?.frames||1);
        const drawCard=c=>{if(c?.ok&&c.img&&img.isConnected!==false)paintGraphicThumb(img,c.img,frames);};
        const cached=state.images.get(name);
        if(cached?.ok)drawCard(cached);
        else void preloadImage(name).then(drawCard).catch(()=>{});
      }
      if(!grid.children.length)grid.append(el('p','No hay gráficos con ese nombre.',{className:'ap-note'}));
    }
    search.oninput=()=>void renderList().catch(problem);
    void renderList().catch(problem);
    return ()=>{};
  }});
  return dialog;
}
function renderInspectorTabs(inspector){
  const tabs=el('div',null,{className:'ap-inspector-tabs'});
  const choices=[['graphics','🖼 Gráficos'],['animation','▶ Animación'],['region','▦ Selección'],['collision','⚙ Colisiones']];
  for(const [key,title] of choices){
    const b=btn(title,()=>{state.inspectorTab=key;refresh();});
    if(key===state.inspectorTab)b.classList.add('active');
    tabs.append(b);
  }
  inspector.append(tabs);
}

// Visible, discoverable tool specification shared by the workspace and help strip.
const AP_TOOLS=[
 ['brush','🖌','Pintar','B','Mantén pulsado y arrastra para colocar props. No necesitas hacer clic celda a celda.'],
 ['eraser','⌫','Borrar','E','Arrastra para borrar solo las celdas de props en la capa actual.'],
 ['select','⬚','Mover','S','Haz clic en un prop y arrástralo para cambiar su posición.'],
 ['line','╱','Línea','L','Arrastra desde el inicio hasta el final para trazar una línea.'],
 ['rectangle','▭','Rectángulo','R','Arrastra entre dos esquinas para rellenar una región.'],
 ['fill','▧','Rellenar','F','Haz clic en una región conectada para rellenarla (máximo 600 celdas).'],
 ['eyedropper','◉','Tomar prop','I','Haz clic sobre un objeto colocado para usar su gráfico y región.'],
 ['wand','✦','Seleccionar similares','W','Haz clic sobre un prop para seleccionar celdas similares; usa la selección como máscara.'],
 ['magic-eraser','✕','Borrar similares','M','Haz clic sobre un prop para borrar los de su tipo; respeta capa y conectividad.'],
 ['pan','✥','Mover mapa','Espacio','Activa el desplazamiento nativo del mapa; vuelve a Pintar para colocar props.']
];
function activePropMode(){return state?.actionMode==='select'?'select':state?.brushMode||'brush';}
function updateToolGuide(){
 const host=state?.host;if(!host)return;
 const mode=activePropMode();
 const record=AP_TOOLS.find(row=>row[0]===mode);
 const head=host.querySelector?.('.ap-context-tool');
 if(head)head.textContent=`${record?.[1]||'🖌'} ${record?.[2]||'Pintar'} · ${record?.[3]||'B'}`;
 const description=host.querySelector?.('.ap-context-help');
 if(description)description.textContent=record?.[4]||'';
 const sizes=host.querySelector?.('.ap-tool-size-options');
 if(sizes)sizes.hidden=!['brush','eraser','line','rectangle'].includes(mode);
 const matching=host.querySelector?.('.ap-tool-match-options');
 if(matching)matching.hidden=!['wand','magic-eraser'].includes(mode);
 const ids=host.querySelectorAll?.('.ap-mode-switch')||[];
 for(const b of ids){
   const selected=(b.dataset?.switchTo==='props')===toolActive();
   b.classList?.toggle?.('active',selected);
   b.setAttribute?.('aria-pressed',String(selected));
 }
}
function renderToolWorkbench(root){
 const bar=el('section',null,{className:'ap-tool-workbench'});
 const main=el('div',null,{className:'ap-tool-main'});
 const text=el('div',null,{className:'ap-tool-intro'});
 text.append(el('strong','Herramientas del mapa'),el('small','Selecciona qué quieres hacer y arrastra sobre el mapa.'));
 main.append(text);
 const modeSwitch=el('div',null,{className:'ap-editor-mode'});
 for(const [key,label,cb] of [['props','▣ Props animados',activateProps],['native','▦ Tiles normales',nativeTiles]]){
   const b=btn(label,cb);b.dataset.switchTo=key;b.classList.add('ap-mode-switch');
   b.classList.toggle('active',(key==='props')===toolActive());
   b.setAttribute?.('aria-pressed',String((key==='props')===toolActive()));
   modeSwitch.append(b);
 }
 main.append(modeSwitch);
 const available=paintLayers();
 if(available.length){
   const quick=el('label',null,{className:'ap-quick-layer'});
   quick.append(el('span','Capa de props'));
   const layerSelect=el('select',null,{className:'ap-input ap-paint-layer'});
   for(const layer of available){const option=el('option',`${layer.index+1} · ${layer.name||'Capa'}`);option.value=String(layer.index);layerSelect.append(option);}
   const index=selectedPaintLayer();if(index!=null)layerSelect.value=String(index);
   layerSelect.onchange=()=>setPaintLayer(activeMap(),Number(layerSelect.value),true);
   quick.append(layerSelect);
   const isolate=el('label',null,{className:'ap-layer-isolate'});
   const check=el('input',null,{type:'checkbox'});check.checked=!!state.isolateLayer;
   check.onchange=()=>{state.isolateLayer=check.checked;syncLayerUI();redraw(true);};
   isolate.append(check,el('span','Solo capa activa'));
   quick.append(isolate);
   quick.append(el('span','',{className:'ap-layer-count'}));
   main.append(quick);
 }
 bar.append(main);
 const tools=el('div',null,{className:'ap-tool-groups'});
 const group=(title,ids,extra=false)=>{
   const content=el('div',null,{className:extra?'ap-tools-advanced':'ap-tools-group'});
   if(title)content.append(el('span',title,{className:'ap-tools-caption'}));
   const buttons=el('div',null,{className:'ap-tools-buttons'});
   for(const mode of ids){
     const row=AP_TOOLS.find(entry=>entry[0]===mode);if(!row)continue;
     const [id,glyph,label,key,help]=row;
     const button=btn('',()=>choosePropTool(id),id===activePropMode());
     button.classList.add('ap-tool-choice');button.dataset.propTool=id;
     button.title=`${label} (${key}): ${help}`;
     button.setAttribute?.('aria-label',`${label}. ${help}`);
     button.setAttribute?.('aria-pressed',String(id===activePropMode()));
     button.append(el('span',glyph,{className:'ap-tool-icon'}),el('span',label,{className:'ap-tool-name'}));
     buttons.append(button);
   }
   content.append(buttons);return content;
 };
 tools.append(group('Esenciales',['brush','eraser','select']));
 tools.append(group('Formas y acciones',['line','rectangle','fill','eyedropper']));
 const advanced=el('details',null,{className:'ap-tool-advanced'});
 advanced.append(el('summary','Más herramientas'));
 advanced.append(group('Selección avanzada',['wand','magic-eraser','pan'],true));
 tools.append(advanced);bar.append(tools);
 const guide=el('div',null,{className:'ap-tool-context'});
 const current=AP_TOOLS.find(t=>t[0]===activePropMode());
 guide.append(el('strong',`${current?.[1]||'🖌'} ${current?.[2]||'Pintar'} · ${current?.[3]||'B'}`,{className:'ap-context-tool'}));
 guide.append(el('span',current?.[4]||'',{className:'ap-context-help'}));
 const options=el('div',null,{className:'ap-context-options'});
 const size=el('div',null,{className:'ap-tool-size-options'});
 size.append(el('label','Tamaño del pincel'));
 const sizeInput=el('input',null,{className:'ap-input ap-size-range',type:'range',min:'1',max:'7',step:'1',value:String(state.brushSize)});
 const sizeNumber=el('output',`${state.brushSize} × ${state.brushSize}`,{className:'ap-size-label'});
 sizeInput.oninput=()=>{state.brushSize=Math.max(1,Math.min(7,Number(sizeInput.value)||1));sizeNumber.textContent=`${state.brushSize} × ${state.brushSize}`;redraw();};
 size.append(sizeInput,sizeNumber);
 const shape=el('select',null,{className:'ap-input ap-shape-select'});
 for(const [value,label] of [['square','■ Cuadrado'],['circle','● Circular']]){
   const option=el('option',label);option.value=value;option.selected=state.brushShape===value;shape.append(option);
 }
 shape.onchange=()=>{state.brushShape=shape.value;redraw();};size.append(shape);options.append(size);
 const match=el('label',null,{className:'ap-tool-match-options'});
 const contiguous=el('input',null,{type:'checkbox',checked:state.selectionContinuous});
 contiguous.onchange=()=>{state.selectionContinuous=contiguous.checked;};
 match.append(contiguous,' Solo elementos conectados');options.append(match);
 const extras=el('details',null,{className:'ap-tool-extras'});
 extras.append(el('summary','Opciones avanzadas'));
 const inside=el('div',null,{className:'ap-tool-extras-inner'});
 const mirrored=el('label',null,{className:'ap-checkline'});
 const follow=el('input',null,{type:'checkbox',checked:state.followNativeTools});
 follow.onchange=()=>{state.followNativeTools=follow.checked;syncStatus();};
 mirrored.append(follow,'Sincronizar botones normales de Maker Studio');inside.append(mirrored);
 inside.append(btn('Limpiar máscara de selección',()=>{state.propSelection=null;redraw();}));
 extras.append(inside);options.append(extras);
 guide.append(options);bar.append(guide);root.append(bar);
 updateToolGuide();
}
function choosePropTool(mode,{fromKeyboard=false}={}){
 if(!state)return;
 if(mode==='pan'){
   state.ctx.editor.setTool('pan');
   status('Desplazamiento nativo: vuelve a un pincel de props para seguir editando.');
   return;
 }
 state.actionMode=mode==='select'?'select':'paint';
 if(mode!=='select')state.brushMode=mode;
 state.drag=null;state.stroke=null;
 if(!toolActive())selectTool();
 else state.propsToolArmed=true;
 const selected=state.host?.querySelectorAll?.('.ap-tool-choice')||[];
 for(const el of selected){
  const active=(el.dataset?.propTool===mode);
  el.classList?.toggle?.('active',active);
  el.setAttribute?.('aria-pressed',String(active));
 }
 const legacy=state.host?.querySelector?.('.ap-brush-select');
 if(legacy&&mode!=='select')legacy.value=mode;
 status(`Herramienta: ${AP_TOOLS.find(p=>p[0]===mode)?.[2]||mode}`);
 updateToolGuide();
 if(!fromKeyboard)redraw();
}
function syncPropToolbar(){
 if(!state?.host)return;
 const activeMode=state.actionMode==='select'?'select':state.brushMode;
 for(const node of state.host.querySelectorAll?.('.ap-tool-choice')||[]){
  const selected=node.dataset?.propTool===activeMode;
  node.classList?.toggle?.('active',selected);
  node.setAttribute?.('aria-pressed',String(selected));
 }
 updateToolGuide();
}
function handlePropToolKey(e){
 if(!toolActive()||e.ctrlKey||e.metaKey||e.altKey||e.repeat)return false;
 if(e.target?.isContentEditable||e.target?.closest?.('input,textarea,select,[contenteditable="true"]'))return false;
 const name={b:'brush',e:'eraser',f:'fill',r:'rectangle',l:'line',i:'eyedropper',w:'wand',m:'magic-eraser',s:'select'}[String(e.key||'').toLowerCase()];
 if(!name)return false;
 e.preventDefault?.();e.stopPropagation?.();e.stopImmediatePropagation?.();
 choosePropTool(name,{fromKeyboard:true});redraw();return true;
}
function refresh(){
  if(!state?.host)return;
  const host=state.host;
  const oldRoot=host.querySelector('.ap-root');
  const oldSheet=host.querySelector('.ap-sheet-wrap');
  const oldList=host.querySelector('.ap-list');
  const savedScroll={root:oldRoot?.scrollTop||0, sheetX:oldSheet?.scrollLeft||0,
    sheetY:oldSheet?.scrollTop||0,list:oldList?.scrollTop||0};
  state.selectionDrag=null;
  host.replaceChildren();
  const root=el('div',null,{className:'ap-root ap-studio-v062'});
  const hostWidth=host.getBoundingClientRect?.().width||0;
  if(hostWidth>0&&hostWidth<1030)root.classList.add('ap-compact');
  host.append(root);
  const st=el('style');st.textContent=CSS;root.append(st);
  const top=el('header',null,{className:'ap-studio-command'});
  const brand=el('div',null,{className:'ap-studio-identity'});
  brand.append(el('strong','ANIMATED PROPS STUDIO'),el('span','Editor de objetos animados · Librería y mapa',{className:'ap-subtitle'}));
  top.append(brand);
  const actions=el('div',null,{className:'ap-command-actions'});
  actions.append(btn('＋ Nuevo prop',newDefinition,true),btn('🖼 Gráficos',()=>openGraphicLibrary('A')),
    btn('↻ PNG',()=>refreshGraphics({force:true}).then(n=>toast(`Recargados ${n.length} gráficos`))),
    btn('↶ Deshacer',undo),btn('↷ Rehacer',redo),btn('Guardar',persist));
  top.append(actions);
  const performanceSelect=el('select',null,{className:'ap-input ap-performance-select'});
  performanceSelect.title='Calidad de reproducción únicamente dentro del editor';
  for(const [id,cfg] of Object.entries({full:getProfile('full'),balanced:getProfile('balanced'),saver:getProfile('saver'),static:getProfile('static')})){
    const option=el('option',cfg.label);option.value=id;option.selected=state.perfMode===id;performanceSelect.append(option);
  }
  performanceSelect.onchange=()=>{state.perfMode=performanceSelect.value;state.lastMapFrameKey=null;state.lastPreviewKey=null;
    state.lastMapTick=null;state.lastPreviewTick=null;
    void state.ctx.storage?.set('animationPerformanceModeEditorStaticV2',state.perfMode).catch?.(problem);
    refresh();redraw();};
  const perfCard=el('div',null,{className:'ap-perf-card'});
  perfCard.append(el('span','Reproducción',{className:'ap-perf-title'}),performanceSelect);
  top.append(perfCard);
  root.append(top);
  renderToolWorkbench(root);
  syncLayerUI();
  if(state.readError){root.append(el('div',`ERROR AL LEER: ${state.readError}. No se permitirá guardar hasta corregir el archivo manualmente.`,{className:'ap-note'}));return;}
  const cols=el('div',null,{className:'ap-cols'});
  if(state.inspectorTab==='region')cols.classList.add('ap-region-mode');
  root.append(cols);
  const sidebar=el('div',null,{className:'ap-card ap-library'}),detail=el('div',null,{className:'ap-card ap-visual-stage'}),inspector=el('div',null,{className:'ap-card ap-inspector'});
  cols.append(sidebar,detail,inspector);
  sidebar.append(el('div','OBJETOS DEL PROYECTO',{className:'ap-control-heading'}));
  const search=el('input',null,{className:'ap-input ap-library-search',placeholder:'Buscar árbol, molino, efecto…',type:'search'});
  sidebar.append(search);
  const list=el('div',null,{className:'ap-list'});sidebar.append(list);
  for(const d of state.data.definitions){
    const b=btn('',()=>{state.selected=d.id;state.playback={paused:false,frame:0,parallelFrame:0};state.animEpoch=performance.now();refresh();redraw();});
    b.classList.add('ap-lib-entry');
    const thumb=el('canvas',null,{className:'ap-thumb',width:66,height:66});thumb.dataset.defid=d.id;
    const text=el('span',`${d.name}\n${d.width}×${d.height} tiles · ${d.frames} fotogramas`,{className:'ap-lib-name'});
    b.append(thumb,text);
    if(d.id===state.selected)b.classList.add('active');list.append(b);
    if(!state.images.has(d.sheet))void preloadImage(d.sheet);
  }
  search.addEventListener('input',()=>{const q=search.value.trim().toLocaleLowerCase();for(const entry of list.querySelectorAll('.ap-lib-entry')){entry.hidden=!!q&&!entry.textContent.toLocaleLowerCase().includes(q);}});
  if(!state.data.definitions.length)list.append(el('p','Crea tu primer objeto animado.',{className:'ap-note'}));
  sidebar.append(btn('⛶ Abrir ventana amplia',()=>openWideStudio(state.ctx),true));
  const count=el('div',null,{className:'ap-note ap-count'});sidebar.append(count);
  const mapControls=el('details',null,{className:'ap-map-controls'});mapControls.open=!!state.mapControlsOpen;
  mapControls.ontoggle=()=>{state.mapControlsOpen=mapControls.open;};
  mapControls.append(el('summary','Capas, colocaciones y posición'));
  const mapContent=el('div',null,{className:'ap-map-content'});
  mapControls.append(mapContent);sidebar.append(mapControls);
  renderPlacementControls(mapContent);
  const diag=el('details',null,{className:'ap-debug-panel'});diag.append(el('summary','Diagnóstico técnico'));diag.append(el('pre','',{className:'ap-diagnostics ap-input-diagnostic'}));sidebar.append(diag);
  refreshCounts();
  const d=getDef();if(!d){detail.append(el('p','Selecciona un objeto para editar sus fotogramas y cuadrícula.',{className:'ap-note'}));return;}
  const heading=el('div',null,{className:'ap-row'});
  inspector.append(el('div','INSPECTOR DE OBJETOS',{className:'ap-control-heading'}),heading);
  heading.append(el('strong',d.name),btn('Eliminar objeto',deleteDefinition));
  renderInspectorTabs(inspector);
  const inspectorPane=el('div',null,{className:'ap-inspector-content'});inspector.append(inspectorPane);
  if(state.inspectorTab==='graphics'){
    inspectorPane.append(el('p','Gestiona cada pista desde tarjetas grandes. Para elegir entre todos los PNG, abre la biblioteca visual.',{className:'ap-note'}));
    trackImageCard(inspectorPane,d,'A');
    trackImageCard(inspectorPane,d,'B');
    inspectorPane.append(btn('Abrir gestor completo de gráficos',()=>openGraphicLibrary('A'),true));
    inspectorPane.append(el('p','Los gráficos en uso están protegidos. Asigna uno nuevo y elimina el anterior desde la biblioteca si queda sin referencias.',{className:'ap-deletion-hint'}));
  } else if(state.inspectorTab==='animation'){
    const fields=el('div',null,{className:'ap-fields'});inspectorPane.append(fields);
    attachLabel(fields,'Nombre',d.name,v=>editDefinition({name:v}));
    attachLabel(fields,'Ancho (tiles)',d.width,v=>editDefinition({width:v}),'number',1,32);
    attachLabel(fields,'Alto (tiles)',d.height,v=>editDefinition({height:v}),'number',1,32);
    attachLabel(fields,'Fotogramas horizontales',d.frames,v=>editDefinition({frames:v}),'number',1,64);
    attachLabel(fields,'FPS',d.fps,v=>editDefinition({fps:v}),'number',1,60);
    fields.append(btn(d.loop?'↻ Repetir':'→ Reproducir una vez',()=>editDefinition({loop:!d.loop})));
    inspectorPane.append(el('p',`ID: ${d.id} · imagen A: ${d.width*32*d.frames} × ${d.height*32}px`,{className:'ap-note'}));
    renderParallelControls(inspectorPane,d);
  }
  detail.append(el('h4','Visor de animaciones')); 
  const visorControls=el('div',null,{className:'ap-preview-toolbar'});
  visorControls.append(el('span','Vista:',{className:'ap-note'}));
  const zoomSelect=el('select',null,{className:'ap-input'});
  for(const factor of [1,2,3]){const option=el('option',`${factor}×`);option.value=String(factor);option.selected=state.previewZoom===factor;zoomSelect.append(option);}
  zoomSelect.onchange=()=>{state.previewZoom=Number(zoomSelect.value);paintPanelPreview();};
  visorControls.append(zoomSelect);
  const viewToggle=(label,key)=>{const b=btn(`${state[key]?'☑':'□'} ${label}`,()=>{state[key]=!state[key];b.textContent=`${state[key]?'☑':'□'} ${label}`;paintPanelPreview();});visorControls.append(b);};
  viewToggle('Cuadrícula','previewGrid');viewToggle('Región','previewCrop');viewToggle('Fantasmas','previewOnion');
  detail.append(visorControls);
  const stage=el('div',null,{className:'ap-anim-stage'});
  const animCanvas=el('canvas',null,{className:'ap-anim-canvas',width:d.width*32,height:d.height*32});
  stage.append(animCanvas);detail.append(stage);
  detail.append(el('div','',{className:'ap-playing'}));
  const player=el('div',null,{className:'ap-button-row'});
  player.append(btn(state.playback.paused?'▶ Reproducir':'⏸ Pausar',()=>{if(!state.playback.paused)state.playback.frame=selectedFrame(d);state.playback.paused=!state.playback.paused;if(!state.playback.paused)state.animEpoch=performance.now();refresh();}));
  player.append(btn('◀ Anterior',()=>{state.playback.paused=true;state.playback.frame=(selectedFrame(d)-1+d.frames)%d.frames;refresh();}));
  player.append(btn('Siguiente ▶',()=>{state.playback.paused=true;state.playback.frame=(selectedFrame(d)+1)%d.frames;refresh();}));
  detail.append(player);
  const scrub=el('input',null,{className:'ap-input ap-scrub',type:'range',min:'0',max:String(d.frames-1),step:'1',value:String(selectedFrame(d))});
  scrub.addEventListener('input',()=>{state.playback.paused=true;state.playback.frame=Number(scrub.value);paintPanelPreview();});
  detail.append(scrub);
  const timeHead=el('div',null,{className:'ap-row'});
  timeHead.append(el('strong','Línea de tiempo / fotogramas'),el('span','0.00 s',{className:'ap-meter ap-playhead-clock'}));
  detail.append(timeHead);
  const filmstrip=el('div',null,{className:'ap-timeline',role:'group'});
  for(let f=0;f<d.frames;f++){
    const chip=el('button',null,{type:'button',className:`ap-frame${f===selectedFrame(d)?' active':''}`});
    chip.dataset.frame=String(f);chip.title=`Fotograma ${f+1} (${(f/d.fps).toFixed(2)} s)`;
    chip.append(el('span',`F${String(f+1).padStart(2,'0')}`),el('canvas',null,{width:60,height:54}));
    chip.onclick=()=>{state.playback.paused=true;state.playback.frame=f;paintPanelPreview();};
    filmstrip.append(chip);
  }
  detail.append(filmstrip);
  const progress=el('div',null,{className:'ap-progress'});progress.append(el('div',null,{className:'ap-progress-fill'}));detail.append(progress);
  detail.append(el('p','Pista principal: secuencia original. La pista secundaria opcional puede reproducirse en paralelo con FPS propios.',{className:'ap-note'}));
  renderParallelTimeline(detail,d);
  if(state.inspectorTab==='graphics'){
    const raw=el('details',null,{className:'ap-raw-details'});
    raw.append(el('summary','Mostrar spritesheet original completo'));
    raw.append(el('img',null,{className:'ap-preview',alt:'Spritesheet completo'}));
    inspectorPane.append(raw);
    inspectorPane.append(el('div','',{className:'ap-note ap-preview-status'}));
    inspectorPane.append(btn('Comprobar PNG',async()=>{await preloadImage(d.sheet,true);refreshPreview();const info=state.images.get(d.sheet);if(info?.error)throw Error(info.error);toast('Gráfico verificado.');}));
    const pic=state.images.get(d.sheet);
    if(!pic)void preloadImage(d.sheet).then(()=>{if(state.host)refreshPreview();});
    else if(pic.error)inspectorPane.append(el('p',`Vista previa no disponible: ${pic.error}`,{className:'ap-note'}));
    if(d.parallel?.enabled){
      const other=state.images.get(d.parallel.sheet),size=expectedTrackDimensions(d,d.parallel);
      if(other?.ok&&other.img&&(other.img.width!==size.width||other.img.height!==size.height))
        inspectorPane.append(el('p',`Pista B: ${other.img.width}×${other.img.height} px; esperado ${size.width}×${size.height} px.`,{className:'ap-warning'}));
    }
    refreshPreview();
  }
  if(state.inspectorTab==='region'){
    inspectorPane.append(el('div','SELECCIÓN DE REGIÓN · EDICIÓN AMPLIADA',{className:'ap-control-heading'}));
    inspectorPane.append(el('p','Arrastra sobre el gráfico para seleccionar tiles. Esta vista ocupa más espacio para evitar selecciones imprecisas.',{className:'ap-note'}));
    renderRegionSelector(inspectorPane,d);
  }
  if(state.inspectorTab==='collision'){
    inspectorPane.append(el('div','PASABILIDAD · PRIORIDAD · TERRENO',{className:'ap-control-heading'}));
    const section=el('details');section.open=true;
    section.ontoggle=()=>{state.gridOpen=section.open;};
    section.append(el('summary','Editar propiedades por celda'));
    inspectorPane.append(section);renderGrid(section,d);
    section.append(el('p','Las propiedades se aplican a las celdas del gráfico original, incluido el fragmento seleccionado.',{className:'ap-note'}));
  }
  paintPanelPreview();paintThumbnails();paintTimelineFrames();
  root.scrollTop=savedScroll.root;
  const sheet=host.querySelector('.ap-sheet-wrap');
  if(sheet){sheet.scrollLeft=savedScroll.sheetX;sheet.scrollTop=savedScroll.sheetY;}
  const listNow=host.querySelector('.ap-list');if(listNow)listNow.scrollTop=savedScroll.list;

}
function drawOverlay(draw,info){
  if(!state||state.readError||!state.showOverlay||!info||!Number.isInteger(info.mapId))return;
  const mapContext=draw;
  state.overlayCalls++;
  const render=renderEntries(info.mapId);
  const view=normalizedViewport(info);
  // The animation scheduler and overlay share a cached spatial viewport query.
  const geo=viewportCacheKey(info.mapId,view);
  const cached=state.visibleCandidates;
  const visible=cached?.geo===geo&&cached?.render===render ? cached.entries : queryVisible(render.spatial,view);
  if(!cached||cached.geo!==geo||cached.render!==render)state.visibleCandidates={geo,render,entries:visible};
  // In this Maker Studio build the overlay surface already inherits the native
  // canvas zoom. Coordinates supplied to drawImage must remain in logical
  // tile pixels, otherwise the graphics scale a second time.
  const scale=view.tileSize;
  if(!Number.isFinite(scale)||scale<=0)return;
  const localRect=(x,y,w,h)=>overlayCanvasRect(x,y,w,h,view);
  const snapshot=layerSnapshot(info.mapId);
  const mapRows=snapshot.rows;
  const tilesByLayer=snapshot.byIndex;
  const currentPaintLayer=selectedPaintLayer(info.mapId);
  const viewOptions=state.ctx.editor.viewOptions?.()||{};
  const now=performance.now();
  // Reuse the already composited transparent prop layer when the native map
  // redraws for lighting, autotiles, zoom/pan repaint or unrelated UI work.
  // Like native animated autotiles, the cached surface is replaced only when
  // the visible animation frame or an editing/view dependency changes.
  const canCache=view.canvasWidth>0 && view.canvasHeight>0 &&
    view.canvasWidth*view.canvasHeight<=2400000 &&
    typeof document!=='undefined' && typeof document.createElement==='function';
  const compositeKey=[geo,state.compositeRevision||0,state.lastMapFrameKey||'',
    state.perfMode,viewOptions.showCollision?1:0,viewOptions.showDim?1:0,
    state.isolateLayer?1:0,currentPaintLayer,state.selectedPlacedId||'',
    state.maskHigherTiles?1:0,
    state.hover?.mapId===info.mapId?state.hover.x+','+state.hover.y:'',
    state.actionMode,state.brushMode||'',state.playback?.paused?1:0].join('|');
  if(canCache && state.compositedOverlay?.key===compositeKey){
    mapContext.save();mapContext.globalCompositeOperation='source-over';
    mapContext.drawImage(state.compositedOverlay.canvas,0,0);mapContext.restore();
    return;
  }
  if(canCache){
    // A changing animation frame should refresh the SAME GPU/canvas backing,
    // not allocate a multi-megabyte bitmap every tick.
    const width=Math.ceil(view.canvasWidth),height=Math.ceil(view.canvasHeight);
    let surface=state.compositedOverlay?.canvas;
    if(!surface || surface.width!==width || surface.height!==height){
      surface=document.createElement('canvas');
      surface.width=width;surface.height=height;
    }
    const surfaceContext=surface.getContext('2d');
    if(surfaceContext){
      surfaceContext.clearRect(0,0,width,height);
      draw=surfaceContext;
    }else state.compositedOverlay=null;
  }
  draw.save();
  const primaryFrames=new Map(),secondaryFrames=new Map();
  const collisionVisible=!!viewOptions.showCollision;
  for(const {p,d} of visible){
    if(state.isolateLayer&&p.layer!==currentPaintLayer)continue;
    const layer=tilesByLayer.get(p.layer)||{visible:true,opacity:1};
    if(layer.visible===false)continue;
    const rawOpacity=Number(layer.opacity??1);
    const layerOpacity=Math.max(0,Math.min(1,rawOpacity>1?rawOpacity/255:rawOpacity));
    const dimmed=viewOptions.showDim && p.layer!==currentPaintLayer;
    draw.globalAlpha=layerOpacity*(dimmed?0.35:1);
    const crop=cropFor(d,p.crop);
    const moving=state.drag?.id===p.id && state.drag.mapId===info.mapId ? state.drag : null;
    const r=localRect(moving?.x??p.x,moving?.y??p.y,crop.w,crop.h);
    // Cull by the *physical* viewport, never by the unscaled overlay bounds.
    const displayed=nativeScreenRect(moving?.x??p.x,moving?.y??p.y,crop.w,crop.h,view);
    if(displayed.x+displayed.w<0||displayed.y+displayed.h<0||
       displayed.x>view.canvasWidth||displayed.y>view.canvasHeight)continue;
    const c=state.images.get(d.sheet);
    const mask=cachedHigherMask(info.mapId,p,crop,mapRows);
    const paintTrack=(picture,frame,opacity)=>{
      if(!picture?.ok||!picture.img)return;
      draw.save();draw.globalAlpha*=opacity;
      draw.imageSmoothingEnabled=false;
      if(!mask.all && typeof draw.clip==='function'){
        if(!(mask.count>0)){draw.restore();return;}
        draw.beginPath();for(const cell of mask.cells)draw.rect(r.x+cell.x*scale,r.y+cell.y*scale,scale,scale);
        draw.clip();
      }
      draw.drawImage(picture.img,(frame*d.width+crop.x)*32,crop.y*32,crop.w*32,crop.h*32,r.x,r.y,r.w,r.h);
      draw.restore();
    };
    if(c?.ok&&c.img){
      const phase=d.timingMode==='independent'?cachedPlacementPhase(p.id,d.frames):0;
      let baseFrame=primaryFrames.get(d.id);
      if(baseFrame==null){baseFrame=frameFor(d,now);primaryFrames.set(d.id,baseFrame);}
      const frame=d.loop?(baseFrame+phase)%d.frames:Math.min(d.frames-1,baseFrame+phase);
      paintTrack(c,frame,1);
    } else {
      if(!c)void preloadImage(d.sheet);
      draw.fillStyle='rgba(50,145,200,0.38)';draw.fillRect(r.x,r.y,r.w,r.h);
      draw.fillStyle='#fff';draw.font='bold 11px sans-serif';draw.fillText(c?.error?'PNG FALTANTE':'CARGANDO PNG',r.x+4,r.y+16);
    }
    if(d.parallel?.enabled && d.parallel.sheet && c?.ok && c.img){
      const secondary=state.images.get(d.parallel.sheet);
      if(!secondary)void preloadImage(d.parallel.sheet);
      if(secondary?.ok && secondary.img){
        const dimensions=expectedTrackDimensions(d,d.parallel);
        if(secondary.img.width===dimensions.width&&secondary.img.height===dimensions.height){
          let secondaryFrame;
          if(d.timingMode==='independent')secondaryFrame=parallelFrame(d,now,p.id);
          else {
            secondaryFrame=secondaryFrames.get(d.id);
            if(secondaryFrame==null){secondaryFrame=parallelFrame(d,now,p.id);secondaryFrames.set(d.id,secondaryFrame);}
          }
          paintTrack(secondary,secondaryFrame,d.parallel.opacity/100);
        }
      }
    }
    if(collisionVisible){
      const collision=collisionCells(d,crop,{...p,x:moving?.x??p.x,y:moving?.y??p.y});
      // Props are stored outside the native tile stack, so Col must show their
      // own passability markers. Do not claim to replace native stack resolution.
      drawCollisionCells(draw,r,view,collision);
    }
    const selected=p.id===state.selectedPlacedId;
    // The mod's editing gizmos must not cover higher native tiles in normal
    // painting mode. Only show them while editing props or selecting one.
    if(selected){
      draw.lineWidth=selected?3:2;
      draw.strokeStyle=selected?'#ffee55':'#39ceff';
      draw.strokeRect(r.x+1,r.y+1,Math.max(0,r.w-2),Math.max(0,r.h-2));
      draw.globalAlpha=1;
      const tag=selected?`${d.name} L${p.layer+1} (${p.x},${p.y})`:'';
      draw.font='bold 12px sans-serif';
      const textWidth=Math.ceil(draw.measureText(tag).width);
      const ty=r.y>22?r.y-20:r.y;
      draw.fillStyle='rgba(0,0,0,.82)';draw.fillRect(r.x,ty,textWidth+10,18);
      draw.fillStyle='#fff';draw.fillText(tag,r.x+5,ty+13);
      draw.fillStyle=selected?'#ffee55':'#39ceff';
      draw.fillRect(r.x-2,r.y-2,7,7);
    }
    draw.globalAlpha=1;
  }
  if(state.propSelection?.mapId===info.mapId&&state.propSelection.layer===currentPaintLayer){
    draw.save();draw.globalAlpha=0.19;draw.fillStyle='#edce4f';
    let rendered=0;
    for(const key of state.propSelection.keys){
      if(rendered++>1800)break;
      const [x,y]=key.split(',').map(Number),r=localRect(x,y,1,1);
      draw.fillRect(r.x,r.y,r.w,r.h);
    }
    draw.restore();
  }
  if(state.stroke?.mapId===info.mapId){
    const points=strokeCells(state.stroke).slice(0,1300);
    draw.save();draw.globalAlpha=0.32;
    draw.fillStyle=state.stroke.erase?'#fb6262':'#48caff';
    for(const p of points){const r=localRect(p.x,p.y,1,1);draw.fillRect(r.x,r.y,r.w,r.h);}
    draw.restore();
  }
  if(state.actionMode==='paint'&&state.hover&&state.hover.mapId===info.mapId&&state.ctx.editor.activeTool()===TOOL){
    const d=getDef();
    const erasing=state.brushMode==='eraser'||state.brushMode==='magic-eraser';
    const picking=state.brushMode==='eyedropper'||state.brushMode==='wand';
    if(erasing||picking){
      const area=(state.brushMode==='eraser')?brushFootprint([{x:state.hover.x,y:state.hover.y}],state.brushSize,state.brushShape):[{x:state.hover.x,y:state.hover.y}];
      draw.save();
      draw.fillStyle=erasing?'rgba(255,82,82,.25)':'rgba(245,204,73,.18)';
      draw.strokeStyle=erasing?'#ff6464':'#f5cc49';draw.lineWidth=2;
      for(const point of area){const r=localRect(point.x,point.y,1,1);draw.fillRect(r.x,r.y,r.w,r.h);draw.strokeRect(r.x+1,r.y+1,Math.max(0,r.w-2),Math.max(0,r.h-2));}
      draw.restore();
    }else if(d){
      const infoMap=state.ctx.map.info(info.mapId);
      const crop=selectedCrop(d);
      const valid=!!infoMap&&validatePosition(d,state.hover.x,state.hover.y,infoMap,crop);
      const r=localRect(state.hover.x,state.hover.y,crop.w,crop.h);
      const c=state.images.get(d.sheet);
      if(c?.ok&&c.img){
        draw.globalAlpha=0.55;
        draw.drawImage(c.img,(frameFor(d)*d.width+crop.x)*32,crop.y*32,crop.w*32,crop.h*32,r.x,r.y,r.w,r.h);
        draw.globalAlpha=1;
      }
      draw.fillStyle=valid?'rgba(57,216,130,.16)':'rgba(255,66,66,.24)';
      draw.fillRect(r.x,r.y,r.w,r.h);
      draw.lineWidth=2;draw.strokeStyle=valid?'#39d882':'#ff5050';
      draw.setLineDash([6,4]);draw.strokeRect(r.x+1,r.y+1,r.w-2,r.h-2);draw.setLineDash([]);
      // Every tile of the footprint is marked, including the anchor cell.
      draw.strokeStyle=valid?'rgba(25,160,88,.55)':'rgba(220,35,35,.65)';
      draw.lineWidth=1;
      for(let cx=1;cx<crop.w;cx++){
        draw.beginPath();draw.moveTo(r.x+cx*scale,r.y);draw.lineTo(r.x+cx*scale,r.y+r.h);draw.stroke();
      }
      for(let cy=1;cy<crop.h;cy++){
        draw.beginPath();draw.moveTo(r.x,r.y+cy*scale);draw.lineTo(r.x+r.w,r.y+cy*scale);draw.stroke();
      }
      draw.font='bold 12px sans-serif';
      const lbl=`${d.name} · (${state.hover.x},${state.hover.y})`;
      const tw=draw.measureText(lbl).width;
      draw.fillStyle='rgba(0,0,0,.8)';draw.fillRect(r.x,r.y+r.h,tw+10,19);
      draw.fillStyle=valid?'#aaffbb':'#ffbaba';draw.fillText(lbl,r.x+5,r.y+r.h+14);
    }
  }
  draw.restore();
  if(canCache && draw!==mapContext){
    state.compositedOverlay={key:compositeKey,canvas:draw.canvas};
    mapContext.save();mapContext.globalCompositeOperation='source-over';
    mapContext.drawImage(draw.canvas,0,0);mapContext.restore();
  }
}
function normaliseToolEvent(e){
  const mapId=Number.isInteger(e?.mapId)?e.mapId:activeMap();
  const x=e?.tileX,y=e?.tileY;
  if(!Number.isInteger(mapId)||!Number.isInteger(x)||!Number.isInteger(y))return null;
  const map=state?.ctx?.map?.info(mapId);
  if(!map||x<0||y<0||x>=map.width||y>=map.height)return null;
  return {mapId,x,y};
}
// Per-stroke geometry is accumulated in map tiles, not screen pixels. One
// checkpoint and one JSON write per gesture, even for long dragged strokes.
function beginPropStroke(tile,e={},origin='native'){
  if(!tile||!state||!toolActive()||state.actionMode!=='paint')return;
  const mode=e.altKey?'eraser':state.brushMode;
  if(mode==='eyedropper'){
    const found=activeLayerPlacementAt(state.data,tile.mapId,tile.x,tile.y,selectedPaintLayer(tile.mapId));
    if(found){state.selected=found.defId;state.crops.set(found.defId,cropFor(state.data.definitions.find(d=>d.id===found.defId),found.crop));refresh();status('Prop tomado del mapa.');}
    return;
  }
  if(state.stroke){
    if(origin==='native'&&state.stroke.origin==='dom'&&state.stroke.mapId===tile.mapId){
      state.stroke.origin='native';state.stroke.start={x:tile.x,y:tile.y};state.stroke.end=state.stroke.start;state.stroke.path=[state.stroke.start];
      return;
    }
    return;
  }
  const start={x:tile.x,y:tile.y};
  if(e.shiftKey&&state.lastStrokePoint?.mapId===tile.mapId && (mode==='brush'||mode==='eraser')){
    const old=state.lastStrokePoint;
    state.stroke={mapId:tile.mapId,origin,mode:'line',erase:mode==='eraser',start:{x:old.x,y:old.y},end:start,path:[{x:old.x,y:old.y},start],size:state.brushSize,shape:state.brushShape};
  }else{
    state.stroke={mapId:tile.mapId,origin,mode,erase:mode==='eraser',start,end:start,path:[start],size:state.brushSize,shape:state.brushShape,ctrlAxis:!!e.ctrlKey,ctrlEraseClick:!!e.ctrlKey,ctrlKey:!!e.ctrlKey,shiftKey:!!e.shiftKey};
  }
  redraw();
}
function movePropStroke(tile,origin='native'){
  const st=state?.stroke;
  if(!st||!tile||tile.mapId!==st.mapId||st.origin!==origin)return;
  let x=tile.x,y=tile.y;
  if(st.ctrlAxis&&st.mode==='brush'){
    if(Math.abs(x-st.start.x)>=Math.abs(y-st.start.y))y=st.start.y;
    else x=st.start.x;
  }
  if(st.end?.x===x&&st.end?.y===y)return;
  st.end={x,y};st.path.push(st.end);
  redraw();
}
async function finishPropStroke(tile,origin='native'){
  const st=state?.stroke;
  if(!st||st.origin!==origin)return false;
  if(tile)movePropStroke(tile,origin);
  state.stroke=null;
  const mapId=st.mapId,info=state.ctx.map.info(mapId),layer=selectedPaintLayer(mapId);
  if(!info||layer==null)return false;
  const def=getDef(),erase=st.erase || st.mode==='magic-eraser' || (st.ctrlEraseClick&&st.path.length===1);
  if(!erase&&st.mode!=='wand'&&!def)throw Error('Selecciona un prop antes de pintar.');
  if(!erase && st.mode!=='wand'){
    const file=await preloadImage(def.sheet);
    if(!file?.ok||file.img.width!==def.width*32*def.frames||file.img.height!==def.height*32)
      throw Error('El PNG seleccionado no coincide con los fotogramas y dimensiones configurados.');
  }
  const region=def?selectedCrop(def):{x:0,y:0,w:1,h:1};
  let anchors;
  if(st.mode==='wand'||st.mode==='magic-eraser'){
    const occupied=occupiedPropCells(state.data,mapId,layer,info.width,info.height);
    anchors=matchPropCells(occupied,st.start,info.width,info.height,{continuous:state.selectionContinuous,limit:1800,empty:st.mode==='wand'});
    if(st.mode==='wand'){
      state.propSelection=changeSelection(state.propSelection,anchors,{layer,mapId,add:st.ctrlKey,subtract:st.shiftKey});
      state.lastAction=`Seleccionadas ${state.propSelection.keys.size} celdas de props · capa ${layer+1}`;
      syncStatus();redraw();return true;
    }
  }else if(st.mode==='fill'){
    const oldList=state.data.placements[String(mapId)]||[];
    const category=(x,y)=>{
      const p=activeLayerPlacementAt({definitions:state.data.definitions,placements:{[String(mapId)]:oldList}},mapId,x,y,layer);
      return p?p.defId:'__empty__';
    };
    anchors=floodCells(st.start,(x,y)=>x>=0&&y>=0&&x<info.width&&y<info.height,category,600);
  }else anchors=strokeCells(st);
  if(st.mode==='line'||st.mode==='rectangle')anchors=brushFootprint(anchors,st.size,st.shape);
  const selection=state.ctx.map.selectionTiles?.(mapId);
  const nativeStencil=Array.isArray(selection)&&selection.length?new Set(selection.map(t=>`${t.x},${t.y}`)):null;
  const customStencil=state.propSelection?.mapId===mapId&&state.propSelection?.layer===layer?state.propSelection.keys:null;
  const permitted=customStencil?.size?customStencil:nativeStencil;
  const list=state.data.placements[String(mapId)]||[];
  const oldLength=list.length;
  const unique=new Set();let count=0,invalid=0;
  const filtered=anchors.filter(p=>{
    if(unique.has(`${p.x},${p.y}`))return false;unique.add(`${p.x},${p.y}`);
    if(!erase && !validatePosition(def,p.x,p.y,info,region)){invalid++;return false;}
    if(erase&&(p.x<0||p.y<0||p.x>=info.width||p.y>=info.height))return false;
    return !permitted||permitted.has(`${p.x},${p.y}`);
  });
  if(!filtered.length){redraw();return false;}
  checkpoint();
  let result=list;
  for(const {x,y} of filtered){
    if(erase){
      const old=activeLayerPlacementAt({definitions:state.data.definitions,placements:{[String(mapId)]:result}},mapId,x,y,layer);
      if(!old)continue;
      const oldDef=state.data.definitions.find(d=>d.id===old.defId);
      result=result.flatMap(p=>p===old?subtractPlacementArea(p,oldDef,{x,y,w:1,h:1},()=>`cut_${Date.now().toString(36)}_${++state.serial}`):[p]);
    }else{
      const area={x,y,w:region.w,h:region.h};
      result=result.flatMap(p=>p.layer!==layer?[p]:subtractPlacementArea(p,state.data.definitions.find(d=>d.id===p.defId),area,()=>`cut_${Date.now().toString(36)}_${++state.serial}`));
      result.push({id:`${Date.now().toString(36)}_${++state.serial}`,defId:def.id,x,y,layer,crop:{...region}});
    }
    count++;
  }
  if(!count){state.undo.pop();redraw();return false;}
  state.data.placements[String(mapId)]=result;
  const last=st.end||st.start;
  state.lastStrokePoint={mapId,x:last.x,y:last.y};
  state.lastAction=`${erase?'Borradas':'Pintadas'} ${count} celdas · capa ${layer+1}${invalid?` · ${invalid} fuera del mapa`:''}`;
  refreshCounts();syncStatus();redraw();
  await persist();return true;
}
// Painter shared by the native tool and the canvas-event fallback. Prevents
// a single click being processed twice when both are dispatched by Maker Studio.
async function paintAt(mapId,x,y,erase=false,source='map'){
  const s=state;if(!s)return false;
  if(!toolActive()&&source!=='manual')return false;
  const key=`${mapId}:${selectedPaintLayer(mapId)}:${x}:${y}:${erase}`;
  const at=performance.now();
  if(s.lastPaint?.key===key && at-s.lastPaint.at<180)return false;
  s.lastPaint={key,at};
  s.lastPointer=`${source} (${x},${y})`;
  return place(mapId,x,y,erase);
}
function paintBoundCanvases(){/* The native overlay redraw is scheduled by the caller. */}
function installCanvasBridge(ctx){
 if(typeof ctx.ui.decorate!=='function')return;
 ctx.ui.decorate(CANVAS_SELECTOR,(host)=>{
  if(!state||state.canvasViews.has(host))return;
  // Input fallback only: all graphics are rendered by registerOverlay.
  const locate=e=>{
   if(!state||!isMapPointer(e))return null;
   const mapId=ctx.editor.activeMapId(),map=ctx.map.info(mapId);
   if(!Number.isInteger(mapId)||!map)return null;
   const result=resolveTile({
    mapId,map,hover:state.nativeHover,editorHover:state.zoomWaiting?null:ctx.editor.hoverTile?.(),
    now:performance.now(),clientX:e.clientX,clientY:e.clientY,
    rect:host.getBoundingClientRect(),renderInfo:state.lastRenderInfo,
    viewport:ctx.editor.viewport?.()
   });
   if(result)state.pointerOrigin=result.source;
   return result;
  };
  const move=e=>{
   if(!toolActive())return;
   const tile=locate(e),last=state.hover;
   if(tile){
     state.hover={mapId:tile.mapId,x:tile.x,y:tile.y};state.coords={x:tile.x,y:tile.y};
     if(state.actionMode==='select'&&state.domPointerHeld&&!state.nativeDragging)updateEdit(tile.mapId,tile.x,tile.y);
     if(state.actionMode==='paint'&&state.domPointerHeld)movePropStroke(tile,'dom');
   }else if(!state.nativeHover)state.hover=null;
   // Avoid asking the whole map to redraw for each mouse pixel.
   if((last?.x!==tile?.x)||(last?.y!==tile?.y)||(last?.mapId!==tile?.mapId)){syncStatus();redraw();}
  };
  const down=e=>{
   if(!toolActive()||e.button!==0)return;
   const tile=locate(e);if(!tile)return;
   // Do not swallow native Maker Studio tool events: they carry authoritative tile coords.
   state.domPointerHeld=true;state.pointerEvents++;
   state.hover=tile;state.coords={x:tile.x,y:tile.y};
   // DOM handles the gesture immediately; native onPointerDown can take
   // authority later in the same dispatch and replace the starting coordinate.
   if(state.actionMode==='select')beginEdit(tile.mapId,tile.x,tile.y);
   else beginPropStroke(tile,e,'dom');
  };
  const up=e=>{
   if(!state?.domPointerHeld)return;
   state.domPointerHeld=false;
   if(state.actionMode==='paint'){
     const tile=locate(e),origin=state.stroke?.origin;
     if(origin==='dom')void finishPropStroke(tile,'dom').catch(problem);
     else if(origin==='native')queueMicrotask(()=>void finishPropStroke(tile,'native').catch(problem));
     return;
   }
   if(state.actionMode!=='select')return;
   const tile=locate(e);if(tile)updateEdit(tile.mapId,tile.x,tile.y);
   queueMicrotask(()=>{if(state?.drag && !state.nativeDragging)void finishEdit().catch(problem);});
  };
  const menu=e=>{
   if(!toolActive())return;
   const tile=locate(e);if(!tile)return;
   e.preventDefault();e.stopPropagation();
   if(state.actionMode==='select'){
     const p=pickProp(state.data,tile.mapId,tile.x,tile.y,selectedPaintLayer(tile.mapId));
     if(p){state.selectedPlacedId=p.id;state.drag=null;void deleteSelected().catch(problem);}
   }else void paintAt(tile.mapId,tile.x,tile.y,true,'clic derecho').catch(problem);
  };
  const leave=()=>{if(state&&!state.domPointerHeld){state.hover=null;syncStatus();redraw();}};
  host.addEventListener('pointermove',move);
  host.addEventListener('pointerdown',down);
  host.addEventListener('pointerup',up);
  host.addEventListener('pointercancel',up);
  host.addEventListener('contextmenu',menu);
  host.addEventListener('pointerleave',leave);
  // Finish a stroke even when the pointer is released outside the canvas.
  const globalUp=e=>{if(state?.domPointerHeld)up(e);};
  if(typeof window!=='undefined')window.addEventListener?.('pointerup',globalUp,true);
  const cleanup=()=>{
   host.removeEventListener('pointermove',move);
   host.removeEventListener('pointerdown',down);
   host.removeEventListener('pointerup',up);
   host.removeEventListener('pointercancel',up);
   host.removeEventListener('contextmenu',menu);
   host.removeEventListener('pointerleave',leave);
   if(typeof window!=='undefined')window.removeEventListener?.('pointerup',globalUp,true);
  };
  state.canvasViews.set(host,{cleanup});
  return ()=>{cleanup();state?.canvasViews?.delete(host);};
 });
}
function openWideStudio(ctx){
  if(typeof ctx.ui.showCustomDialog!=='function'){ctx.ui.openPanel(PANEL);return;}
  if(state?.wideOpen)return;
  const previous=state.host;
  state.wideOpen=true;
  const dlg=ctx.ui.showCustomDialog({title:'Animated Props Studio — Editor de animación',width:'min(1580px,98vw)',height:'min(940px,95vh)',render(host){
    state.host=host;refresh();
    return ()=>{if(!state)return;state.wideOpen=false;state.host=previous?.isConnected?previous:null;if(state.host)refresh();};
  }});
  state.wideDialog=dlg;
}

export async function activate(ctx){
  if(state)deactivate(); // safe for repeated activate/hot reload
  state={ctx,data:defaultData(),selected:'',selectedPlacedId:'',actionMode:'paint',drag:null,nativePointerSeq:0,domPointerHeld:false,lastRenderInfo:null,mode:'passage',host:null,readError:null,
    images:new Map(),writer:Promise.resolve(),undo:[],redo:[],serial:0,hover:null,coords:{x:0,y:0},paintLayer:null,
    showOverlay:true,maskHigherTiles:false,isolateLayer:false,lastAction:'Selecciona un prop en la paleta y haz clic en el mapa.', canvasViews:new Map(), lastPaint:null, gridOpen:false,crops:new Map(),
    layerMasks:new Map(),layerMetaByMap:new Map(),renderIndex:new Map(),visibleCandidates:null,drawPending:false,drawRaf:null,propSelection:null,selectionContinuous:true,toolKeyCleanup:null,followNativeTools:true,propsToolArmed:false,toolMirrorLock:false,
    selectionZoom:1,selectionDrag:null,playback:{paused:false,frame:0,parallelFrame:0},animEpoch:performance.now(),miniHover:null,pointerEvents:0,overlayCalls:0,lastPointer:'',interval:null, nativeHover:null,nativeDragging:false,zoomWaiting:false,pointerOrigin:'',perfMode:'static',lastMapTick:null,lastPreviewTick:null,previewZoom:1,previewGrid:false,previewCrop:false,previewOnion:false,inspectorTab:'graphics',mapControlsOpen:false,brushMode:'brush',brushSize:1,brushShape:'square',stroke:null,lastStrokePoint:null,imageStamps:new Map(),reloadingGraphics:false,graphicsCheckTimer:null,focusListener:null,scanCursor:0,historyKeyCleanup:null};
  try{const saved=await ctx.storage?.get('animationPerformanceModeEditorStaticV2','static');if(['full','balanced','saver','static'].includes(saved))state.perfMode=saved;}catch{}
  try{state.data=await loadData();invalidateRenderIndex();}catch(e){state.readError=String(e?.message||e);problem(e);}
  state.selected=state.data.definitions[0]?.id||'';
  ctx.ui.registerPanel({id:PANEL,title:'Objetos animados',showInMenu:false,defaultPosition:'right',defaultSize:{width:1280,height:820},
    render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
  ctx.menu.registerMenuItem({menu:'Mods',label:'Biblioteca de objetos animados',icon:'layers',
    handler:()=>openWideStudio(ctx)});
  ctx.menu.registerMenuItem({menu:'Mods',label:'Abrir Animated Props (panel acoplable)',icon:'layers',handler:()=>ctx.ui.openPanel(PANEL)});
  ctx.tools.registerTool({id:TOOL,label:'Objeto animado',icon:'🎞',
    onActivate(){
      status('Pincel activado. Mueve el ratón sobre el mapa para ver la huella.');
      redraw();
    },
    onDeactivate(){if(state){state.hover=null;syncStatus();redraw();}},
    onPointerMove(e){
      if(!state)return;
      state.pointerEvents++;
      const tile=normaliseToolEvent(e);if(!tile)return;
      state.zoomWaiting=false;state.nativeHover={...tile,at:performance.now()};state.pointerOrigin='tool';
      state.hover=tile;state.coords={x:tile.x,y:tile.y};
      if(state.actionMode==='select'&&state.drag)updateEdit(tile.mapId,tile.x,tile.y);
      if(state.actionMode==='paint')movePropStroke(tile,'native');
      syncStatus();redraw();
    },
    onPointerDown(e){
      if(!state)return;
      state.pointerEvents++;
      const tile=normaliseToolEvent(e);if(!tile)return;
      state.nativePointerSeq++;
      state.lastPointer=`(${tile.x},${tile.y}) buttons=${e.buttons} ctrl=${!!e.ctrlKey}`;
      // Los eventos públicos de ToolDef ya representan un pointer down.
      // No se filtra por buttons: algunas versiones del editor envían 0.
      if((e.buttons&2) && !(e.buttons&1))return;
      if(!Number.isInteger(tile.x)||!Number.isInteger(tile.y)){
        status('El editor envió un evento sin coordenadas de tile.');return;
      }
      state.zoomWaiting=false;state.nativeHover={...tile,at:performance.now()};state.pointerOrigin='tool';
      state.hover=tile;state.coords={x:tile.x,y:tile.y};
      syncStatus();
      if(state.actionMode==='select'){state.nativeDragging=true;beginEdit(tile.mapId,tile.x,tile.y);
      }else beginPropStroke(tile,e,'native');
    },
    onPointerUp(e){
      if(!state)return;
      const tile=normaliseToolEvent(e);
      if(state.actionMode==='paint'){void finishPropStroke(tile,'native').catch(problem);return;}
      if(state.actionMode!=='select'||!state.drag)return;
      if(tile)updateEdit(tile.mapId,tile.x,tile.y);
      state.nativeDragging=false;
      void finishEdit().catch(problem);
    }});
  // Public map overlay is kept for editors without the DOM-canvas bridge.
  const previewOverlay={id:'lbds-animated-props.preview',zOrder:12,render:(draw,info)=>{
    if(state)state.lastRenderInfo=normalizedViewport(info);
    drawOverlay(draw,state.lastRenderInfo?{...info,...state.lastRenderInfo}:info);
  }};
  ctx.ui.registerOverlay(previewOverlay);
  installCanvasBridge(ctx);
  ctx.ui.registerContextMenuItem({context:'map-tile',label:'Colocar objeto animado seleccionado aquí',
    handler:({mapId,tileX,tileY})=>void place(mapId,tileX,tileY).then(changed=>{if(changed)toast(state.lastAction);}).catch(problem),
    isEnabled:({mapId,tileX,tileY})=>{
      const d=getDef(),inf=ctx.map.info(mapId);
      return !!d&&!!inf&&validatePosition(d,tileX,tileY,inf,selectedCrop(d));
    }});
  ctx.ui.registerContextMenuItem({context:'map-tile',label:'Borrar objeto animado aquí',
    handler:({mapId,tileX,tileY})=>void place(mapId,tileX,tileY,true).then(changed=>{if(changed)toast(state.lastAction);}).catch(problem),
    isEnabled:({mapId,tileX,tileY})=>!!placementAt(state.data,mapId,tileX,tileY)});
  ctx.ui.registerContextMenuItem({context:'map-tile',label:'Seleccionar / mover prop animado',
    handler:({mapId,tileX,tileY})=>{state.actionMode='select';state.ctx.editor.setTool(TOOL);beginEdit(mapId,tileX,tileY);state.drag=null;},
    isEnabled:({mapId,tileX,tileY})=>!!pickProp(state.data,mapId,tileX,tileY,selectedPaintLayer(mapId))});
  ctx.ui.registerContextMenuItem({context:'map-tile',label:'Eliminar prop animado completo',
    handler:({mapId,tileX,tileY})=>{const p=pickProp(state.data,mapId,tileX,tileY,selectedPaintLayer(mapId));if(!p)return;state.selectedPlacedId=p.id;void deleteSelected().catch(problem);},
    isEnabled:({mapId,tileX,tileY})=>!!pickProp(state.data,mapId,tileX,tileY,selectedPaintLayer(mapId))});
  ctx.bus.on('map.loaded',()=>{if(state){invalidateLayerMetadata();invalidateRenderIndex();invalidateLayerMask();state.hover=null;state.drag=null;state.selectedPlacedId='';state.paintLayer=null;state.propSelection=null;refresh();redraw();}});
  ctx.bus.on('tool.activated',e=>{
    if(!state)return;
    const id=e?.toolId;
    // Optional toolbar bridge. Convert the native tool CHOICE, not its map writes.
    // This keeps all animated-prop JSON operations in our custom tool.
    const nativeModes={brush:'brush',eraser:'eraser',fill:'fill',rectangle:'rectangle',eyedropper:'eyedropper',select:'select',wand:'wand','magic-eraser':'magic-eraser'};
    if(state.followNativeTools&&state.propsToolArmed&&!state.toolMirrorLock&&id&&id!==TOOL&&nativeModes[id]){
      state.toolMirrorLock=true;
      try{
        const mode=nativeModes[id];
        state.actionMode=mode==='select'?'select':'paint';
        if(mode!=='select')state.brushMode=mode;
        state.ctx.editor.setTool(TOOL);
        syncPropToolbar();syncStatus();
      }finally{state.toolMirrorLock=false;}
    }
    state.hover=null;state.drag=null;syncStatus();redraw();
  });
  ctx.bus.on('layer.changed',e=>{
    if(!state)return;
    const mapId=Number.isInteger(e?.mapId)?e.mapId:activeMap();
    // Changes of the active layer are presentation-only: do NOT rebuild
    // thumbnail canvases, inspector, timelines or the whole Studio.
    if(e?.change==='active'){
      if(Number.isInteger(e.layerIndex)&&paintLayers(mapId).some(l=>l.index===e.layerIndex))
        {state.paintLayer={mapId,index:e.layerIndex};state.propSelection=null;}
      syncLayerUI();redraw(true);return;
    }
    invalidateLayerMetadata(mapId);invalidateLayerMask(mapId);
    if(e?.change==='added'||e?.change==='removed')refresh();
    else syncLayerUI();
    redraw(true);
  });
  ctx.bus.on('map.tile.changed',e=>{invalidateLayerMask(e?.mapId);if(state.maskHigherTiles)redraw();});
  ctx.bus.on('map.batch.changed',e=>{invalidateLayerMask(e?.mapId);if(state.maskHigherTiles)redraw();});
  ctx.bus.on('brush.changed',e=>{if(state&&Number.isInteger(e?.size))state.brushSize=Math.min(7,Math.max(1,e.size));});
  ctx.bus.on('tileset.changed',e=>{if(e?.reason==='selected'&&toolActive())nativeTiles();});
  ctx.bus.on('viewport.changed',()=>{if(!state)return;state.nativeHover=null;state.hover=null;state.lastRenderInfo=null;state.zoomWaiting=true;state.lastMapFrameKey=null;redraw();});
  ctx.bus.on('hover.changed',e=>{
    if(!state||ctx.editor.activeTool()!==TOOL)return;
    const before=state.hover;
    if(e.x==null||e.y==null){state.hover=null;state.nativeHover=null;}
    else if(Number.isInteger(e.x)&&Number.isInteger(e.y)){
      state.zoomWaiting=false;state.nativeHover={mapId:e.mapId,x:e.x,y:e.y,at:performance.now()};
      state.hover={mapId:e.mapId,x:e.x,y:e.y};state.pointerOrigin='hover.changed';
    }
    if(before?.x!==state.hover?.x||before?.y!==state.hover?.y||before?.mapId!==state.hover?.mapId){syncStatus();redraw();}
  });
  installHistoryKeys();
  state.interval=setInterval(tickVisuals,PREVIEW_INTERVAL_MS);
  state.graphicsCheckTimer=setInterval(()=>{
    if(state&&!state.reloadingGraphics && (typeof document==='undefined'||document.hasFocus?.()!==false))
      void refreshGraphics().catch(e=>state?.ctx?.log?.warn?.(`PNG watch: ${e}`));
  },5000);
  if(typeof window!=='undefined' && window.addEventListener){
    state.focusListener=()=>void refreshGraphics({fullScan:true}).catch(e=>state?.ctx?.log?.warn?.(`PNG focus: ${e}`));
    window.addEventListener('focus',state.focusListener);
  }
  redraw();
}
export function deactivate(){
  if(!state)return;
  // On F12/reload clean up listeners BEFORE any asynchronous writes can resume.
  state.historyKeyCleanup?.();
  state.toolKeyCleanup?.();
  if(state.drawRaf!=null&&typeof cancelAnimationFrame==='function')cancelAnimationFrame(state.drawRaf);
  // Close the dialog on mod reload; its old render callback must not survive.
  try{state.wideDialog?.close?.();}catch{}
  // Cancel an unfinished pointer gesture during hot reload instead of starting
  // an async JSON write against a disposed editor context.
  state.stroke=null;
  if(state.interval!=null)clearInterval(state.interval);
  if(state.graphicsCheckTimer!=null)clearInterval(state.graphicsCheckTimer);
  if(state.focusListener&&typeof window!=='undefined')window.removeEventListener?.('focus',state.focusListener);
  for(const view of state.canvasViews?.values()||[])view.cleanup?.();
  for(const c of state.images.values())if(c.url?.startsWith('blob:'))URL.revokeObjectURL(c.url);
  state=null;
}
