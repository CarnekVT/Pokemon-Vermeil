export let STYLES=`
:host,.bss-root{--bg:#0d1017;--panel:#141923;--panel2:#1a202c;--line:#2a3242;--text:#eef2ff;--muted:#9aa5b8;--accent:#4268ff;--ok:#59d9a6;--warn:#e5b94f;box-sizing:border-box}
*{box-sizing:border-box}.bss-root{height:100%;width:100%;min-width:760px;background:var(--bg);color:var(--text);font:13px/1.35 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;overflow:hidden;display:flex;flex-direction:column}.bss-root button,.bss-root input,.bss-root select{font:inherit}.bss-top{height:64px;flex:none;display:flex;align-items:center;gap:8px;padding:8px 14px;background:#151824;border-bottom:1px solid var(--line)}.bss-brand{display:flex;align-items:center;gap:10px;margin-right:10px}.bss-mark{width:40px;height:40px;border-radius:12px;background:#22293a;display:grid;place-items:center;font-size:20px}.bss-brand strong{font-size:15px}.bss-brand small{display:block;color:var(--muted);font-size:10px;margin-top:2px}.bss-btn,.bss-nav{border:1px solid #333c50;background:#1c2230;color:var(--text);border-radius:8px;padding:8px 11px;cursor:pointer}.bss-btn:hover,.bss-nav:hover{background:#252d3d}.bss-btn.primary,.bss-nav.active{background:var(--accent);border-color:#6380ff}.bss-btn.danger{border-color:#7f3843}.bss-btn.small{padding:5px 8px}.bss-spacer{flex:1}.bss-pill{padding:6px 10px;border:1px solid #2e6652;border-radius:999px;color:#79edbd;background:#10221e}.bss-pill.off{border-color:#645529;color:#e7c45d;background:#211d10}.bss-body{min-height:0;flex:1;position:relative;overflow:hidden}.bss-library{height:100%;overflow:auto;padding:18px}.bss-libhead{display:flex;gap:10px;align-items:center;margin-bottom:16px}.bss-search,.bss-input,.bss-select{background:#10141d;color:var(--text);border:1px solid #343e51;border-radius:7px;padding:8px 9px;min-width:0}.bss-search{width:min(420px,50vw)}.bss-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}.bss-card{background:var(--panel);border:1px solid var(--line);border-radius:13px;overflow:hidden}.bss-card-art{height:120px;background:#0b0e14;display:flex;align-items:flex-end;justify-content:center;overflow:hidden;position:relative}.bss-card-art img{max-height:112px;max-width:160px;image-rendering:pixelated}.bss-card-art .kind{position:absolute;left:9px;top:9px;background:#171d2a;border:1px solid #2b3446;border-radius:8px;padding:4px 7px}.bss-card-body{padding:11px}.bss-card-body input{width:100%;font-weight:700;margin-bottom:7px}.bss-card-body small{color:var(--muted)}.bss-card-actions{display:flex;gap:7px;margin-top:10px}.bss-editor{height:100%;display:grid;grid-template-columns:var(--left,250px) 5px minmax(360px,1fr) 5px var(--right,330px);grid-template-rows:100%;overflow:hidden}.bss-side,.bss-inspector{background:#151a23;overflow:auto}.bss-side{border-right:1px solid var(--line)}.bss-inspector{border-left:1px solid var(--line)}.bss-resizer{background:#0d1017;cursor:col-resize;position:relative}.bss-resizer:hover{background:#27314a}.bss-side-head{padding:12px;border-bottom:1px solid var(--line)}.bss-sections{padding:8px}.bss-section{width:100%;text-align:left;border:0;background:transparent;color:#dce3f3;padding:9px 10px;border-radius:7px;cursor:pointer}.bss-section.active{background:#252c3a}.bss-dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#68748b;margin-right:8px}.bss-section.active .bss-dot{background:var(--ok)}.bss-stagewrap{min-width:0;background:#090c12;display:flex;flex-direction:column;overflow:hidden}.bss-stagebar{height:42px;display:flex;align-items:center;gap:8px;padding:6px 10px;background:#111620;border-bottom:1px solid var(--line)}.bss-stage{flex:1;min-height:0;display:grid;place-items:center;padding:12px}.bss-canvasbox{width:min(100%,960px);aspect-ratio:4/3;border:1px solid #2f394d;background:#05070b;position:relative;box-shadow:0 12px 36px #0008}.bss-canvasbox canvas{width:100%;height:100%;display:block;touch-action:none;cursor:grab}.bss-canvasbox canvas.dragging{cursor:grabbing}.bss-hint{position:absolute;left:10px;bottom:9px;background:#0b0f17cc;border:1px solid #283144;border-radius:7px;padding:5px 7px;color:#aeb8ca;font-size:10px;pointer-events:none}.bss-inspector-inner{padding:12px}.bss-panel{border:1px solid var(--line);border-radius:10px;background:#121720;margin-bottom:10px;overflow:hidden}.bss-panel h3{font-size:11px;margin:0;padding:9px 10px;border-bottom:1px solid var(--line);color:#aab5c7;text-transform:uppercase}.bss-panel-body{padding:10px}.bss-field{display:grid;gap:5px;margin-bottom:10px}.bss-field>span{font-size:10px;color:var(--muted)}.bss-field input,.bss-field select{width:100%}.bss-check{display:flex;gap:8px;align-items:center;margin:8px 0}.bss-teamrow{display:grid;grid-template-columns:minmax(0,1fr) 78px 32px;gap:7px;align-items:center;margin-bottom:8px}.bss-specbtn{display:flex;align-items:center;gap:8px;width:100%;min-width:0;text-align:left}.bss-icon{width:34px;height:34px;object-fit:contain;image-rendering:pixelated;flex:none}.bss-icon.ph{display:grid;place-items:center;background:#202738;border-radius:7px;color:#77849a}.bss-specbtn span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-note{color:var(--muted);font-size:11px}.bss-sosbanner{border:1px solid #316954;background:#10261e;border-radius:9px;padding:9px;margin:9px 0;color:#91f1c7}.bss-sosstudio{height:100%;overflow:auto;padding:18px}.bss-sosgrid{display:grid;grid-template-columns:340px minmax(400px,1fr);gap:14px}.bss-profiles{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:10px;min-height:300px}.bss-prof{display:flex;align-items:center;gap:8px;border-bottom:1px solid #252d3b;padding:7px 3px}.bss-prof .grow{flex:1;min-width:0}.bss-prof b,.bss-prof small{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-prof small{color:var(--muted)}.bss-modalback{position:absolute;inset:0;background:#05070bcc;z-index:30;display:grid;place-items:center;padding:30px}.bss-modal{width:min(780px,94vw);max-height:min(720px,90vh);background:#141a24;border:1px solid #354057;border-radius:14px;display:flex;flex-direction:column;overflow:hidden;box-shadow:0 20px 80px #000}.bss-modalhead{display:flex;align-items:center;gap:8px;padding:12px;border-bottom:1px solid var(--line)}.bss-modalbody{overflow:auto;padding:10px}.bss-pickgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:7px}.bss-pick{display:flex;align-items:center;gap:8px;text-align:left;border:1px solid #2b3445;background:#171d28;color:var(--text);padding:6px;border-radius:9px;cursor:pointer}.bss-pick:hover{border-color:#5d75ce;background:#20283a}.bss-pick small{display:block;color:var(--muted)}.bss-toast{position:absolute;right:15px;bottom:15px;z-index:50;background:#1c2230;border:1px solid #3b4559;border-radius:9px;padding:10px 12px;max-width:520px;box-shadow:0 8px 30px #0008}.bss-empty{color:var(--muted);padding:30px;text-align:center}.bss-key{color:#8fa7ff}.bss-error{color:#ff9aa7}.bss-hidden{display:none!important}.bss-btn.active{background:var(--accent);border-color:#6380ff}.bss-dataset-meta{margin:8px 0 12px;padding:9px;border:1px solid var(--line);border-radius:8px;background:#0e131c}.bss-dataset-meta b,.bss-dataset-meta small{display:block}.bss-dataset-meta small,.bss-dataset-meta p{color:var(--muted);font-size:10px}.bss-dataset-meta p{margin:7px 0 0}.bss-groupindex{margin-top:10px}.bss-group-row{display:flex;justify-content:space-between;gap:12px;padding:7px 2px;border-bottom:1px solid #252d3b}.bss-group-row small{color:var(--muted);text-align:right}body.bss-fullscreen-lock{overflow:hidden!important;overscroll-behavior:none!important}.bss-root.bss-fullscreen-active{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;min-width:0!important;max-width:none!important;z-index:2147483000!important;margin:0!important;border-radius:0!important}.bss-fullscreen-session-controls{display:none}.bss-root.bss-fullscreen-active .bss-fullscreen-session-controls{display:flex;position:fixed;top:8px;right:10px;z-index:2147483640;gap:7px;align-items:center}.bss-root.bss-fullscreen-active .bss-top{padding-right:270px}
.bss-chipbox{display:flex;align-items:center;gap:5px;flex-wrap:wrap;min-height:30px;margin:4px 0 7px}.bss-chipbox.compact{margin:4px 0 0}.bss-chip{display:inline-flex;align-items:center;gap:4px;padding:3px 6px;border:1px solid #344058;background:#171e2a;border-radius:999px;font-size:10px;color:#dce5f7}.bss-chip button{border:0;background:transparent;color:#9aa8bc;padding:0 2px;cursor:pointer}.bss-chip button:hover{color:#ff9aa7}.bss-prof.override{background:#121d1b}.bss-prof>input[type=checkbox]{width:16px;height:16px;flex:none}.bss-example{width:100%;display:block;text-align:left;border:1px solid #303a50;background:#151c28;color:var(--text);border-radius:8px;padding:8px;margin:6px 0;cursor:pointer}.bss-example:hover{border-color:#5b75d3;background:#1c2535}.bss-example b,.bss-example small{display:block}.bss-example small{color:var(--muted);margin-top:3px;white-space:normal}.bss-sosstudio .bss-libhead{position:sticky;top:-18px;z-index:5;background:var(--bg);padding:10px 0}.bss-profiles .bss-prof{min-height:62px}

.bss-groupselect{min-width:210px}.bss-card-group{width:100%;margin-top:8px}.bss-mainlib-note{margin:-4px 0 14px;padding:9px 11px;border:1px solid #36534b;background:#10201c;border-radius:9px;color:#b9e8d7}.bss-poollist{display:grid;gap:6px;margin:7px 0}.bss-poolrow{display:grid;grid-template-columns:34px minmax(90px,1fr) auto 56px 34px;gap:7px;align-items:center;padding:6px;border:1px solid #2a3345;border-radius:8px;background:#10151e}.bss-poolrow .mini{width:72px;padding:5px 6px}.bss-poolrow label{display:flex;align-items:center;gap:5px;color:var(--muted);font-size:10px}.bss-profile-title{display:flex;justify-content:space-between;gap:12px;margin:2px 2px 10px}.bss-sosprofile-card{border:1px solid #2d3749;border-radius:10px;background:#111720;margin-bottom:9px;padding:7px}.bss-sosprofile-card .bss-prof{border-bottom:1px solid #293244}.bss-mini-field{display:grid;gap:2px;font-size:9px;color:var(--muted)}.bss-input.mini{width:70px;padding:5px 6px}.bss-reqbox{margin-top:7px;padding-top:7px;border-top:1px solid #283143}.bss-reqhead{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}.bss-reqrow{display:flex;gap:6px;align-items:center;margin-bottom:5px}.bss-reqrow .bss-select{min-width:150px}.bss-sosprofile-card .bss-icon{width:32px;height:32px}.bss-sosstudio .bss-profiles{overflow:visible}

/* v0.6.7 · compact workspace + BAS-equivalent expanded mode */
.bss-root{min-width:0}
.bss-top{height:52px;gap:6px;padding:6px 10px}
.bss-mark{width:34px;height:34px;border-radius:9px;font-size:17px}
.bss-brand{gap:8px;margin-right:5px}
.bss-brand strong{font-size:13px}
.bss-btn,.bss-nav{padding:6px 9px;border-radius:7px}
.bss-pill{padding:5px 8px}
.bss-library{padding:10px}
.bss-libhead{gap:7px;margin-bottom:10px}
.bss-card-art{height:102px}.bss-card-art img{max-height:96px}
.bss-card-body{padding:8px}.bss-card-actions{margin-top:7px}
.bss-editor{grid-template-columns:var(--left,205px) 4px minmax(300px,1fr) 4px var(--right,295px)}
.bss-side-head{padding:8px}.bss-sections{padding:5px}.bss-section{padding:7px 8px}
.bss-stagebar{height:38px;padding:4px 8px;gap:6px}
.bss-stage{padding:6px}
.bss-canvasbox{width:min(100%,880px);max-height:100%;box-shadow:0 8px 24px #0007}
.bss-inspector-inner{padding:7px}.bss-panel{margin-bottom:7px}.bss-panel h3{padding:7px 8px}.bss-panel-body{padding:7px}
.bss-field{gap:3px;margin-bottom:7px}.bss-check{margin:6px 0}
.bss-teamrow{gap:5px;margin-bottom:6px}.bss-icon{width:30px;height:30px}
.bss-sosbanner{padding:7px;margin:6px 0}
.bss-poollist{gap:4px;margin:5px 0}.bss-poolrow{grid-template-columns:30px minmax(75px,1fr) auto 50px 30px;gap:5px;padding:4px}
.bss-reqbox{margin-top:5px;padding-top:5px}.bss-reqrow{gap:4px;margin-bottom:4px}.bss-reqrow .bss-select{min-width:125px}
.bss-sosprofile-card{margin-bottom:6px;padding:5px}.bss-profiles .bss-prof{min-height:48px;padding:4px 2px}
.bss-sosstudio{height:100%;overflow:hidden;padding:8px;display:flex;flex-direction:column}
.bss-sosstudio .bss-libhead{position:static;top:auto;z-index:auto;background:transparent;padding:0;flex:none;min-height:34px}
.bss-sosgrid{grid-template-columns:minmax(260px,315px) minmax(340px,1fr);gap:8px;min-height:0;flex:1;overflow:hidden}
.bss-sosgrid>div:first-child{min-height:0;overflow:auto;padding-right:2px}
.bss-sosstudio .bss-profiles{min-height:0;overflow:auto!important;padding:7px}
.bss-example{cursor:default;padding:7px;margin:5px 0}.bss-example:hover{background:#151c28}
.bss-example-actions{display:flex;gap:5px;flex-wrap:wrap;margin-top:6px}
.bss-example-actions .bss-btn{flex:1;min-width:112px}
.bss-modalback{padding:12px}.bss-modal{max-height:94%}.bss-modalhead{padding:8px}.bss-modalbody{padding:7px}
.bss-pickgrid{grid-template-columns:repeat(auto-fill,minmax(165px,1fr));gap:5px}

/* BAS uses a document workspace overlay, not the browser/OS Fullscreen API.
   Keep its moderate z-index so Maker Studio/Electron window chrome stays above it. */
.bss-root.bss-fullscreen-active{
  position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;
  min-width:0!important;min-height:0!important;max-width:none!important;max-height:none!important;
  margin:0!important;border:0!important;border-radius:0!important;z-index:5000!important;
  box-shadow:none!important;background:var(--bg)!important
}
@supports(height:100dvh){.bss-root.bss-fullscreen-active{height:100dvh!important}}
.bss-root.bss-fullscreen-active .bss-fullscreen-session-controls{
  display:flex;position:fixed;top:10px;right:12px;z-index:2147483647;gap:8px;align-items:center;
  padding:6px;border:1px solid rgba(255,255,255,.12);border-radius:10px;
  background:rgba(20,22,30,.94);box-shadow:0 8px 28px rgba(0,0,0,.32)
}
.bss-root.bss-fullscreen-active .bss-top{padding-right:260px}

@media(max-width:1180px){
  .bss-brand small,.bss-pill{display:none}
  .bss-brand{margin-right:0}
  .bss-editor{grid-template-columns:minmax(145px,var(--left,180px)) 3px minmax(280px,1fr) 3px minmax(245px,var(--right,270px))}
  .bss-stagebar .bss-note{display:none}
  .bss-sosgrid{grid-template-columns:minmax(235px,285px) minmax(320px,1fr)}
  .bss-profile-title p{display:none}
}
@media(max-width:920px){
  .bss-top{gap:4px;padding-left:6px;padding-right:6px}
  .bss-mark{display:none}.bss-brand strong{font-size:12px}
  .bss-btn,.bss-nav{padding:5px 7px}
  .bss-editor{grid-template-columns:145px 3px minmax(260px,1fr) 3px 245px}
  .bss-stage{padding:3px}
  .bss-sosgrid{grid-template-columns:235px minmax(300px,1fr)}
  .bss-search{width:min(300px,36vw)}
}


.bss-example-filters{display:grid;grid-template-columns:minmax(0,1fr) minmax(150px,.7fr);gap:7px;margin:7px 0}.bss-example-list{max-height:420px;overflow:auto;overscroll-behavior:contain;padding-right:3px}.bss-example-list .bss-example{margin-bottom:6px}@media(max-width:1050px){.bss-example-filters{grid-template-columns:1fr}.bss-example-list{max-height:330px}}

/* v0.6.8 SOS Studio organization */
.bss-sosgrid>div:first-child>.bss-panel:nth-of-type(2){display:none!important}
.bss-import-modal{width:min(1040px,96vw);height:min(780px,94vh)}
.bss-import-tabs{display:flex;gap:6px;padding:8px;border-bottom:1px solid var(--line);flex-wrap:wrap}
.bss-import-tools{display:grid;grid-template-columns:minmax(200px,1fr) minmax(180px,320px);gap:7px;padding:8px;border-bottom:1px solid var(--line)}
.bss-import-summary{padding:6px 10px;color:var(--muted);font-size:10px;border-bottom:1px solid var(--line)}
.bss-import-list{overflow:auto;padding:8px;display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:7px;min-height:0}
.bss-import-card{display:grid;grid-template-columns:46px minmax(0,1fr) auto;align-items:center;gap:8px;padding:7px;border:1px solid #2d3749;border-radius:9px;background:#111720}
.bss-import-caller{width:44px!important;height:44px!important}.bss-import-info{min-width:0}.bss-import-info>b,.bss-import-info>small{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-import-info>small{color:var(--muted);font-size:9px}.bss-import-allies{display:flex;align-items:center;gap:2px;margin-top:4px;min-height:25px}.bss-import-ally{width:24px!important;height:24px!important}.bss-import-allies small{color:var(--muted);font-size:9px;margin-left:3px}
@media(max-width:900px){.bss-import-tools{grid-template-columns:1fr}.bss-import-list{grid-template-columns:1fr}.bss-sosgrid{grid-template-columns:minmax(220px,270px) minmax(300px,1fr)}}

/* v0.6.11 compact runtime SOS pools */
.bss-pool-preview{display:flex;align-items:center;gap:8px;padding:8px 5px;border-bottom:1px solid #252d3b;background:#10151e}.bss-pool-preview .grow{flex:1;min-width:0}.bss-pool-preview b,.bss-pool-preview small{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-pool-preview small{color:var(--muted);font-size:9px}.bss-pool-preview-icons{display:flex;align-items:center;min-width:62px}.bss-pool-preview-icons .bss-icon{width:28px;height:28px;margin-left:-7px;border:2px solid #141923;border-radius:50%;background:#1a2130}.bss-pool-preview-icons .bss-icon:first-child{margin-left:0}.bss-pool-more{font-size:9px;padding:3px 5px;border-radius:999px;background:#252e40;color:#bcc7dc;margin-left:2px}.bss-poollist.expanded{padding:7px;background:#0d121a;border-bottom:1px solid #252d3b}.bss-sosprofile-card{border:1px solid #2a3344;border-radius:10px;overflow:hidden;margin:8px 0;background:#121720}.bss-sosprofile-card .bss-reqbox{margin:7px}.bss-sosstudio{padding:10px}.bss-sosstudio .bss-libhead{top:-10px}.bss-sosgrid{grid-template-columns:minmax(250px,310px) minmax(430px,1fr)}
@media(max-width:1050px){.bss-sosgrid{grid-template-columns:minmax(225px,270px) minmax(360px,1fr)}.bss-pool-preview{gap:5px}.bss-pool-preview-icons .bss-icon{width:24px;height:24px}}

/* v0.6.12 · compact SOS grid + pool modal */
.bss-profile-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:8px;align-content:start}
.bss-sosprofile-tile{border:1px solid #2a3344;border-radius:10px;overflow:hidden;background:#121720;min-width:0}
.bss-sosprofile-tile .bss-prof{min-height:48px;padding:6px 7px;border-bottom:1px solid #252d3b}
.bss-sosprofile-tile .bss-icon{width:32px;height:32px}
.bss-tile-rates{display:grid;grid-template-columns:1fr 1fr;gap:6px;padding:6px 7px;border-bottom:1px solid #252d3b}
.bss-tile-rates .bss-input.mini{width:100%}
.bss-pool-preview.compact{padding:6px 7px;border-bottom:0;justify-content:space-between}
.bss-pool-preview.compact .bss-pool-preview-icons{min-width:0;overflow:hidden}
.bss-tile-req{border-top:1px solid #252d3b;background:#0f141c}
.bss-tile-req>summary{cursor:pointer;color:#aeb8ca;font-size:10px;padding:6px 8px;user-select:none}
.bss-tile-req .bss-reqbox{margin:0!important;padding:7px!important;border-top:1px solid #252d3b}
.bss-tile-req .bss-reqrow{display:grid;grid-template-columns:minmax(110px,1fr) auto auto auto}
.bss-pool-modal{width:min(720px,94vw);max-height:min(720px,90vh)}
.bss-pool-modal .bss-modalhead>div:first-child b,.bss-pool-modal .bss-modalhead>div:first-child small{display:block}
.bss-import-list{grid-template-columns:repeat(auto-fill,minmax(245px,1fr))}
.bss-import-card{grid-template-columns:44px minmax(0,1fr);align-content:start}
.bss-import-card>.bss-btn{grid-column:1/-1;width:100%}
.bss-btn:disabled{opacity:.45;cursor:default;pointer-events:none}
@media(max-width:1050px){.bss-profile-grid{grid-template-columns:repeat(auto-fill,minmax(210px,1fr))}}
/* v0.6.22 · live SOS selection + level controls */
.bss-sosprofile-tile.selected{outline:1px solid var(--accent,#668cff);box-shadow:0 0 0 1px rgba(102,140,255,.2) inset}
.bss-level-range{display:grid;grid-template-columns:minmax(72px,1fr) auto minmax(72px,1fr);gap:6px;align-items:center}
.bss-level-range>span{text-align:center;color:var(--muted)}

/* v0.6.22 · nested pool picker, scripted SOS composition/messages */
.bss-picker-modalback{z-index:80!important}
.bss-subpanel{margin-top:12px;padding:10px;border:1px solid var(--line);border-radius:9px;background:#0f141d}
.bss-subpanel>b{display:block;margin-bottom:4px}
.bss-fixed-slot{margin-left:auto;color:#9fb0ca;font-size:10px;border:1px solid #344058;border-radius:999px;padding:3px 7px;background:#171e2a}

/* v0.6.23 · scripted SOS moveset + stable weighted pool controls */
.bss-poolentry{border-bottom:1px solid #222a37;padding:4px 0 7px}.bss-poolentry:last-child{border-bottom:0}.bss-poolentry .bss-poolrow{border-bottom:0;padding-bottom:4px}.bss-sos-moves{display:grid;gap:5px;padding:2px 7px 4px 42px;color:var(--text-secondary,#b7bdca);font-size:10px}.bss-sos-moves>label{display:flex;align-items:center;gap:7px}.bss-sos-moves .bss-select.mini{width:auto;min-width:155px;padding:4px 6px}.bss-movegrid{display:grid;grid-template-columns:1fr 1fr;gap:5px}.bss-movegrid .bss-input{padding:5px 6px;font-size:10px}.bss-poolrow .bss-btn{flex:0 0 auto}

/* Boss/Totem editor */
.bss-bossbanner{border:1px solid #725c31;background:#241c0f;border-radius:9px;padding:9px;margin:9px 0;color:#f0cf83}
.bss-boss-stats{display:grid;grid-template-columns:1fr 1fr;gap:7px}
.bss-boss-stat{display:grid;grid-template-columns:minmax(0,1fr) 70px;align-items:center;gap:7px;padding:6px 7px;border:1px solid #2b3445;border-radius:8px;background:#10151e}
.bss-boss-stat span{font-size:10px;color:var(--muted)}
.bss-boss-stat .bss-input{width:70px;padding:5px 6px}
@media(max-width:1050px){.bss-boss-stats{grid-template-columns:1fr}}

/* v0.6.25 · compact inspector, lazy preview and custom Pokémon modal */
.bss-editor{grid-template-columns:var(--left,180px) 4px minmax(300px,1fr) 4px var(--right,470px)}
.bss-stage{padding:8px;align-items:start}
.bss-canvasbox{width:min(100%,680px);max-height:calc(100vh - 135px);margin-top:6px}
.bss-teamrow{grid-template-columns:minmax(0,1fr) 72px 34px 34px}
.bss-scripted-poolrow{grid-template-columns:30px minmax(82px,1fr) auto 46px 34px auto 34px}
.bss-scripted-poolrow .bss-fixed-slot{margin-left:0}
.bss-optiongroup{margin-top:8px;border:1px solid var(--line);border-radius:9px;background:#0f141d;overflow:hidden}
.bss-optiongroup>summary{cursor:pointer;user-select:none;padding:8px 10px;font-size:10px;font-weight:700;color:#c5cede;background:#121924}
.bss-optiongroup[open]>summary{border-bottom:1px solid var(--line)}
.bss-optiongroup>.bss-field,.bss-optiongroup>p,.bss-optiongroup>.bss-boss-stats,.bss-optiongroup>.bss-btn{margin-left:9px;margin-right:9px}
.bss-optiongroup>.bss-field:first-of-type,.bss-optiongroup>p:first-of-type{margin-top:9px}
.bss-optiongroup>.bss-btn{margin-bottom:9px}
.bss-mon-modalback{z-index:95!important}
.bss-mon-modal{width:min(860px,94vw);max-height:min(780px,92vh)}
.bss-mon-sections{display:grid;gap:8px}
.bss-mon-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:9px}
.bss-mon-grid .bss-field{margin-bottom:0}
.bss-stat-editor{display:grid;grid-template-columns:80px repeat(3,minmax(80px,1fr));gap:6px;align-items:center;padding:8px 9px}
.bss-stat-editor+ .bss-stat-editor{border-top:1px solid #252d3b}
.bss-stat-editor>b{font-size:10px;color:#aeb8ca}
.bss-stat-editor label{display:grid;gap:3px}
.bss-stat-editor label span{font-size:9px;color:var(--muted)}
.bss-stat-editor .bss-input{width:100%;padding:5px 6px}
.bss-mon-modal .bss-movegrid{padding:9px}
.bss-mon-modal .bss-movechoice{display:grid;gap:5px;padding:7px;border:1px solid #293244;border-radius:7px;background:rgba(8,12,19,.36)}
.bss-mon-modal .bss-movechoice>label{display:grid;gap:4px}.bss-mon-modal .bss-movechoice .bss-select{width:100%;min-width:0}

.bss-mon-modal .bss-optiongroup>.bss-field{margin-top:9px}
@media(max-width:1180px){
  .bss-editor{grid-template-columns:minmax(145px,var(--left,165px)) 3px minmax(250px,1fr) 3px minmax(390px,var(--right,430px))}
  .bss-canvasbox{width:min(100%,560px)}
  .bss-scripted-poolrow{grid-template-columns:30px minmax(70px,1fr) auto 34px auto 34px}
  .bss-scripted-poolrow>small{display:none}
}
@media(max-width:900px){
  .bss-editor{grid-template-columns:140px 3px minmax(220px,1fr) 3px 360px}
  .bss-canvasbox{width:min(100%,460px)}
  .bss-mon-grid{grid-template-columns:1fr}
  .bss-stat-editor{grid-template-columns:70px repeat(2,minmax(70px,1fr))}
}

/* v0.6.25 · optional preview collapse for option-heavy blueprints */
.bss-editor.preview-collapsed{grid-template-columns:var(--left,180px) 4px minmax(220px,280px) 4px minmax(520px,1fr)}
.bss-editor.preview-collapsed .bss-stagewrap{min-width:0}
.bss-editor.preview-collapsed .bss-stage{min-height:180px;display:flex;align-items:flex-start;justify-content:center}
.bss-preview-collapsed-note{width:min(230px,calc(100% - 16px));margin-top:18px;padding:12px;border:1px dashed #344058;border-radius:10px;background:#0f141d;text-align:center}
.bss-preview-collapsed-note b,.bss-preview-collapsed-note small{display:block}
.bss-preview-collapsed-note small{margin:5px 0 10px;color:var(--muted);font-size:9px;line-height:1.4}

/* v0.6.36 · runtime-equivalent aura preview */
.bss-aura-runtime-particle{position:absolute;width:70px;height:70px;object-fit:fill;image-rendering:pixelated;pointer-events:none;transform-origin:50% 100%;opacity:0;visibility:hidden;will-change:left,top,width,height,opacity,transform}
.bss-aura-live-preview>.bss-aura-demo-mon{z-index:3}
.bss-aura-preview-note b{color:var(--text);font-weight:700}
@media(max-width:1100px){.bss-editor.preview-collapsed{grid-template-columns:145px 3px 210px 3px minmax(390px,1fr)}}


/* v0.6.32 · editable EBDX-style Totem aura */
.bss-aura-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:9px}
.bss-aura-grid>.bss-field{margin:0!important}
.bss-aura-grid>.bss-check{margin:0;padding:8px;border:1px solid #2b3445;border-radius:8px;background:#10151e}
.bss-colorrow{display:grid;grid-template-columns:44px minmax(0,1fr);gap:7px;align-items:center}
.bss-color{width:44px;height:30px;padding:1px;border:1px solid #39445a;border-radius:7px;background:#0c1119;cursor:pointer}
@media(max-width:1050px){.bss-aura-grid{grid-template-columns:1fr}}


/* v0.6.33 Aura Studio */
.bss-aura-studio-launch{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:8px 0 12px}.bss-aura-studio-modal{z-index:140}.bss-aura-studio{width:min(920px,94vw);max-height:88vh}.bss-aura-studio-body{display:grid;grid-template-columns:210px minmax(0,1fr);min-height:520px}.bss-aura-profile-list{padding:12px;border-right:1px solid var(--border);display:flex;flex-direction:column;gap:7px;overflow:auto}.bss-aura-profile{display:flex;flex-direction:column;gap:2px;text-align:left;border:1px solid var(--border);background:var(--bg-secondary);color:inherit;border-radius:7px;padding:9px;cursor:pointer}.bss-aura-profile.active{border-color:var(--accent);background:rgba(90,110,255,.12)}.bss-aura-profile small{opacity:.65}.bss-aura-studio main{padding:14px;overflow:auto}.bss-aura-live-preview{height:250px;position:relative;overflow:hidden;border:1px solid var(--border);border-radius:10px;background:radial-gradient(circle at 50% 62%,rgba(255,255,255,.09),rgba(0,0,0,.45) 55%),#161821;display:grid;place-items:center}.bss-aura-demo-mon{position:relative;z-index:3;width:130px;height:95px;border-radius:45% 45% 38% 38%;display:grid;place-items:center;font-weight:900;letter-spacing:.08em;color:white;background:#4e556c;box-shadow:0 0 3px 2px var(--outline),0 0 12px 3px color-mix(in srgb,var(--outline) 75%,transparent)}.bss-aura-live-preview i{position:absolute;left:50%;top:69%;width:15px;height:36px;border-radius:65% 35% 60% 40%;background:linear-gradient(to top,var(--aura),transparent);filter:drop-shadow(0 0 4px var(--aura));opacity:0;scale:var(--wisp-scale,1);transform:translateX(calc(var(--x) * var(--spread)));animation:bssAuraWisp var(--speed) linear infinite;animation-delay:calc(var(--i) * -0.071s)}@keyframes bssAuraWisp{0%{opacity:0;transform:translateX(calc(var(--x) * var(--spread))) translateY(10px) scale(.55)}18%{opacity:.95}68%{opacity:.8}100%{opacity:0;transform:translateX(calc(var(--x) * var(--spread))) translateY(-92px) scale(1.15)}}.bss-aura-edit-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-top:12px}.bss-aura-edit-grid label{display:grid;gap:5px;font-size:11px}.bss-tile-rates b{font-size:10px;color:var(--text-secondary)}


/* v0.6.34 · persistent navigation + visible Aura Studio */
.bss-inspector{position:relative;scroll-behavior:smooth}.bss-inspector-jumpbar{position:sticky;top:0;z-index:20;display:flex;gap:4px;overflow-x:auto;padding:6px;background:#111620f2;border-bottom:1px solid var(--line);backdrop-filter:blur(5px)}.bss-jump{flex:none;border:1px solid #30394b;background:#171d28;color:#bdc8dc;border-radius:6px;padding:5px 7px;font-size:9px;cursor:pointer}.bss-jump.active{background:var(--accent);border-color:#6380ff;color:white}.bss-aura-studio-prominent{padding:8px;border:1px solid #33415d;border-radius:9px;background:#111827}.bss-aura-section-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:10px}.bss-aura-section-head b,.bss-aura-section-head small{display:block}.bss-aura-section-head small{color:var(--muted);margin-top:3px}.bss-aura-inline-preview{height:220px;margin-bottom:10px}.bss-aura-profile-summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:6px;margin:10px 0}.bss-aura-studio-body{border-color:var(--line)}.bss-aura-profile-list{border-right-color:var(--line)}.bss-aura-profile{border-color:var(--line);background:#10151e}.bss-aura-live-preview{border-color:var(--line)}
/* Aura wisps reset only while fully transparent; the reset itself is never visible. */
.bss-aura-live-preview i{animation-timing-function:linear}@keyframes bssAuraWisp{0%,7%{opacity:0;transform:translateX(calc(var(--x) * var(--spread))) translateY(12px) scale(.50)}20%{opacity:.92}58%{opacity:.86}86%{opacity:.22}93%,100%{opacity:0;transform:translateX(calc(var(--x) * var(--spread))) translateY(-92px) scale(1.15)}}


/* v0.6.36 · standalone Aura Studio + fast tab navigation */
.bss-aura-studio-screen{height:100%;min-height:0;overflow:hidden;padding:8px;display:flex;flex-direction:column}
.bss-aura-studio-screen>.bss-libhead{flex:none;min-height:38px;margin-bottom:8px;padding:0 2px}
.bss-aura-title{display:flex;flex-direction:column;min-width:0}.bss-aura-title small{color:var(--muted);font-size:9px;margin-top:2px}
.bss-aura-workspace{flex:1;min-height:0;display:grid;grid-template-columns:minmax(170px,230px) minmax(0,1fr);border:1px solid var(--line);border-radius:12px;overflow:hidden;background:#0c1118}
.bss-aura-workspace>.bss-aura-profile-list{min-height:0;overflow:auto;padding:8px;background:#10151e;border-right:1px solid var(--line)}
.bss-aura-main{min-width:0;min-height:0;display:grid;grid-template-columns:minmax(320px,.9fr) minmax(390px,1.1fr);overflow:hidden;background:#0d121a}
.bss-aura-preview-column{min-width:0;min-height:0;padding:12px;display:flex;flex-direction:column;gap:8px;border-right:1px solid var(--line);overflow:auto}
.bss-aura-testbar{display:flex;align-items:center;justify-content:space-between;gap:10px}.bss-aura-testbar b,.bss-aura-testbar small{display:block}.bss-aura-testbar small{color:var(--muted);font-size:9px;margin-top:2px}
.bss-aura-studio-preview{height:min(430px,52vh);min-height:290px;flex:none}
.bss-aura-demo-mon{position:relative;z-index:3;width:300px;height:260px;max-width:88%;max-height:82%;border-radius:0;background:transparent!important;box-shadow:none!important;display:grid;place-items:center;color:#9aa8bc;font-size:11px;text-align:center}
.bss-aura-test-img{display:block;max-width:none;max-height:none;object-fit:contain;image-rendering:pixelated;position:relative;z-index:3}
.bss-aura-preview-note{padding:8px 10px;border:1px solid #29354a;border-radius:8px;background:#101722;color:var(--muted);font-size:9px;line-height:1.45}
.bss-aura-controls{min-width:0;min-height:0;display:flex;flex-direction:column;overflow:hidden}
.bss-aura-tabs{flex:none;display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:5px;padding:8px;border-bottom:1px solid var(--line);background:#10151e}
.bss-aura-tab{border:1px solid #30394b;background:#171d28;color:#bdc8dc;border-radius:7px;padding:8px 5px;cursor:pointer;font-size:10px}.bss-aura-tab:hover{background:#20283a}.bss-aura-tab.active{background:var(--accent);border-color:#6380ff;color:#fff}
.bss-aura-tabbody{flex:1;min-height:0;overflow:auto;padding:10px;overscroll-behavior:contain}
.bss-aura-settings-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;align-content:start}.bss-aura-settings-grid>.bss-field{margin:0}.bss-aura-settings-grid>.bss-check{margin:0;padding:9px;border:1px solid #2b3445;border-radius:8px;background:#10151e;min-height:42px}
.bss-aura-settings-grid input[type=color]{width:100%;height:36px;border:1px solid #39445a;border-radius:7px;background:#0c1119}
.bss-aura-info-card{grid-column:1/-1;padding:10px;border:1px solid #33415d;border-radius:9px;background:#111827}.bss-aura-info-card b,.bss-aura-info-card span{display:block}.bss-aura-info-card span{color:var(--muted);font-size:9px;margin-top:5px;line-height:1.45}
.bss-aura-shortcuts{flex:none;margin:0 10px 10px;padding:8px 10px;border:1px solid #263145;border-radius:8px;background:#0f151f}.bss-aura-shortcuts b,.bss-aura-shortcuts span{display:block}.bss-aura-shortcuts span{color:var(--muted);font-size:9px;margin-top:3px}
.bss-aura-profile-summary{max-height:180px;overflow:auto;overscroll-behavior:contain}
.bss-aura-live-preview i{animation-delay:var(--delay,0s)!important;opacity:0}
@keyframes bssAuraWisp{0%,7%{opacity:calc(var(--aura-o-start,0)*var(--wisp-opacity,1));transform:translateX(calc(var(--x) * var(--spread))) translateY(12px) scale(.50)}20%{opacity:calc((var(--aura-o-start,0) + (var(--aura-o-mid,1) - var(--aura-o-start,0)) * .55)*var(--wisp-opacity,1))}55%{opacity:calc(var(--aura-o-mid,1)*var(--wisp-opacity,1))}86%{opacity:calc((var(--aura-o-end,0) + (var(--aura-o-mid,1) - var(--aura-o-end,0)) * .25)*var(--wisp-opacity,1))}93%,100%{opacity:calc(var(--aura-o-end,0)*var(--wisp-opacity,1));transform:translateX(calc(var(--x) * var(--spread))) translateY(-92px) scale(1.15)}}

/* v0.6.36 · runtime-equivalent aura preview */
.bss-aura-runtime-particle{position:absolute;width:70px;height:70px;object-fit:fill;image-rendering:pixelated;pointer-events:none;transform-origin:50% 100%;opacity:0;visibility:hidden;will-change:left,top,width,height,opacity,transform}
.bss-aura-live-preview>.bss-aura-demo-mon{z-index:3}
.bss-aura-preview-note b{color:var(--text);font-weight:700}
@media(max-width:1100px){.bss-aura-main{grid-template-columns:minmax(285px,.8fr) minmax(330px,1.2fr)}.bss-aura-workspace{grid-template-columns:180px minmax(0,1fr)}.bss-aura-studio-preview{min-height:250px}}
@media(max-width:860px){.bss-aura-workspace{grid-template-columns:155px minmax(0,1fr)}.bss-aura-main{grid-template-columns:1fr;overflow:auto}.bss-aura-preview-column{border-right:0;border-bottom:1px solid var(--line)}.bss-aura-controls{min-height:420px}.bss-aura-settings-grid{grid-template-columns:1fr}.bss-aura-tabs{grid-template-columns:1fr 1fr}.bss-aura-studio-preview{height:280px;min-height:240px}}
/* v0.6.37 · configurable aura graphics */
.bss-aura-settings-wide{grid-column:1/-1;min-width:0}.bss-aura-sequence-editor{grid-column:1/-1;border:1px solid #303a50;border-radius:9px;background:#0f151f;padding:9px;display:grid;gap:6px}.bss-aura-sequence-head{display:flex;align-items:center;gap:8px}.bss-aura-sequence-head b{flex:1}.bss-aura-sequence-row{display:grid;grid-template-columns:24px minmax(0,1fr) auto 34px 34px 34px;gap:5px;align-items:center}.bss-aura-sequence-row>span{text-align:center;color:var(--muted);font-size:10px}.bss-aura-sequence-row .bss-select{width:100%}.bss-aura-sequence-editor>small{color:var(--muted);font-size:9px;line-height:1.4}.bss-aura-inline-preview{min-height:230px;margin:10px 0}.bss-aura-inline-preview .bss-aura-demo-mon{min-height:185px}.bss-aura-inline-preview .bss-aura-test-img{max-width:none;max-height:none}

/* v0.6.37 · Blueprint aura preview is a first-class visual, not a tiny strip. */
.bss-aura-blueprint-preview-card{margin:10px 0 12px;padding:10px;border:1px solid #3b4b68;border-radius:10px;background:#0b111a;box-shadow:inset 0 0 0 1px rgba(255,255,255,.018)}
.bss-aura-blueprint-preview-head{display:flex;align-items:flex-start;gap:10px;margin-bottom:8px}.bss-aura-blueprint-preview-head>div{flex:1;min-width:0}.bss-aura-blueprint-preview-head b,.bss-aura-blueprint-preview-head small{display:block}.bss-aura-blueprint-preview-head small{margin-top:3px;color:var(--muted);font-size:9px;line-height:1.4}.bss-aura-blueprint-preview-head>span{max-width:42%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:4px 7px;border:1px solid #34425b;border-radius:999px;background:#121a27;color:#d9e3f4;font-size:9px}
.bss-aura-blueprint-preview-card .bss-aura-inline-preview{height:300px;min-height:300px;margin:0;border-color:#394964;background:radial-gradient(circle at 50% 62%,rgba(255,255,255,.035),rgba(5,8,13,.18) 40%,rgba(5,8,13,.72) 78%)}
.bss-aura-blueprint-preview-card .bss-aura-inline-preview .bss-aura-demo-mon{min-height:250px;max-height:88%}
@media(max-width:860px){.bss-aura-blueprint-preview-card .bss-aura-inline-preview{height:260px;min-height:260px}.bss-aura-blueprint-preview-card .bss-aura-inline-preview .bss-aura-demo-mon{min-height:215px}}

/* v0.6.39 · project-wide asset picker + clearer aura editing */
.bss-asset-field{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:6px;align-items:center}.bss-asset-field>.bss-select{min-width:0}.bss-asset-picker-modal{z-index:190}.bss-asset-picker-card{width:min(980px,94vw);height:min(760px,88vh);display:flex;flex-direction:column;gap:9px;overflow:hidden}.bss-asset-picker-card>.bss-input{flex:none}.bss-asset-picker-grid{flex:1;min-height:0;overflow:auto;overscroll-behavior:contain;display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;padding:2px 3px 8px}.bss-asset-tile{min-width:0;border:1px solid #2f3b50;border-radius:9px;background:#101722;color:inherit;padding:7px;display:flex;flex-direction:column;gap:5px;text-align:left;cursor:pointer}.bss-asset-tile:hover{border-color:#667ff2;background:#151e2d}.bss-asset-tile b{font-size:9px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-asset-tile small{font-size:8px;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-asset-thumb{height:104px;border:1px solid #273349;border-radius:7px;background:#080c12;display:grid;place-items:center;overflow:hidden}.bss-asset-thumb img{display:block;max-width:100%;max-height:100%;image-rendering:pixelated;object-fit:contain}.bss-asset-audio-icon{height:104px;border:1px solid #273349;border-radius:7px;background:#0b1018;display:grid;place-items:center;font-size:34px;color:#9eacd0}.bss-aura-explain{display:flex;flex-direction:column;gap:4px;padding:9px 10px;margin-bottom:9px;border:1px solid #33415d;border-radius:9px;background:#111827}.bss-aura-explain b{font-size:10px}.bss-aura-explain span{font-size:9px;line-height:1.45;color:var(--muted)}.bss-aura-sequence-head>div{flex:1;min-width:0}.bss-aura-sequence-head b,.bss-aura-sequence-head small{display:block}.bss-aura-sequence-head small{color:var(--muted);font-size:8px;line-height:1.4;margin-top:3px}.bss-aura-parallel-layer{border-color:#34445e;background:#0f1621}.bss-aura-layer-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:7px 0}.bss-aura-empty-layer{padding:9px;border:1px dashed #33415d;border-radius:8px;color:var(--muted);font-size:9px}.bss-aura-parallel-particle{pointer-events:none}.bss-aura-blueprint-preview-card .bss-aura-inline-preview{height:340px;min-height:340px}.bss-aura-blueprint-preview-card .bss-aura-inline-preview .bss-aura-demo-mon{min-height:285px}
@media(max-width:860px){.bss-aura-tabs{grid-template-columns:repeat(3,minmax(0,1fr))}.bss-asset-picker-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.bss-asset-field{grid-template-columns:minmax(0,1fr) auto}.bss-asset-field>[data-asset-clear]{grid-column:2}.bss-aura-blueprint-preview-card .bss-aura-inline-preview{height:285px;min-height:285px}.bss-aura-blueprint-preview-card .bss-aura-inline-preview .bss-aura-demo-mon{min-height:235px}}

/* v0.6.39 · aura preview hydration regression fix */
.bss-aura-demo-mon>[data-aura-test-battler]{position:relative;z-index:3}.bss-aura-live-preview .bss-aura-test-img{visibility:visible;opacity:1}.bss-aura-runtime-particle,.bss-aura-parallel-particle{pointer-events:none}


/* v0.6.40 · global settings, project browser and Aura Studio navigation */
.bss-global-settings-modal,.bss-asset-picker-modal{position:absolute!important;inset:0!important;width:auto!important;max-height:none!important;background:#05070bd9!important;border:0!important;border-radius:0!important;z-index:205!important;display:grid!important;place-items:center!important;padding:18px!important;overflow:hidden!important;box-shadow:none!important}
.bss-modal-card{background:#141a24;border:1px solid #354057;border-radius:14px;box-shadow:0 20px 80px #000;overflow:hidden;color:var(--text)}
.bss-global-settings-card{width:min(720px,92vw);max-height:min(760px,86vh);display:flex;flex-direction:column;overflow:auto}
.bss-modal-head{display:flex;align-items:center;gap:10px;padding:12px 14px;border-bottom:1px solid var(--line);background:#111722;position:sticky;top:0;z-index:3}.bss-modal-head>div{flex:1;min-width:0}.bss-modal-head b,.bss-modal-head small{display:block}.bss-modal-head small{color:var(--muted);font-size:9px;margin-top:3px;line-height:1.4}
.bss-global-settings-section{padding:14px;border-bottom:1px solid var(--line)}.bss-global-settings-section:last-child{border-bottom:0}.bss-global-settings-section h3{font-size:11px;margin:0 0 10px;color:#cbd6ea}.bss-global-settings-section .bss-note{margin:8px 0 0}
.bss-global-status{display:flex;align-items:center;gap:8px;padding:8px 10px;border:1px solid #2f3d55;border-radius:8px;background:#0f1620}.bss-global-status strong{color:#dce6f7}
.bss-asset-picker-card{width:min(1080px,95vw)!important;height:min(790px,90vh)!important;max-height:none!important;display:flex!important;flex-direction:column!important;gap:0!important;overflow:hidden!important}
.bss-asset-picker-toolbar{display:grid;grid-template-columns:minmax(260px,1fr) minmax(180px,260px);gap:8px;padding:10px 12px;border-bottom:1px solid var(--line);background:#0f151f;flex:none}.bss-asset-picker-toolbar .bss-input,.bss-asset-picker-toolbar .bss-select{width:100%}
.bss-asset-picker-layout{display:grid;grid-template-columns:190px minmax(0,1fr);flex:1;min-height:0;overflow:hidden}.bss-asset-folder-list{min-height:0;overflow:auto;padding:8px;background:#0d121a;border-right:1px solid var(--line);display:flex;flex-direction:column;gap:4px}.bss-asset-folder{border:1px solid transparent;border-radius:7px;background:transparent;color:#b9c5d9;padding:7px 8px;text-align:left;cursor:pointer;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss-asset-folder:hover{background:#182131;border-color:#2f3b51}.bss-asset-folder.active{background:#26324a;border-color:#536da9;color:#fff}
.bss-asset-picker-grid{padding:10px!important;align-content:start}.bss-asset-tile{height:155px}.bss-asset-thumb,.bss-asset-audio-icon{height:100px}.bss-asset-picker-grid>.bss-empty{grid-column:1/-1}
.bss-aura-tabs{position:sticky;top:0;z-index:6;box-shadow:0 5px 12px #0007}.bss-aura-layer-tabs{display:flex;gap:5px;align-items:center;position:sticky;top:0;z-index:5;margin:-10px -10px 10px;padding:8px 10px;background:#0e141d;border-bottom:1px solid #2b3548;overflow-x:auto}.bss-aura-layer-tab{flex:none;border:1px solid #303b50;background:#151c28;color:#b9c6db;border-radius:7px;padding:7px 9px;cursor:pointer;white-space:nowrap}.bss-aura-layer-tab:hover{background:#202a3c}.bss-aura-layer-tab.active{background:#425bc2;border-color:#6f87ef;color:#fff}
.bss-aura-layer-editor{display:grid;gap:9px}.bss-aura-parallel-layer{padding:10px;border:1px solid #34445e;border-radius:10px;background:#0f1621}.bss-aura-tabbody{scrollbar-gutter:stable}.bss-aura-settings-grid{padding-bottom:8px}.bss-aura-sequence-editor{scroll-margin-top:55px}.bss-aura-sequence-row{scroll-margin-top:60px}
.bss-aura-outline-stack{position:absolute;inset:0;pointer-events:none;z-index:2;overflow:visible}.bss-aura-outline-copy{position:absolute;left:50%;top:50%;max-width:none;max-height:none;image-rendering:pixelated;pointer-events:none;transform-origin:50% 50%;opacity:0;visibility:hidden;z-index:2}.bss-aura-test-img{position:relative;z-index:4}.bss-aura-demo-mon{isolation:isolate;overflow:visible!important}
.bss-aura-preview-note{position:sticky;bottom:0;z-index:4;background:#101722f2}
@media(max-width:900px){.bss-asset-picker-layout{grid-template-columns:145px minmax(0,1fr)}.bss-asset-picker-toolbar{grid-template-columns:1fr}.bss-asset-tile{height:145px}.bss-aura-layer-tabs{top:0}.bss-global-settings-modal,.bss-asset-picker-modal{padding:8px!important}}

.bss-global-inline-status{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;padding:9px 10px;margin:8px 0;border:1px solid #2d394d;border-radius:8px;background:#0d141e;color:#aebbd0}.bss-global-inline-status b{color:#e5ecf8}
`;

/* v0.6.42 · dedicated BGM browser / transport */
STYLES += `
.bss-asset-picker-grid.audio-mode{display:block!important;padding:8px 10px!important}
.bss-audio-list{display:flex;flex-direction:column;gap:4px;min-height:100%}
.bss-audio-row{width:100%;min-height:48px;border:1px solid transparent;border-radius:8px;background:#0e151f;color:inherit;padding:7px 9px;display:grid;grid-template-columns:30px minmax(0,1fr);gap:8px;align-items:center;text-align:left;cursor:pointer}
.bss-audio-row:hover{background:#172131;border-color:#31425c}.bss-audio-row.active{background:#22304a;border-color:#6f89d8;box-shadow:inset 3px 0 0 #8ea4ee}
.bss-audio-note{width:28px;height:28px;border-radius:7px;border:1px solid #314059;background:#111a28;display:grid;place-items:center;color:#aab9e5;font-size:17px}
.bss-audio-copy{min-width:0;display:flex;flex-direction:column;gap:2px}.bss-audio-copy b{font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss-audio-copy small{font-size:8px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bss-audio-preview-bar{flex:none;display:grid;grid-template-columns:minmax(220px,1fr) auto auto auto auto;gap:7px;align-items:center;padding:9px 11px;border-top:1px solid var(--line);background:#0c121b}
.bss-audio-selected{min-width:0;display:flex;flex-direction:column;gap:2px}.bss-audio-selected b,.bss-audio-selected small{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss-audio-selected b{font-size:10px}.bss-audio-selected small{font-size:8px;color:var(--muted)}
@media(max-width:820px){.bss-audio-preview-bar{grid-template-columns:1fr repeat(4,auto)}.bss-audio-selected{grid-column:1/-1}}
`;

/* v0.6.46 · batch library + spritesheet/layer editing */
STYLES += `
.bss-library-batchbar{position:sticky;top:0;z-index:7;display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin:-4px 0 12px;padding:9px 10px;border:1px solid #2d394d;border-radius:10px;background:#0d141ef2;backdrop-filter:blur(5px)}
.bss-library-batchbar .bss-divider{width:1px;height:25px;background:#344158;margin:0 2px}.bss-library-batchbar .bss-note{margin-left:auto}
.bss-card{position:relative}.bss-card.selected{border-color:#7188e5;box-shadow:0 0 0 1px #7188e555 inset}.bss-card-select{position:absolute;right:8px;top:8px;z-index:3;display:flex;align-items:center;gap:5px;padding:5px 7px;border:1px solid #3b4963;border-radius:7px;background:#0d131ed9;font-size:9px;color:#c5d0e3;cursor:pointer}.bss-card-select input{margin:0;width:14px;height:14px}
.bss-card-actions{flex-wrap:wrap}.bss-card-actions .bss-btn{padding:5px 7px;font-size:9px}
.bss-library-export-card{width:min(610px,92vw);max-height:min(720px,88vh);display:flex;flex-direction:column}.bss-library-group-list{padding:12px 15px;overflow:auto;display:grid;gap:6px}.bss-library-group-list .bss-check{padding:8px;border:1px solid #2e394d;border-radius:8px;background:#101722;margin:0}.bss-library-group-list small{margin-left:auto;color:var(--muted)}.bss-modal-actions{display:flex;justify-content:flex-end;gap:8px;padding:11px 14px;border-top:1px solid var(--line);background:#0e141d}
.bss-aura-sheet-grid{grid-column:1/-1;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;padding:9px;border:1px solid #31405a;border-radius:9px;background:#0e1622}.bss-aura-sheet-grid>.bss-aura-explain{grid-column:1/-1;margin:0}.bss-aura-explain.compact{padding:7px 8px}.bss-aura-settings-wide{grid-column:1/-1}.bss-aura-layer-head small{display:block;color:var(--muted);font-size:8px;margin-top:3px;line-height:1.35}.bss-aura-layer-head>div{flex:1;min-width:0}
.bss-boss-hud-editor{border-color:#39506e}.bss-boss-hud-editor>summary{background:#142031}
@media(max-width:980px){.bss-aura-sheet-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.bss-library-batchbar .bss-note{width:100%;margin-left:0}}
`;
STYLES += `
.bss-boss-hud-preview{margin:10px;padding:10px 12px;border:1px solid #3c4d67;border-radius:9px;background:#0a0f17;box-shadow:inset 0 0 18px #0008}.bss-boss-hud-preview>b{display:block;font-size:11px;margin-bottom:6px}.bss-boss-hud-preview>small{display:block;margin-top:6px;color:var(--muted);font-size:8px}.bss-boss-hp-preview{height:11px;padding:2px;border-radius:3px;background:#020407}.bss-boss-hp-preview>i{display:block;height:100%;border-radius:2px;background:#55d67a}.bss-boss-shield-preview{display:flex;gap:3px;margin-top:5px}.bss-boss-shield-preview>i{flex:1;height:7px;min-width:3px;border:1px solid #4b8db5;background:#5bc2ff;box-shadow:0 0 4px #4ab5ff66}

.bss-boss-hud-preview{background:transparent!important;border:0!important;padding:10px 18px 14px!important;position:relative}.bss-boss-hud-preview>b{display:block;text-align:center;font-size:15px;text-shadow:1px 1px 0 #000;margin-bottom:2px}.bss-boss-hp-preview{height:14px!important;border:2px solid #d9d9df!important;clip-path:polygon(2% 0,98% 0,100% 50%,98% 100%,2% 100%,0 50%);background:#25162b!important;padding:3px 10px!important}.bss-boss-hp-preview>i{display:block;height:4px!important;background:linear-gradient(90deg,#4ed67a,#35bb5c)!important}.bss-boss-shield-preview{display:flex!important;width:192px!important;max-width:70%;height:6px!important;margin:3px auto 0!important;gap:1px!important}.bss-boss-shield-preview i{height:6px!important;flex:1!important;transform:skewX(-28deg);border:1px solid #ff91b6!important;background:#e73e79!important}
`;

STYLES += `
/* v0.6.49 · native boss attributes, scalable shields, fade-safe HUD */
.bss-boss-mechanics-editor,.bss-boss-dbk-editor{border-color:#465171}.bss-boss-mechanics-editor>summary,.bss-boss-dbk-editor>summary{background:#141b2a}
.bss-boss-residual-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:9px}.bss-boss-residual-grid>.bss-field{margin:0!important}
.bss-dbk-immunities{padding:8px 10px 12px;display:grid;gap:9px}.bss-dbk-immunity-group{border:1px solid #2c3850;border-radius:9px;background:#0e151f;padding:8px}.bss-dbk-immunity-group>b{display:block;font-size:10px;color:#dce6fa;margin:0 0 7px}
.bss-dbk-immunity-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.bss-dbk-immunity{display:flex;align-items:center;gap:7px;border:1px solid #2d394d;border-radius:7px;background:#111925;padding:7px 8px;cursor:pointer;min-width:0}.bss-dbk-immunity:hover{border-color:#53698f;background:#182235}.bss-dbk-immunity input{margin:0;flex:none}.bss-dbk-immunity span{display:flex;align-items:baseline;gap:5px;min-width:0}.bss-dbk-immunity strong{font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss-dbk-immunity small{font-size:7px;color:#8190aa}
.bss-optiongroup code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;color:#bad1ff}
@media(max-width:900px){.bss-boss-residual-grid,.bss-dbk-immunity-grid{grid-template-columns:1fr}}
`;

STYLES += `
/* v0.6.52 · Blueprint subsection navigation */
.bss-inspector-subnav{position:sticky;top:38px;z-index:11;display:flex;gap:5px;overflow-x:auto;padding:6px 8px;border-bottom:1px solid var(--line);background:#0c121cf2;backdrop-filter:blur(5px);scrollbar-width:thin}
.bss-subjump{flex:none;border:1px solid #34425a;border-radius:999px;background:#111a27;color:#adbad0;padding:5px 8px;font:inherit;font-size:8px;cursor:pointer;white-space:nowrap}.bss-subjump:hover{border-color:#60769d;color:#e7eefb;background:#19253a}.bss-subjump-empty{font-size:8px;color:var(--muted);padding:4px 2px}
.bss-boss-residual-grid .bss-check.compact{margin-top:6px;padding:5px 6px;background:#0b121b;border:1px solid #263248;border-radius:6px}
`;

STYLES += `
/* v0.6.52 · Aura preview keeps pixel assets crisp and uses the browser's true
   additive compositor when available, closer to RGSS blend_type = 1. */
.bss-aura-runtime-preview img,
.bss-aura-live-preview img,
.bss-aura-particle,
.bss-aura-outline-copy {
  image-rendering: pixelated;
  image-rendering: crisp-edges;
}


/* v0.6.52 · Boss Blueprint focused workspace */
.bss-editor.bss-boss-focus{grid-template-columns:minmax(145px,var(--left,180px)) 4px minmax(0,1fr)!important}
.bss-editor.bss-boss-focus>.bss-stagewrap,.bss-editor.bss-boss-focus>.bss-resizer[data-resize="right"]{display:none!important}
.bss-editor.bss-boss-focus>.bss-inspector{grid-column:3;border-left:1px solid var(--line);min-width:0;background:#0e131b}
.bss-editor.bss-boss-focus .bss-inspector-inner{padding:10px 14px 24px;max-width:1180px;width:100%;margin:0 auto}
.bss-editor.bss-boss-focus .bss-inspector-jumpbar{justify-content:flex-start}
.bss-boss-workspace{border:0;background:transparent;overflow:visible;margin:0}
.bss-boss-workspace>.bss-panel-body{padding:0}
.bss-boss-workspace-head{display:flex;align-items:center;justify-content:space-between;gap:18px;padding:15px 16px;border:1px solid #303b51;border-radius:12px;background:linear-gradient(135deg,#151d2b,#111722)}
.bss-boss-workspace-head h2{font-size:18px;margin:3px 0 5px}.bss-boss-workspace-head p{margin:0;color:var(--muted);font-size:10px;max-width:720px}.bss-boss-kicker{font-size:9px;letter-spacing:.15em;color:#8fa7ff}
.bss-boss-master{display:flex;align-items:center;gap:9px;min-width:130px;padding:9px 11px;border:1px solid #3a4863;border-radius:10px;background:#0e1420;cursor:pointer}.bss-boss-master input{width:18px;height:18px}.bss-boss-master b,.bss-boss-master small{display:block}.bss-boss-master small{font-size:8px;color:var(--muted)}
.bss-boss-statusline{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0}.bss-boss-statusline span{padding:4px 7px;border:1px solid #2c3850;border-radius:999px;background:#101722;color:#b9c5d9;font-size:9px}
.bss-boss-shortcuts{display:flex;gap:7px;align-items:center;margin:8px 0 10px}
.bss-boss-cardgrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;align-items:start}.bss-boss-card{margin:0!important;border-color:#303b50;background:#111720}.bss-boss-card>summary{display:flex!important;align-items:center;gap:8px;padding:10px 12px!important;background:#151d29!important;font-weight:700;cursor:pointer}.bss-boss-card>summary>span{display:grid;place-items:center;width:24px;height:20px;border-radius:6px;background:#202a3d;color:#8fa7ff;font-size:8px}.bss-boss-cardbody{padding:10px 11px}.bss-boss-cardbody>.bss-field:last-child{margin-bottom:0}
.bss-boss-two{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.bss-boss-three{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.bss-boss-two>.bss-field,.bss-boss-three>.bss-field{margin-bottom:7px}.bss-boss-switch{padding:8px;border:1px solid #2b374d;border-radius:8px;background:#0d141e}.bss-boss-switch span{display:block}.bss-boss-switch b,.bss-boss-switch small{display:block}.bss-boss-switch small{color:var(--muted);font-size:8px;margin-top:2px}
.bss-boss-stats-clean{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px;padding:0!important;margin:0!important}.bss-boss-stats-clean .bss-boss-stat{margin:0!important}
.bss-boss-immunity-help,.bss-boss-capture-note{padding:8px 9px;border:1px solid #33425a;border-radius:8px;background:#0f1723;color:#aebbd0;font-size:9px;line-height:1.45;margin:7px 0}.bss-boss-capture-note b,.bss-boss-capture-note span{display:block}.bss-boss-capture-note span{margin-top:3px;color:var(--muted)}.bss-boss-capture-note.disabled{opacity:.55}
.bss-boss-immunity-groups{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px}.bss-boss-immunity-card{padding:7px;border:1px solid #29364b;border-radius:8px;background:#0d131d}.bss-boss-immunity-card>b{display:block;margin:0 0 6px;color:#b9c7df;font-size:9px}.bss-boss-immunity-card .bss-dbk-immunity-grid{grid-template-columns:1fr!important;gap:4px}.bss-boss-immunity-card .bss-dbk-immunity{padding:5px!important;margin:0!important}
.bss-boss-inline-checks{display:flex;gap:14px;align-items:center;padding:6px 0 9px;color:#cbd5e6;font-size:10px}.bss-boss-inline-checks label{display:flex;gap:5px;align-items:center}
.bss-boss-hud-preview{display:none!important}
@media(max-width:1050px){.bss-boss-cardgrid{grid-template-columns:1fr}.bss-boss-immunity-groups{grid-template-columns:1fr 1fr}.bss-boss-stats-clean{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:820px){.bss-editor.bss-boss-focus{grid-template-columns:125px 3px minmax(0,1fr)!important}.bss-boss-two,.bss-boss-three{grid-template-columns:1fr}.bss-boss-immunity-groups{grid-template-columns:1fr}.bss-boss-workspace-head{align-items:flex-start;flex-direction:column}.bss-boss-stats-clean{grid-template-columns:repeat(2,minmax(0,1fr))}}
`;

STYLES += `
/* v0.6.53 · one clean full-width workspace for every Blueprint section */
.bss-editor.bss-blueprint-focus{height:100%;min-height:0;display:grid!important;grid-template-columns:230px minmax(0,1fr)!important;grid-template-rows:minmax(0,1fr)!important;overflow:hidden;background:#0b1017}
.bss-blueprint-focus>.bss-side,.bss-blueprint-focus>.bss-resizer,.bss-blueprint-focus>.bss-stagewrap{display:none!important}
.bss-blueprint-rail{min-width:0;min-height:0;border-right:1px solid var(--line);background:#0f151e;display:flex;flex-direction:column;overflow:hidden}
.bss-blueprint-railhead{flex:none;padding:10px;border-bottom:1px solid var(--line);display:grid;gap:9px}.bss-blueprint-railhead>div b,.bss-blueprint-railhead>div small{display:block}.bss-blueprint-railhead>div b{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss-blueprint-railhead>div small{font-size:8px;color:var(--muted);margin-top:3px}
.bss-blueprint-navlist{padding:7px;display:grid;gap:5px;overflow:auto}.bss-blueprint-nav{appearance:none;border:1px solid transparent;background:transparent;color:#aeb9ca;border-radius:9px;padding:8px;text-align:left;display:grid;grid-template-columns:26px minmax(0,1fr);column-gap:7px;cursor:pointer}.bss-blueprint-nav>span{grid-row:1/3;display:grid;place-items:center;width:24px;height:24px;border-radius:6px;background:#182130;color:#7587a4;font-size:8px}.bss-blueprint-nav>b{font-size:10px;color:#d5deed}.bss-blueprint-nav>small{font-size:7px;color:#6f7d92;line-height:1.25;margin-top:2px}.bss-blueprint-nav:hover{background:#141d2a;border-color:#29374d}.bss-blueprint-nav.active{background:#18243a;border-color:#4865a2}.bss-blueprint-nav.active>span{background:var(--accent);color:#fff}.bss-blueprint-nav.active>b{color:#fff}.bss-blueprint-nav.active>small{color:#aebfe0}
.bss-editor.bss-blueprint-focus>.bss-inspector.bss-blueprint-main{grid-column:2!important;grid-row:1!important;min-width:0;min-height:0;border:0!important;background:#0d121a;overflow:auto;display:block}
.bss-blueprint-head{position:sticky;top:0;z-index:30;min-height:70px;display:flex;align-items:center;justify-content:space-between;gap:18px;padding:10px 16px;border-bottom:1px solid var(--line);background:#0d131df5;backdrop-filter:blur(7px)}.bss-blueprint-head>div:first-child>span{font-size:8px;letter-spacing:.16em;color:#7e93bb}.bss-blueprint-head h2{font-size:17px;margin:2px 0}.bss-blueprint-head p{font-size:9px;color:var(--muted);margin:0}.bss-blueprint-head-actions{display:flex;align-items:center;justify-content:flex-end;gap:9px;flex-wrap:wrap}.bss-blueprint-head-actions>.bss-note{max-width:300px;text-align:right}
.bss-blueprint-subnav{top:70px!important;z-index:25!important;padding:7px 16px!important;background:#101722f4!important}.bss-blueprint-content{width:min(1180px,100%);margin:0 auto;padding:12px 16px 30px!important}.bss-blueprint-content>.bss-panel{margin:0;border:0;background:transparent;overflow:visible}.bss-blueprint-content>.bss-panel>.bss-panel-head{margin-bottom:9px;border:1px solid #303b50;border-radius:10px;background:#131b27}.bss-blueprint-content .bss-optiongroup{border-color:#303b50;background:#111720;border-radius:10px;overflow:hidden;margin-bottom:9px}.bss-blueprint-content .bss-optiongroup>summary{background:#151d29;padding:10px 12px;font-weight:700}.bss-blueprint-content .bss-field{max-width:none}.bss-blueprint-content .bss-teamrow{grid-template-columns:minmax(220px,1fr) 100px 42px 42px;gap:7px;padding:7px 8px;border:1px solid #283449;border-radius:8px;background:#101720;margin-bottom:6px}.bss-blueprint-content .bss-teamrow .bss-specbtn{justify-content:flex-start}.bss-blueprint-focus .bss-boss-cardgrid{grid-template-columns:repeat(2,minmax(0,1fr))}.bss-blueprint-focus .bss-boss-workspace-head{margin-top:0}
@media(max-width:980px){.bss-editor.bss-blueprint-focus{grid-template-columns:185px minmax(0,1fr)!important}.bss-blueprint-nav>small{display:none}.bss-blueprint-nav{grid-template-rows:1fr}.bss-blueprint-nav>span{grid-row:auto}.bss-blueprint-focus .bss-boss-cardgrid{grid-template-columns:1fr}.bss-blueprint-head{align-items:flex-start;flex-direction:column}.bss-blueprint-head-actions{width:100%;justify-content:space-between}.bss-blueprint-subnav{top:104px!important}}
@media(max-width:720px){.bss-editor.bss-blueprint-focus{grid-template-columns:130px minmax(0,1fr)!important}.bss-blueprint-nav{grid-template-columns:1fr}.bss-blueprint-nav>span{display:none}.bss-blueprint-content{padding-left:9px!important;padding-right:9px!important}.bss-blueprint-content .bss-teamrow{grid-template-columns:minmax(150px,1fr) 72px 36px 36px}.bss-blueprint-head-actions>.bss-note{display:none}}
`;

STYLES += `
.bss-mini-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(110px,1fr));gap:7px;margin:7px 0}.bss-mini-grid .bss-mini-field{min-width:0}.bss-mini-grid .bss-select{width:100%;min-width:0}
`;

STYLES += `
/* v0.6.86 · EBDX Studio */
.bss-ebdx-studio-screen{height:100%;min-height:0;display:flex;flex-direction:column;background:#0b1017}.bss-ebdx-workspace{flex:1;min-height:0;display:grid;grid-template-columns:230px minmax(0,1fr);overflow:hidden}.bss-ebdx-sidebar{min-height:0;overflow:auto;border-right:1px solid var(--line);padding:10px;background:#0f151e}.bss-ebdx-sidebar h3{margin:8px 0 6px;font-size:10px;color:#cbd7e8}.bss-ebdx-custom,.bss-ebdx-preset{width:100%;border:1px solid #2a3549;background:#111925;color:#d4deec;border-radius:8px;padding:7px 8px;margin:0 0 5px;text-align:left;cursor:pointer}.bss-ebdx-custom b,.bss-ebdx-custom small,.bss-ebdx-preset b,.bss-ebdx-preset small{display:block}.bss-ebdx-custom small,.bss-ebdx-preset small{font-size:7px;color:#76869d;margin-top:2px}.bss-ebdx-custom:hover,.bss-ebdx-preset:hover{border-color:#465d86;background:#151f2e}.bss-ebdx-custom.active{border-color:#5f84dc;background:#192a49}.bss-ebdx-preset-list{display:grid;gap:1px}.bss-ebdx-main{min-width:0;min-height:0;overflow:auto;padding:12px 14px 32px}.bss-ebdx-head{display:grid;grid-template-columns:minmax(220px,1fr) minmax(300px,46%);gap:12px;align-items:stretch;margin-bottom:10px}.bss-ebdx-head>div:first-child{display:flex;flex-direction:column;justify-content:center;gap:5px}.bss-ebdx-head small{color:var(--muted);font-size:8px}.bss-ebdx-name{font-size:16px;font-weight:700}.bss-ebdx-preview{position:relative;min-height:150px;border:1px solid #33415a;border-radius:10px;overflow:hidden;background:linear-gradient(#101822,#090e14)}.bss-ebdx-preview img{width:100%;height:100%;min-height:150px;object-fit:cover;image-rendering:pixelated}.bss-ebdx-preview span{position:absolute;left:8px;bottom:7px;padding:3px 6px;border-radius:6px;background:#05080dbf;color:#dce7f8;font-size:8px}.bss-ebdx-section-head{display:flex;gap:10px;align-items:center;justify-content:space-between}.bss-ebdx-section-head h3{margin:0}.bss-ebdx-section-head p{margin:3px 0 0}.bss-ebdx-layer{border:1px solid #2c394f;border-radius:9px;background:#0f1620;padding:9px;margin:7px 0}.bss-ebdx-layer>header{display:flex;align-items:center;justify-content:space-between;margin-bottom:7px}.bss-ebdx-layer-flags{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:7px 0}.bss-ebdx-layer-flags .bss-check{margin:0}.bss-ebdx-json{width:100%;min-height:260px;resize:vertical;font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:9px;line-height:1.45;white-space:pre}.bss-ebdx-empty{min-height:260px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:7px;text-align:center}.bss-ebdx-empty span{max-width:520px;color:var(--muted)}
@media(max-width:900px){.bss-ebdx-workspace{grid-template-columns:170px minmax(0,1fr)}.bss-ebdx-head{grid-template-columns:1fr}.bss-ebdx-preview{min-height:120px}}
`;
STYLES += `
/* v0.6.86 · beginner-friendly EBDX Studio */
.bss-ebdx-preset.active{outline:2px solid currentColor;transform:translateY(-1px)}
.bss-ebdx-readonly-title{display:block;font-size:20px;margin-bottom:4px}
.bss-ebdx-friendly-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:10px;margin:12px 0}
.bss-ebdx-friendly-toggle{display:flex;gap:10px;align-items:flex-start;padding:10px;border:1px solid rgba(127,127,127,.25);border-radius:10px}
.bss-ebdx-friendly-toggle span{display:flex;flex-direction:column;gap:3px}.bss-ebdx-friendly-toggle small{opacity:.72;line-height:1.25}
.bss-ebdx-main details.bss-panel>summary{cursor:pointer;padding:6px 0}
`;

STYLES += `
/* v0.6.86 · reconstructed EBDX preview */
.bss-ebdx-preview{aspect-ratio:384/308;min-height:0;background:#080d13;display:grid;place-items:center}
.bss-ebdx-preview-canvas{display:block;width:100%;height:100%;object-fit:contain;image-rendering:pixelated;cursor:crosshair;background:#080d13}
.bss-ebdx-preview>span{pointer-events:none}
`;

// BSS 0.7.4 visual map metadata / scene editor
STYLES += `
.bss-mapmeta-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:10px;margin-top:12px}
.bss-mapmeta-card{display:flex;gap:10px;padding:9px;border:1px solid var(--line,#334253);border-radius:10px;background:rgba(14,20,28,.55)}
.bss-mapmeta-thumb{width:104px;height:78px;flex:0 0 104px;background:#101822;border-radius:7px;overflow:hidden;position:relative}
.bss-mapmeta-thumb img{width:100%;height:100%;object-fit:cover;image-rendering:pixelated}
.bss-mapmeta-thumb span{position:absolute;left:4px;bottom:3px;font-size:10px;background:#000a;padding:2px 4px;border-radius:3px}
.bss-mapmeta-main{min-width:0;flex:1}.bss-mapmeta-main small{display:block;opacity:.7;margin:2px 0 7px}
.bss072-scene-toolbar{display:flex;align-items:center;gap:12px;padding:8px 10px;margin:0 0 10px;border:1px solid var(--line,#334253);border-radius:8px;background:rgba(20,30,42,.75)}
.bss072-scene-toolbar label{display:flex;align-items:center;gap:6px}.bss072-scene-toolbar .bss-select{width:74px}
.bss-ebdx-preview-canvas{cursor:crosshair;image-rendering:pixelated}

/* BSS 0.7.8 EBDX authoring */
.bss076-camera .bss-mini-grid{grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:8px}.bss076-map-json textarea,.bss076-scene-meta textarea{min-height:140px;font-family:ui-monospace,Consolas,monospace}.bss076-libraries{margin-top:12px}.bss076-scene-meta{border-left:3px solid var(--accent,#5aa7ff)}

`;

STYLES += "\n\n/* BSS 0.7.8 · EBDX canvas-first authoring */\n.bss078-ebdx-flow{display:grid;grid-template-columns:repeat(4,minmax(130px,1fr));gap:8px;margin:0 0 10px}.bss078-ebdx-flow button{display:flex;flex-direction:column;align-items:flex-start;gap:2px;padding:9px 11px;border:1px solid var(--border,#343641);border-radius:10px;background:var(--bg-secondary,#191b24);color:inherit;cursor:pointer}.bss078-ebdx-flow button:hover{border-color:var(--accent,#6ea8ff);background:var(--bg-tertiary,#222430)}.bss078-ebdx-flow small{opacity:.68}.bss078-ebdx-authoring{display:grid;grid-template-columns:minmax(430px,1.35fr) minmax(320px,.8fr);gap:12px;min-height:0;align-items:start}.bss078-ebdx-canvas-column{position:sticky;top:0;display:flex;flex-direction:column;gap:8px;min-width:0}.bss078-ebdx-canvas-title,.bss078-ebdx-safe-hint{display:flex;justify-content:space-between;gap:12px;align-items:center;padding:8px 10px;border:1px solid var(--border,#343641);border-radius:9px;background:var(--bg-secondary,#191b24)}.bss078-ebdx-canvas-title>div{display:flex;flex-direction:column}.bss078-ebdx-canvas-title small,.bss078-ebdx-safe-hint span{opacity:.68;font-size:11px}.bss078-ebdx-canvas-column .bss-ebdx-preview{width:100%;height:auto;min-height:420px;aspect-ratio:384/308;max-height:calc(100vh - 285px);background:#08090d}.bss078-ebdx-canvas-column .bss-ebdx-preview img{width:100%;height:100%;object-fit:contain;image-rendering:pixelated}.bss078-ebdx-inspector-column{display:flex;flex-direction:column;gap:10px;min-width:0;max-height:calc(100vh - 210px);overflow:auto;padding-right:4px}.bss078-ebdx-inspector-column>.bss-panel,.bss078-ebdx-inspector-column>details{margin:0}.bss-ebdx-studio-screen .bss-ebdx-workspace{grid-template-columns:240px minmax(0,1fr)}@media(max-width:1050px){.bss078-ebdx-authoring{grid-template-columns:1fr}.bss078-ebdx-canvas-column{position:relative}.bss078-ebdx-inspector-column{max-height:none}.bss078-ebdx-flow{grid-template-columns:repeat(2,1fr)}}\n";

// BSS v0.7.9 · EBDX Studio library / Intro Studio / centralized config
STYLES += `
.bss079-ebdx-studio{height:100%;min-height:0;display:flex;flex-direction:column;background:var(--bss-bg,#10151d)}
.bss079-ebdx-header{flex:0 0 auto}
.bss079-ebdx-tabs{display:flex;gap:6px;padding:8px 12px;border-bottom:1px solid rgba(255,255,255,.09);background:rgba(8,12,18,.92)}
.bss079-ebdx-tabs button{border:0;border-radius:8px;padding:9px 18px;background:transparent;color:inherit;font-weight:700;cursor:pointer}
.bss079-ebdx-tabs button:hover{background:rgba(255,255,255,.06)}
.bss079-ebdx-tabs button.active{background:rgba(87,151,255,.18);box-shadow:inset 0 0 0 1px rgba(112,170,255,.45)}
.bss079-ebdx-content{flex:1;min-height:0;overflow:auto;padding:12px}
.bss079-background-page{height:100%;min-height:0;display:flex;flex-direction:column;gap:10px}
.bss079-background-toolbar{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}
.bss079-library-chips{display:flex;gap:6px;flex-wrap:wrap}
.bss079-chip{border:1px solid rgba(255,255,255,.12);background:rgba(255,255,255,.035);color:inherit;border-radius:999px;padding:6px 11px;cursor:pointer}
.bss079-chip.active{border-color:rgba(103,167,255,.7);background:rgba(86,151,255,.18)}
.bss079-scene-workspace{flex:1;min-height:0;display:grid;grid-template-columns:minmax(440px,1fr) minmax(350px,430px);gap:12px}
.bss079-scene-browser{min-height:0;border:1px solid rgba(255,255,255,.08);border-radius:10px;background:rgba(255,255,255,.018);overflow:hidden}
.bss079-scene-grid-scroll{height:100%;overflow:auto;padding:10px;scrollbar-gutter:stable}
.bss079-scene-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:10px;align-content:start}
.bss079-scene-card{display:flex;min-width:0;flex-direction:column;gap:6px;text-align:left;padding:8px;border:1px solid rgba(255,255,255,.1);border-radius:10px;background:rgba(255,255,255,.035);color:inherit;cursor:pointer;overflow:hidden}
.bss079-scene-card:hover{border-color:rgba(117,177,255,.55);background:rgba(117,177,255,.07)}
.bss079-scene-card.active{border-color:rgba(117,177,255,.9);box-shadow:0 0 0 2px rgba(75,143,255,.18)}
.bss079-scene-card>b{font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bss079-scene-card>small{font-size:10px;line-height:1.3;opacity:.72;min-height:26px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.bss079-card-preview{position:relative;aspect-ratio:384/308;border-radius:7px;overflow:hidden;background:#080b10;border:1px solid rgba(255,255,255,.08)}
.bss079-card-preview canvas{display:block;width:100%;height:100%;image-rendering:pixelated;pointer-events:none}
.bss079-card-preview>span{position:absolute;right:5px;bottom:5px;padding:2px 5px;border-radius:4px;background:rgba(0,0,0,.65);font:9px monospace}
.bss079-scene-inspector{min-height:0;overflow:auto;padding-right:3px;display:flex;flex-direction:column;gap:10px}
.bss079-inspector-sticky{position:sticky;top:0;z-index:4;background:linear-gradient(var(--bss-bg,#10151d) 88%,transparent);padding-bottom:8px}
.bss079-inspector-title{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:8px}
.bss079-inspector-title>div{min-width:0;display:flex;flex-direction:column;gap:3px}
.bss079-main-preview{aspect-ratio:384/308;min-height:250px;max-height:43vh;overflow:hidden;border-radius:10px;background:#080b10}
.bss079-main-preview canvas,.bss079-main-preview img{width:100%;height:100%;object-fit:contain;image-rendering:pixelated}
.bss079-toggle-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px}
.bss079-config-page,.bss079-intro-page{display:flex;flex-direction:column;gap:12px;max-width:1280px;margin:0 auto}
.bss079-config-block{border:1px solid rgba(255,255,255,.09);border-radius:11px;background:rgba(255,255,255,.025);padding:12px}
.bss079-section-head{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:10px}
.bss079-section-head>div{display:flex;flex-direction:column;gap:2px}.bss079-section-head small{opacity:.68}
.bss079-preset-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px;margin-bottom:12px}
.bss079-mini-card{display:flex;flex-direction:column;align-items:flex-start;gap:3px;text-align:left;padding:9px;border-radius:8px;border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.035);color:inherit;cursor:pointer}
.bss079-mini-card.active{border-color:rgba(103,167,255,.75);background:rgba(103,167,255,.14)}.bss079-mini-card small{opacity:.66;line-height:1.3}
.bss079-camera-grid{grid-template-columns:repeat(auto-fill,minmax(170px,1fr))}
.bss079-map-assign{display:grid;grid-template-columns:minmax(220px,1.4fr) 130px minmax(220px,1.2fr) auto;gap:8px;align-items:end}
.bss079-map-list{display:flex;flex-direction:column;gap:6px;margin-top:10px}
.bss079-map-row{display:grid;grid-template-columns:minmax(160px,1fr) minmax(220px,1.4fr) auto;gap:8px;align-items:center;padding:7px 8px;border:1px solid rgba(255,255,255,.08);border-radius:8px;background:rgba(0,0,0,.08)}
.bss079-map-row>div{display:flex;flex-direction:column}.bss079-map-row small{opacity:.62}
.bss079-library-config{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:8px}
.bss079-json-details{margin-top:10px}.bss079-json-details textarea{min-height:180px;font-family:monospace}
.bss079-intro-grid{grid-template-columns:repeat(auto-fit,minmax(180px,1fr))}
.bss079-intro-art{height:82px;border-radius:7px;display:grid;place-items:center;background:radial-gradient(circle at 50% 55%,rgba(112,174,255,.24),rgba(10,15,24,.9));overflow:hidden}
.bss079-intro-art span{font-size:30px;font-weight:900;letter-spacing:2px;opacity:.9}
.bss079-wide-check{padding:9px;border:1px solid rgba(255,255,255,.08);border-radius:8px;margin-bottom:10px}
@media(max-width:1050px){.bss079-scene-workspace{grid-template-columns:1fr}.bss079-scene-inspector{overflow:visible}.bss079-inspector-sticky{position:static}.bss079-main-preview{max-height:none}.bss079-map-assign{grid-template-columns:1fr 120px}.bss079-map-assign button{grid-column:1/-1}.bss079-toggle-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
`;
STYLES += `
.bss079-quick-guide{display:flex;gap:10px;align-items:center;padding:8px 10px;border:1px solid rgba(93,155,255,.24);border-radius:9px;background:rgba(79,142,255,.07)}
.bss079-quick-guide>b{white-space:nowrap}.bss079-quick-guide>span{font-size:10px;opacity:.75;line-height:1.35}
`;

// BSS v0.8.4 camera-context editor
(function(){try{const css=`
.bss084-camera-contexts{margin-top:18px;border-top:1px solid rgba(255,255,255,.08);padding-top:14px}
.bss084-camera-context{display:grid;grid-template-columns:minmax(180px,1.2fr) minmax(170px,1fr) minmax(130px,.7fr);gap:10px;align-items:end;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.055)}
.bss084-camera-context .bss-check{align-self:center;margin:0}.bss084-camera-context .bss-mini-field{margin:0}
@media(max-width:900px){.bss084-camera-context{grid-template-columns:1fr}}
`;if(typeof document!=="undefined"){let s=document.getElementById("bss084-context-style");if(!s){s=document.createElement("style");s.id="bss084-context-style";s.textContent=css;document.head.appendChild(s);}}}catch(_){}})();

// BSS v0.8.7 - separate EBDX Scene Editor workspace
STYLES += `
.bss087-scene-browser-full{min-height:0;height:calc(100vh - 250px)}
.bss087-scene-browser-full .bss079-scene-grid-scroll{height:100%;max-height:none}
.bss087-scene-editor{height:100%;display:flex;flex-direction:column;min-height:0;background:var(--bss-bg,#16191f)}
.bss087-scene-editor-head{flex:0 0 auto}
.bss087-scene-editor-workspace{flex:1 1 auto;min-height:0;display:grid;grid-template-columns:minmax(520px,1.65fr) minmax(360px,.85fr);gap:12px;padding:12px;overflow:hidden}
.bss087-scene-canvas-column,.bss087-scene-inspector-column{min-height:0;overflow:auto}
.bss087-scene-canvas-column{display:flex;flex-direction:column;gap:12px}
.bss087-scene-inspector-column>.bss079-scene-inspector{width:auto;max-width:none;position:static;overflow:visible}
.bss087-scene-inspector-column .bss079-inspector-sticky{position:static}
.bss087-main-preview{width:100%;min-height:500px;display:flex;align-items:center;justify-content:center;background:#0d1015;border:1px solid rgba(255,255,255,.1);border-radius:10px;overflow:hidden}
.bss087-main-preview canvas{width:min(100%,760px)!important;height:auto!important;image-rendering:pixelated}
.bss087-scene-canvas-head{display:flex;justify-content:space-between;gap:12px;align-items:flex-end}.bss087-scene-canvas-head small{opacity:.7}
.bss087-asset-browser{min-height:240px}.bss087-asset-browser .bss079-section-head{gap:10px;align-items:center}.bss087-asset-browser .bss-search{max-width:280px}
.bss087-asset-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;max-height:330px;overflow:auto;padding:4px}
.bss087-asset-card{min-width:0;background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:7px;color:inherit;text-align:left;cursor:pointer;display:flex;flex-direction:column;gap:5px}
.bss087-asset-card:hover{border-color:rgba(255,255,255,.25);background:rgba(255,255,255,.07)}
.bss087-asset-thumb{height:78px;display:flex;align-items:center;justify-content:center;background:#101319;border-radius:5px;overflow:hidden}.bss087-asset-thumb img{max-width:100%;max-height:100%;image-rendering:pixelated}
.bss087-asset-card b{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss087-asset-card small{opacity:.55;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bss087-camera-profiles,.bss087-context-strengths{margin:12px 0;padding:10px;border:1px solid rgba(255,255,255,.08);border-radius:8px;background:rgba(255,255,255,.025)}
@media(max-width:1100px){.bss087-scene-editor-workspace{grid-template-columns:1fr}.bss087-main-preview{min-height:380px}}
`;
STYLES += `.bss087-profile-card-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px}.bss087-profile-card-grid .bss079-mini-card{min-height:72px}`;

// BSS v0.8.8 - unified EBDX Background Composer
STYLES += `
.bss088-composer{height:calc(100vh - 170px);min-height:620px;display:grid;grid-template-columns:250px minmax(520px,1fr) minmax(360px,430px);gap:10px;overflow:hidden}
.bss088-library,.bss088-canvas-zone,.bss088-inspector{min-height:0;border:1px solid rgba(255,255,255,.08);border-radius:11px;background:rgba(255,255,255,.018)}
.bss088-library{display:flex;flex-direction:column;overflow:hidden}.bss088-pane-head{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:10px;border-bottom:1px solid rgba(255,255,255,.07)}.bss088-pane-head>div{display:flex;flex-direction:column;gap:2px;min-width:0}.bss088-pane-head small{font-size:9px;opacity:.62}
.bss088-library-chips{padding:8px;border-bottom:1px solid rgba(255,255,255,.055);overflow-x:auto;flex-wrap:nowrap}.bss088-library-chips .bss079-chip{white-space:nowrap;font-size:9px;padding:5px 8px}
.bss088-library-scroll{flex:1;min-height:0;overflow:auto;padding:8px}.bss088-new-library{margin:8px}
.bss088-scene-list{display:flex;flex-direction:column;gap:7px}.bss079-scene-card.bss088-scene-card{display:grid;grid-template-columns:86px minmax(0,1fr);gap:8px;align-items:center;padding:6px;min-height:76px}.bss088-scene-card .bss079-card-preview{aspect-ratio:384/308;height:64px}.bss088-scene-card-copy{min-width:0;display:flex;flex-direction:column;gap:3px}.bss088-scene-card-copy>b{font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-scene-card-copy>small{font-size:8px;line-height:1.25;opacity:.62;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.bss088-canvas-zone{display:flex;flex-direction:column;gap:8px;overflow:auto;padding:10px}.bss088-canvas-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px}.bss088-canvas-toolbar>div:first-child{display:flex;flex-direction:column;min-width:0}.bss088-canvas-toolbar>div:first-child>b{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-canvas-toolbar small{opacity:.62;font-size:9px}.bss088-canvas-actions{display:flex;align-items:center;gap:7px;flex-wrap:wrap;justify-content:flex-end}.bss088-canvas-actions>label{display:flex;align-items:center;gap:5px;font-size:9px;opacity:.85}.bss088-canvas-actions .bss-select{width:auto;min-width:74px}
.bss088-canvas-help{display:flex;gap:7px;flex-wrap:wrap}.bss088-canvas-help span{font-size:8px;padding:4px 7px;border:1px solid rgba(255,255,255,.07);border-radius:999px;background:rgba(255,255,255,.025);opacity:.72}
.bss088-main-preview{min-height:430px;max-height:none;display:flex;align-items:center;justify-content:center;position:relative;background:#090c11;border:1px solid rgba(255,255,255,.11)}.bss088-main-preview canvas{width:min(100%,820px)!important;height:auto!important;image-rendering:pixelated;cursor:crosshair}.bss088-canvas-caption{position:absolute;left:8px;bottom:8px;padding:3px 6px;border-radius:5px;background:rgba(0,0,0,.62);font:8px monospace;pointer-events:none}
.bss088-layer-stack{border:1px solid rgba(255,255,255,.07);border-radius:9px;background:rgba(0,0,0,.08);overflow:hidden}.bss088-layer-stack-head{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 9px;border-bottom:1px solid rgba(255,255,255,.06)}.bss088-layer-stack-head>div{display:flex;flex-direction:column}.bss088-layer-stack-head small{font-size:8px;opacity:.55}.bss088-layer-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:5px;padding:6px;max-height:170px;overflow:auto}.bss088-layer-row{display:grid;grid-template-columns:28px minmax(0,1fr) auto;gap:7px;align-items:center;text-align:left;border:1px solid rgba(255,255,255,.065);border-radius:7px;background:rgba(255,255,255,.025);color:inherit;padding:6px;cursor:pointer}.bss088-layer-row:hover{background:rgba(103,167,255,.07);border-color:rgba(103,167,255,.28)}.bss088-layer-row.active{background:rgba(103,167,255,.14);border-color:rgba(103,167,255,.65);box-shadow:inset 0 0 0 1px rgba(103,167,255,.15)}.bss088-layer-order{display:grid;place-items:center;height:28px;border-radius:6px;background:rgba(255,255,255,.055);font:9px monospace}.bss088-layer-main{min-width:0;display:flex;flex-direction:column}.bss088-layer-main b{font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-layer-main small{font-size:7px;opacity:.58;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-layer-kind{font-size:7px;opacity:.55}
.bss088-inspector{overflow:auto;padding:10px;display:flex;flex-direction:column;gap:9px}.bss088-readonly-banner,.bss088-scene-meta,.bss088-inspector-section,.bss088-json,.bss088-fine-controls{border:1px solid rgba(255,255,255,.075);border-radius:9px;background:rgba(255,255,255,.025)}.bss088-readonly-banner{display:flex;justify-content:space-between;align-items:center;gap:8px;padding:9px}.bss088-readonly-banner>div{display:flex;flex-direction:column;min-width:0}.bss088-readonly-banner b{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-readonly-banner small{font-size:8px;opacity:.62}.bss088-scene-meta{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding:9px}.bss088-meta-description{grid-column:1/-1}.bss088-scene-meta .bss-row{grid-column:1/-1}.bss088-scene-meta textarea{min-height:58px}
.bss088-context-head{display:flex;align-items:flex-start;justify-content:space-between;gap:8px;padding:4px 2px 1px}.bss088-context-head>div:first-child{display:flex;flex-direction:column;gap:2px;min-width:0}.bss088-context-head>div:first-child>span{font-size:7px;letter-spacing:.12em;color:#8eafff}.bss088-context-head b{font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss088-context-head small{font-size:8px;opacity:.58}
.bss088-layer-inspector{display:flex;flex-direction:column;gap:8px}.bss088-inspector-section{padding:9px}.bss088-section-title{display:flex;align-items:flex-start;justify-content:space-between;gap:8px;margin-bottom:8px}.bss088-section-title>div{display:flex;flex-direction:column;gap:2px}.bss088-section-title small{font-size:8px;opacity:.58;line-height:1.3}.bss088-current-behavior{font-size:7px;padding:3px 6px;border:1px solid rgba(103,167,255,.28);background:rgba(103,167,255,.09);border-radius:999px;white-space:nowrap}.bss088-transform-grid,.bss088-fine-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px}.bss088-nudge-pad{display:grid;grid-template-columns:repeat(5,1fr);gap:4px;margin-top:7px}.bss088-nudge-pad button{border:1px solid rgba(255,255,255,.08);border-radius:6px;background:rgba(255,255,255,.035);color:inherit;padding:5px 3px;font:inherit;font-size:8px;cursor:pointer}.bss088-nudge-pad button:hover{background:rgba(103,167,255,.1);border-color:rgba(103,167,255,.3)}
.bss088-behavior-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.bss088-behavior-card{display:flex;flex-direction:column;gap:2px;align-items:flex-start;text-align:left;padding:7px;border:1px solid rgba(255,255,255,.075);border-radius:7px;background:rgba(255,255,255,.025);color:inherit;cursor:pointer}.bss088-behavior-card:hover:not(:disabled){background:rgba(103,167,255,.08);border-color:rgba(103,167,255,.28)}.bss088-behavior-card.active{background:rgba(103,167,255,.15);border-color:rgba(103,167,255,.55)}.bss088-behavior-card:disabled{cursor:default;opacity:.72}.bss088-behavior-card b{font-size:9px}.bss088-behavior-card small{font-size:7px;line-height:1.25;opacity:.58}.bss088-behavior-tune{margin-top:7px}.bss088-behavior-tune small{display:block;font-size:7px;opacity:.52;margin-top:2px}
.bss088-switch-list{display:flex;flex-direction:column;gap:5px;margin-bottom:7px}.bss088-switch-list>label{display:flex;gap:7px;padding:7px;border:1px solid rgba(255,255,255,.06);border-radius:7px;background:rgba(0,0,0,.08)}.bss088-switch-list input{margin-top:2px}.bss088-switch-list span{display:flex;flex-direction:column}.bss088-switch-list b{font-size:9px}.bss088-switch-list small{font-size:7px;opacity:.55;line-height:1.3}.bss088-fine-controls>summary,.bss088-json>summary{cursor:pointer;padding:9px;font-weight:700}.bss088-fine-grid{padding:0 9px 9px}.bss088-fine-controls .bss-note{padding:0 9px 9px;margin:0}.bss088-json textarea{min-height:220px;margin:0 9px 8px;width:calc(100% - 18px);font-family:ui-monospace,SFMono-Regular,Consolas,monospace}.bss088-json>.bss-btn{margin:0 9px 9px}.bss088-inspector-empty{display:flex;flex-direction:column;gap:4px;padding:12px;border:1px dashed rgba(103,167,255,.25);border-radius:9px;background:rgba(103,167,255,.045)}.bss088-inspector-empty span{font-size:8px;opacity:.62;line-height:1.4}
.bss088-env-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5px}.bss088-env-toggle{display:flex;gap:6px;padding:7px;border:1px solid rgba(255,255,255,.065);border-radius:7px;background:rgba(0,0,0,.08)}.bss088-env-toggle.on{border-color:rgba(103,167,255,.35);background:rgba(103,167,255,.08)}.bss088-env-toggle input{margin-top:2px}.bss088-env-toggle span{display:flex;flex-direction:column}.bss088-env-toggle b{font-size:9px}.bss088-env-toggle small{font-size:7px;opacity:.52;line-height:1.25}
.bss088-asset-tray{border:1px solid rgba(255,255,255,.075);border-radius:9px;background:rgba(255,255,255,.018);padding:8px;min-height:190px}.bss088-asset-tray-head{display:flex;justify-content:space-between;align-items:center;gap:10px}.bss088-asset-tray-head>div{display:flex;flex-direction:column}.bss088-asset-tray-head small{font-size:8px;opacity:.58}.bss088-asset-tray-head .bss-search{max-width:260px}.bss088-asset-cats{display:flex;gap:4px;overflow-x:auto;padding:7px 0 5px}.bss088-asset-cats button,.bss088-quick-elements button{white-space:nowrap;border:1px solid rgba(255,255,255,.07);border-radius:999px;background:rgba(255,255,255,.025);color:inherit;padding:4px 7px;font:inherit;font-size:7px;cursor:pointer}.bss088-asset-cats button.active{border-color:rgba(103,167,255,.48);background:rgba(103,167,255,.12)}.bss088-quick-elements{display:flex;align-items:center;gap:4px;overflow-x:auto;padding:2px 0 6px}.bss088-quick-elements>span{font-size:7px;opacity:.5;white-space:nowrap}.bss088-quick-elements button:hover,.bss088-asset-cats button:hover{background:rgba(103,167,255,.09)}.bss088-asset-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(125px,1fr));gap:6px;max-height:255px;overflow:auto}.bss088-asset-grid .bss087-asset-card{padding:5px}.bss088-asset-grid .bss087-asset-thumb{height:62px}.bss088-asset-grid .bss087-asset-card b{font-size:8px}.bss088-asset-grid .bss087-asset-card small{font-size:7px}.bss088-readonly-hint{margin-top:8px;padding:8px;border:1px dashed rgba(255,255,255,.08);border-radius:7px;font-size:8px;opacity:.6}
@media(max-width:1280px){.bss088-composer{grid-template-columns:220px minmax(470px,1fr) 350px}.bss088-behavior-grid{grid-template-columns:1fr}.bss088-main-preview{min-height:360px}}
@media(max-width:1050px){.bss088-composer{height:auto;min-height:0;grid-template-columns:1fr;overflow:visible}.bss088-library{max-height:360px}.bss088-canvas-zone,.bss088-inspector{overflow:visible}.bss088-main-preview{min-height:320px}.bss079-ebdx-content{overflow:auto}.bss088-scene-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr))}}
`;
STYLES += `
.bss088-group-row .bss088-layer-order{font-size:13px}.bss088-mirror-check{align-self:end;min-height:34px;padding:7px;border:1px solid rgba(255,255,255,.06);border-radius:7px;background:rgba(0,0,0,.08)}
.bss088-learning-note{display:flex;flex-direction:column;gap:3px;padding:8px 9px;border:1px solid rgba(103,167,255,.18);border-radius:8px;background:rgba(103,167,255,.045)}.bss088-learning-note b{font-size:9px}.bss088-learning-note span{font-size:7px;line-height:1.4;opacity:.62}
`;

STYLES += `
.bss088-conflict-note{display:flex;flex-direction:column;gap:3px;margin-top:7px;padding:8px 9px;border:1px solid rgba(255,190,80,.28);border-radius:8px;background:rgba(255,190,80,.055)}.bss088-conflict-note b{font-size:9px}.bss088-conflict-note span{font-size:7px;line-height:1.4;opacity:.68}
`;

// BSS v0.8.9 - Background Composer workspace hierarchy
STYLES += `
.bss079-ebdx-content{position:relative}
.bss089-composer{height:calc(100vh - 170px);min-height:620px;display:grid;grid-template-columns:minmax(220px,260px) minmax(500px,1fr) minmax(360px,410px);gap:10px;overflow:hidden;position:relative}
.bss089-author-dock,.bss089-canvas-zone,.bss089-composer>.bss088-inspector{min-height:0;border:1px solid rgba(255,255,255,.08);border-radius:11px;background:rgba(255,255,255,.018)}
.bss089-author-dock{display:flex;flex-direction:column;overflow:hidden}.bss089-dock-tabs{display:grid;grid-template-columns:1fr 1fr;padding:6px;gap:5px;border-bottom:1px solid rgba(255,255,255,.07);background:rgba(0,0,0,.12)}.bss089-dock-tabs button{border:1px solid rgba(255,255,255,.07);border-radius:7px;background:rgba(255,255,255,.025);color:inherit;padding:8px 6px;font:inherit;font-size:9px;cursor:pointer}.bss089-dock-tabs button.active{background:rgba(103,167,255,.15);border-color:rgba(103,167,255,.55)}.bss089-dock-content{flex:1;min-height:0;overflow:hidden;display:flex;flex-direction:column}
.bss089-dock-content .bss088-layer-stack{height:100%;min-height:0;border:0;border-radius:0;background:transparent;display:flex;flex-direction:column}.bss089-dock-content .bss088-layer-stack-head{flex:0 0 auto;padding:9px}.bss089-dock-content .bss088-layer-stack-head .bss-row{gap:3px}.bss089-dock-content .bss088-layer-stack-head .bss-btn{padding:4px 5px;font-size:7px}.bss089-dock-content .bss088-layer-list{flex:1;min-height:0;max-height:none;display:flex;flex-direction:column;gap:4px;overflow:auto;padding:6px}.bss089-dock-content .bss088-layer-row{flex:0 0 auto;width:100%;min-height:43px;grid-template-columns:30px minmax(0,1fr) auto;padding:7px}.bss089-dock-content .bss088-layer-main b{font-size:9px}.bss089-dock-content .bss088-layer-main small{font-size:7px}
.bss089-elements{display:flex;flex-direction:column;min-height:0;height:100%}.bss089-element-search{padding:8px;border-bottom:1px solid rgba(255,255,255,.06)}.bss089-element-search .bss-search{width:100%;max-width:none}.bss089-element-cats{flex:0 0 auto;padding:6px;border-bottom:1px solid rgba(255,255,255,.05)}.bss089-quick-elements{display:flex;gap:4px;overflow-x:auto;padding:6px;border-bottom:1px solid rgba(255,255,255,.05)}.bss089-quick-elements button{white-space:nowrap;border:1px solid rgba(255,255,255,.07);border-radius:999px;background:rgba(255,255,255,.025);color:inherit;padding:4px 7px;font:inherit;font-size:7px;cursor:pointer}.bss089-element-list{flex:1;min-height:0;overflow:auto;padding:6px;display:flex;flex-direction:column;gap:5px}.bss089-element-row{display:grid;grid-template-columns:58px minmax(0,1fr) 20px;gap:7px;align-items:center;text-align:left;border:1px solid rgba(255,255,255,.07);border-radius:8px;background:rgba(255,255,255,.025);color:inherit;padding:5px;cursor:pointer}.bss089-element-row:hover{background:rgba(103,167,255,.09);border-color:rgba(103,167,255,.35)}.bss089-element-row .bss087-asset-thumb{width:58px;height:44px;border-radius:5px}.bss089-element-row>span:nth-child(2){min-width:0;display:flex;flex-direction:column}.bss089-element-row b{font-size:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss089-element-row small{font-size:7px;opacity:.55;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss089-element-row strong{font-size:15px;text-align:center;opacity:.65}.bss089-elements-empty{margin:10px;padding:12px;border:1px dashed rgba(255,255,255,.1);border-radius:8px;display:flex;flex-direction:column;gap:4px}.bss089-elements-empty span{font-size:8px;opacity:.6}
.bss089-canvas-zone{display:flex;flex-direction:column;gap:8px;overflow:hidden;padding:10px}.bss089-canvas-toolbar{display:flex;align-items:center;justify-content:space-between;gap:10px;flex:0 0 auto}.bss089-scene-title{display:flex;align-items:center;gap:8px;min-width:0}.bss089-scene-title>div{display:flex;flex-direction:column;min-width:0}.bss089-scene-title b{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss089-scene-title small{font-size:8px;opacity:.58}.bss089-canvas-actions{display:flex;align-items:center;justify-content:flex-end;gap:5px;flex-wrap:wrap}.bss089-canvas-actions>label{display:flex;align-items:center;gap:5px;font-size:8px;opacity:.8}.bss089-canvas-actions .bss-select{width:auto;min-width:65px}.bss089-history-btn:disabled{opacity:.32;cursor:default}.bss089-canvas-help{flex:0 0 auto}.bss089-main-preview{flex:1;min-height:360px;max-height:none;overflow:hidden}.bss089-main-preview canvas{max-height:100%;max-width:100%;object-fit:contain}
.bss089-composer>.bss088-inspector{overflow:auto;padding:10px}.bss089-composer>.bss088-inspector .bss088-scene-meta{grid-template-columns:1fr}.bss089-composer>.bss088-inspector .bss088-meta-description,.bss089-composer>.bss088-inspector .bss088-scene-meta .bss-row{grid-column:1}
.bss089-library-overlay{position:absolute;inset:0;z-index:90;display:flex}.bss089-library-shade{position:absolute;inset:0;border:0;background:rgba(2,5,9,.68);backdrop-filter:blur(2px);cursor:default}.bss089-library-drawer{position:relative;z-index:1;width:min(390px,92%);height:100%;display:flex;flex-direction:column;background:#10151d;border-right:1px solid rgba(255,255,255,.13);box-shadow:18px 0 38px rgba(0,0,0,.38)}.bss089-library-actions{display:flex;gap:6px;padding:8px;border-bottom:1px solid rgba(255,255,255,.055)}.bss089-library-list{flex:1;min-height:0;overflow:auto;padding:8px}.bss089-library-list .bss088-scene-list{gap:7px}.bss089-library-list .bss079-scene-card.bss088-scene-card{grid-template-columns:100px minmax(0,1fr);min-height:86px}.bss089-library-list .bss088-scene-card .bss079-card-preview{height:72px}
@media(max-width:1280px){.bss089-composer{grid-template-columns:210px minmax(450px,1fr) 340px}.bss089-dock-content .bss088-layer-kind{display:none}.bss089-main-preview{min-height:330px}.bss088-behavior-grid{grid-template-columns:1fr}}
@media(max-width:1020px){.bss089-composer{height:auto;min-height:0;grid-template-columns:220px minmax(430px,1fr);overflow:visible}.bss089-composer>.bss088-inspector{grid-column:1/-1;max-height:none}.bss089-author-dock{min-height:540px}.bss089-canvas-zone{min-height:540px}.bss079-ebdx-content{overflow:auto}}
`;

STYLES += `
/* BSS v0.8.12 - Background Composer comfort pass */
.bss092-composer{grid-template-columns:var(--bss092-left,285px) 6px minmax(440px,1fr) 6px var(--bss092-right,390px);gap:0}
.bss092-composer>.bss089-author-dock,.bss092-composer>.bss089-canvas-zone,.bss092-composer>.bss092-inspector{border-radius:10px}
.bss092-splitter{position:relative;min-width:0;cursor:col-resize;z-index:5}.bss092-splitter:after{content:"";position:absolute;top:12px;bottom:12px;left:2px;width:2px;border-radius:2px;background:rgba(255,255,255,.06)}.bss092-splitter:hover:after{background:rgba(103,167,255,.65)}
.bss092-left-hidden{grid-template-columns:0 0 minmax(440px,1fr) 6px var(--bss092-right,390px)}.bss092-left-hidden>.bss089-author-dock{visibility:hidden;border:0}.bss092-left-hidden>.bss092-splitter-left{visibility:hidden}
.bss092-right-hidden{grid-template-columns:var(--bss092-left,285px) 6px minmax(440px,1fr) 0 0}.bss092-right-hidden>.bss092-inspector{visibility:hidden;border:0;padding:0}.bss092-right-hidden>.bss092-splitter-right{visibility:hidden}
.bss092-left-hidden.bss092-right-hidden{grid-template-columns:0 0 minmax(440px,1fr) 0 0}
.bss092-panel-toggle.off{opacity:.55;border-style:dashed}
.bss092-layer-stack{height:100%}.bss092-layer-head{padding-bottom:7px}.bss092-layer-search{padding:6px 7px;border-bottom:1px solid rgba(255,255,255,.055)}.bss092-layer-search .bss-search{width:100%;max-width:none}
.bss092-layer-actions{display:grid;grid-template-columns:auto repeat(4,28px) 1fr;gap:4px;align-items:center;padding:6px 7px;border-bottom:1px solid rgba(255,255,255,.055);background:rgba(103,167,255,.045)}.bss092-layer-actions>span{font-size:7px;opacity:.6;margin-right:2px}.bss092-layer-actions button,.bss092-quick-depth button{height:27px;border:1px solid rgba(255,255,255,.09);border-radius:6px;background:rgba(255,255,255,.035);color:inherit;cursor:pointer}.bss092-layer-actions button:hover,.bss092-quick-depth button:hover{background:rgba(103,167,255,.14);border-color:rgba(103,167,255,.45)}.bss092-layer-actions em{font-style:normal;font:8px monospace;opacity:.65;text-align:right}
.bss089-dock-content .bss092-layer-row{grid-template-columns:22px minmax(0,1fr) auto;cursor:pointer;user-select:none}.bss092-drag-grip{font-size:11px;opacity:.28;text-align:center;cursor:grab}.bss092-layer-row:hover .bss092-drag-grip{opacity:.72}.bss092-layer-row.dragging{opacity:.35}.bss092-layer-row.bss092-drop-target{border-color:rgba(112,194,255,.9);box-shadow:inset 0 2px 0 rgba(112,194,255,.85)}
.bss092-layer-shortcuts{display:flex;flex-direction:column;gap:2px;padding:6px 8px;border-top:1px solid rgba(255,255,255,.05);font-size:7px;opacity:.48;line-height:1.3}
.bss092-inspector{display:flex!important;flex-direction:column;padding:0!important;overflow:hidden!important}.bss092-inspector-tabs{flex:0 0 auto;display:grid;grid-template-columns:1fr 1fr;gap:5px;padding:6px;border-bottom:1px solid rgba(255,255,255,.07);background:rgba(0,0,0,.12)}.bss092-inspector-tabs button{border:1px solid rgba(255,255,255,.07);border-radius:7px;background:rgba(255,255,255,.025);color:inherit;padding:8px;font:inherit;font-size:9px;cursor:pointer}.bss092-inspector-tabs button.active{background:rgba(103,167,255,.15);border-color:rgba(103,167,255,.55)}.bss092-inspector-body{flex:1;min-height:0;overflow:auto;padding:9px}.bss092-scene-meta{margin-bottom:8px}
.bss092-quickbar{display:flex;align-items:center;gap:8px;min-height:42px;padding:6px 8px;border:1px solid rgba(255,255,255,.075);border-radius:9px;background:rgba(0,0,0,.12);overflow-x:auto;flex:0 0 auto}.bss092-quickbar.muted{font-size:8px;opacity:.5}.bss092-quick-name{display:flex;flex-direction:column;min-width:110px;max-width:170px}.bss092-quick-name small{font-size:6px;opacity:.46}.bss092-quick-name b{font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bss092-quick-fields{display:flex;align-items:center;gap:5px;flex:1}.bss092-quick-fields label{display:flex;align-items:center;gap:3px;font-size:7px;opacity:.72;white-space:nowrap}.bss092-quick-fields input{width:58px;height:27px;padding:3px 5px;border:1px solid rgba(255,255,255,.08);border-radius:6px;background:rgba(0,0,0,.16);color:inherit;font:8px monospace}.bss092-quick-depth{display:grid;grid-template-columns:repeat(4,28px);gap:3px;flex:0 0 auto}
.bss092-main-preview{position:relative;min-height:0}.bss092-main-preview canvas{cursor:default}.bss092-canvas-tip{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;flex:0 0 auto;padding:2px 6px;font-size:7px;opacity:.45}
@media(max-width:1280px){.bss092-composer{--bss092-left:245px;--bss092-right:350px}.bss092-quick-name{display:none}.bss092-quick-fields input{width:52px}}
@media(max-width:1050px){.bss092-composer{height:auto;grid-template-columns:1fr!important;gap:8px;overflow:visible}.bss092-splitter{display:none}.bss092-composer>.bss089-author-dock,.bss092-composer>.bss092-inspector{visibility:visible!important;border:1px solid rgba(255,255,255,.08)!important}.bss092-composer>.bss089-author-dock{min-height:430px}.bss092-composer>.bss092-inspector{min-height:480px}.bss092-quickbar{flex-wrap:wrap}.bss092-quick-fields{flex-wrap:wrap}}
`;

STYLES += `
/* BSS v0.8.13 - mesh warp / curvature */
.bss093-warp-panel{border-color:rgba(105,178,255,.20)!important;background:linear-gradient(180deg,rgba(74,144,230,.055),rgba(0,0,0,.02))}
.bss093-warp-badge{font:8px monospace;padding:3px 6px;border:1px solid rgba(105,178,255,.30);border-radius:999px;background:rgba(105,178,255,.10);color:#a9d5ff}
.bss093-warp-actions{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin:7px 0}
.bss093-warp-presets{display:grid;grid-template-columns:repeat(3,1fr);gap:5px;margin:7px 0}.bss093-warp-presets button{min-height:29px;border:1px solid rgba(255,255,255,.08);border-radius:7px;background:rgba(255,255,255,.035);color:inherit;font:inherit;font-size:7px;cursor:pointer}.bss093-warp-presets button:hover{border-color:rgba(105,178,255,.48);background:rgba(105,178,255,.10)}
.bss093-warp-help{margin:7px 0 0;padding:7px 8px;border-radius:7px;background:rgba(0,0,0,.13);font-size:7px;line-height:1.45;opacity:.72}
.bss093-warp-quick{height:29px;padding:0 10px;border:1px solid rgba(255,255,255,.09);border-radius:7px;background:rgba(255,255,255,.035);color:inherit;font:inherit;font-size:8px;white-space:nowrap;cursor:pointer}.bss093-warp-quick:hover,.bss093-warp-quick.active{background:rgba(105,178,255,.12);border-color:rgba(105,178,255,.42)}.bss093-warp-quick.editing{box-shadow:0 0 0 1px rgba(255,207,109,.45) inset;color:#ffe0a0}
.bss092-main-preview canvas{touch-action:none}
`;

STYLES += `
/* BSS v0.8.15 */
.bss095-preview-mode{border:1px solid var(--line,#334155);background:rgba(12,20,32,.82);color:inherit;border-radius:8px;padding:6px 9px;font-size:11px;white-space:nowrap}.bss095-preview-mode.active{border-color:#69b2ff;box-shadow:0 0 0 1px rgba(105,178,255,.18) inset}.bss095-blur input[type="range"]{width:100%}.bss095-blur-presets{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:5px;margin-top:7px}.bss095-blur-presets button,.bss095-warp-toolcards button{border:1px solid rgba(120,145,175,.28);background:rgba(14,23,36,.7);color:inherit;border-radius:8px;padding:7px;cursor:pointer}.bss095-warp-toolcards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;margin:8px 0}.bss095-warp-toolcards button{text-align:left;display:flex;flex-direction:column;gap:2px}.bss095-warp-toolcards button small{opacity:.68;font-size:10px}.bss095-warp-toolcards button.active{border-color:#69b2ff;background:rgba(72,137,201,.15)}.bss095-veg-picker{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin:8px 0 10px}.bss095-veg-picker button{min-width:0;border:1px solid rgba(120,145,175,.25);background:rgba(13,21,32,.72);color:inherit;border-radius:9px;padding:5px;cursor:pointer}.bss095-veg-picker button.active{border-color:#69b2ff;box-shadow:0 0 0 1px rgba(105,178,255,.22) inset}.bss095-veg-thumb{display:flex;height:58px;align-items:flex-end;justify-content:center;overflow:hidden;border-radius:6px;background:repeating-conic-gradient(rgba(255,255,255,.055) 0 25%,transparent 0 50%) 50%/12px 12px}.bss095-veg-thumb img{max-width:100%;max-height:58px;image-rendering:pixelated;object-fit:contain}.bss095-veg-picker b{display:block;margin-top:4px;font-size:10px;overflow:hidden;text-overflow:ellipsis}.bss092-main-preview canvas[width="640"]{aspect-ratio:4/3;max-height:min(68vh,620px);width:100%;height:auto;object-fit:contain;image-rendering:pixelated}
`;
STYLES += `
/* BSS v0.8.19 - local blur */
.bss099-local-blur{border-color:rgba(122,196,255,.22)!important}.bss099-blur-area{margin-top:7px;padding:8px;border:1px solid rgba(255,255,255,.07);border-radius:8px;background:rgba(0,0,0,.11)}.bss099-blur-area.active{border-color:rgba(255,207,109,.6);box-shadow:0 0 0 1px rgba(255,207,109,.13) inset}.bss099-blur-area header{display:flex;justify-content:space-between;gap:8px;align-items:center;margin-bottom:7px}.bss099-blur-area header>div:first-child{display:flex;flex-direction:column}.bss099-blur-area header small{font-size:7px;opacity:.55}
`;

STYLES += `
/* BSS v0.8.20 - large asset browser / cropper / direct canvas tools */
.bss100-elements-dock{display:flex;flex-direction:column;min-height:0;height:100%}.bss100-elements-head{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:7px 8px}.bss100-elements-head>div{display:flex;flex-direction:column;min-width:0}.bss100-elements-head small{font-size:8px;opacity:.62}.bss100-dock-category{margin:0 7px 6px;width:calc(100% - 14px)}.bss100-more-assets{margin:8px;width:calc(100% - 16px)}
.bss100-asset-modal,.bss100-crop-modal{position:fixed;inset:0;z-index:999990;display:flex;align-items:center;justify-content:center;padding:3vh 3vw}.bss100-modal-shade{position:absolute;inset:0;border:0;background:rgba(2,6,12,.78);backdrop-filter:blur(2px)}
.bss100-asset-card,.bss100-crop-card{position:relative;z-index:1;width:min(1500px,94vw);height:min(900px,94vh);display:flex;flex-direction:column;overflow:hidden;border:1px solid rgba(105,178,255,.3);border-radius:14px;background:var(--panel,#101822);box-shadow:0 24px 80px rgba(0,0,0,.55)}.bss100-asset-card>header,.bss100-crop-card>header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 13px;border-bottom:1px solid rgba(255,255,255,.08)}.bss100-asset-card>header>div,.bss100-crop-card>header>div{display:flex;flex-direction:column}.bss100-asset-card header small,.bss100-crop-card header small{font-size:9px;opacity:.62}.bss100-asset-search{padding:9px 12px;border-bottom:1px solid rgba(255,255,255,.06)}.bss100-asset-search input{width:100%;font-size:13px;min-height:36px}.bss100-asset-layout{display:grid;grid-template-columns:minmax(180px,230px) 1fr;min-height:0;flex:1}.bss100-asset-layout>aside{overflow:auto;padding:8px;border-right:1px solid rgba(255,255,255,.07)}.bss100-asset-layout>aside button{width:100%;display:flex;justify-content:space-between;gap:8px;padding:8px 9px;margin-bottom:4px;border:1px solid transparent;border-radius:8px;background:transparent;color:inherit;text-align:left;cursor:pointer}.bss100-asset-layout>aside button.active{border-color:rgba(105,178,255,.38);background:rgba(105,178,255,.11)}.bss100-asset-layout>aside span{opacity:.55}.bss100-asset-grid{overflow:auto;padding:10px;display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));grid-auto-rows:max-content;gap:9px;align-content:start}.bss100-asset-item{min-width:0;display:flex;flex-direction:column;gap:5px;padding:7px;border:1px solid rgba(255,255,255,.08);border-radius:10px;background:rgba(255,255,255,.025);color:inherit;text-align:left;cursor:pointer}.bss100-asset-item:hover{border-color:rgba(105,178,255,.5);background:rgba(105,178,255,.08)}.bss100-asset-item .bss087-asset-thumb{height:110px}.bss100-asset-item .bss087-asset-thumb img{width:100%;height:100%;object-fit:contain;image-rendering:pixelated}.bss100-asset-item b{font-size:10px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss100-asset-item small{font-size:8px;opacity:.6;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bss100-asset-item em{font-size:8px;font-style:normal;color:#9fd3ff}
.bss100-crop-card{width:min(1200px,94vw)}.bss100-crop-toolbar{display:flex;align-items:center;gap:12px;padding:8px 12px;border-bottom:1px solid rgba(255,255,255,.06)}.bss100-crop-toolbar label{display:flex;align-items:center;gap:7px}.bss100-crop-toolbar span{font:10px monospace;opacity:.75}.bss100-crop-stage{flex:1;min-height:0;overflow:auto;display:flex;align-items:flex-start;justify-content:center;padding:14px;background:rgba(0,0,0,.2)}.bss100-crop-stage canvas{max-width:100%;height:auto;image-rendering:pixelated;touch-action:none;background:repeating-conic-gradient(rgba(255,255,255,.045) 0 25%,transparent 0 50%) 50%/16px 16px}.bss100-crop-card>footer{display:flex;align-items:center;gap:8px;padding:10px 12px;border-top:1px solid rgba(255,255,255,.07)}.bss100-source-crop{border-color:rgba(105,178,255,.16)!important}.bss100-canvas-tool{height:29px;padding:0 10px;border:1px solid rgba(255,255,255,.09);border-radius:7px;background:rgba(255,255,255,.035);color:inherit;white-space:nowrap;cursor:pointer}.bss100-canvas-tool.active{border-color:#69b2ff;background:rgba(105,178,255,.15);box-shadow:0 0 0 1px rgba(105,178,255,.2) inset}.bss100-metadata{max-width:1200px;margin:0 auto}.bss100-metadata .bss079-config-block{margin-bottom:12px}
@media(max-width:900px){.bss100-asset-modal,.bss100-crop-modal{padding:1vh 1vw}.bss100-asset-card,.bss100-crop-card{width:98vw;height:97vh}.bss100-asset-layout{grid-template-columns:145px 1fr}.bss100-asset-grid{grid-template-columns:repeat(auto-fill,minmax(120px,1fr));padding:7px}.bss100-asset-item .bss087-asset-thumb{height:82px}}
`;

/* BSS v0.8.22 composer parity/ergonomics */
STYLES += `
.bss101-floor-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:8px 0 10px}
.bss101-floor-grid button{min-height:56px;border:1px solid var(--border,#334155);background:rgba(22,32,45,.88);color:inherit;border-radius:8px;text-align:left;padding:9px;display:flex;flex-direction:column;gap:4px}
.bss101-floor-grid button:hover{border-color:#69b2ff;background:rgba(42,76,108,.55)}
.bss101-floor-grid small{opacity:.68;font-size:10px}
.bss101-battlers.active{border-color:#69b2ff!important;background:rgba(55,110,160,.38)!important}
.bss101-assets-large .bss100-asset-card{width:min(1480px,96vw);height:min(900px,92vh)}
.bss101-assets-large .bss100-asset-grid{grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px;align-content:start}
.bss101-assets-large .bss100-asset-item{min-height:154px}
.bss101-assets-large .bss087-asset-thumb{height:92px}
.bss101-assets-large .bss100-asset-layout{min-height:0;flex:1}
.bss101-assets-large .bss100-asset-layout main{overflow:auto;min-height:0}
`;
STYLES += `
.bss101-pipeline{margin:8px 10px 12px;padding:10px;border:1px solid rgba(105,178,255,.25);background:rgba(9,18,29,.58);border-radius:9px}
.bss101-pipeline>small{display:block;opacity:.62;font-size:9px;margin-bottom:7px}
.bss101-pipeline>div{display:flex;align-items:center;gap:5px;flex-wrap:wrap}
.bss101-pipeline span{padding:4px 7px;border:1px solid rgba(255,255,255,.12);border-radius:6px;opacity:.48;font-size:10px}
.bss101-pipeline span.active{opacity:1;border-color:rgba(105,178,255,.7);background:rgba(54,105,151,.28)}
.bss101-pipeline i{font-style:normal;opacity:.4}
.bss101-pipeline em{display:block;font-style:normal;font-size:9px;opacity:.66;margin-top:7px;line-height:1.35}
`;

/* BSS v0.8.23 composer usability */
STYLES += `
.bss102-lock{flex:0 0 34px!important;min-width:34px!important;height:30px!important;padding:0!important;border-radius:7px!important;opacity:.72}
.bss102-lock.active{opacity:1;background:rgba(255,190,80,.13)!important;border-color:rgba(255,190,80,.55)!important}
.bss092-layer-row.bss102-locked{opacity:.72}.bss092-layer-row.bss102-locked .bss092-drag-grip{cursor:not-allowed!important}
.bss102-floor-panel{display:block!important}.bss102-floor-panel>summary,.bss102-clouds>summary{cursor:pointer;display:flex;gap:8px;align-items:baseline;padding:4px 0 10px}.bss102-floor-panel>summary small,.bss102-clouds>summary small{opacity:.62;font-size:10px}
.bss102-use-tabs{display:flex;gap:8px;padding:10px 14px 0}.bss102-use-tabs button{border:1px solid var(--line,#263343);background:#101722;color:#cbd7e7;border-radius:8px;padding:8px 12px;cursor:pointer}.bss102-use-tabs button.active{border-color:#5fa7ff;background:#15283c;color:#fff}
.bss102-asset-card{width:min(1480px,96vw)!important;height:min(900px,93vh)!important}.bss102-asset-card .bss100-asset-grid{grid-template-columns:repeat(auto-fill,minmax(160px,1fr))!important}.bss102-asset-card .bss087-asset-thumb{height:130px!important}
.bss102-cloud-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px}.bss102-cloud-grid fieldset{border:1px solid #28384a;border-radius:8px;padding:10px}.bss102-cloud-grid legend{padding:0 5px;font-weight:700}
.bss102-tint-row{display:grid;grid-template-columns:1fr 1fr;gap:8px}.bss102-integration{border-color:rgba(93,165,255,.34)!important}
.bss102-command-overview{margin-top:12px;padding:12px;border:1px solid #2a3b4d;border-radius:10px;background:rgba(17,26,38,.62)}
@media(max-width:1100px){.bss102-cloud-grid{grid-template-columns:1fr}.bss102-asset-card .bss100-asset-grid{grid-template-columns:repeat(auto-fill,minmax(135px,1fr))!important}}
`;


STYLES += `
/* BSS v0.8.24 visual background browser */
.bss089-library-drawer.bss103-visual-library{width:min(720px,94vw)}
.bss103-visual-library .bss089-library-list .bss088-scene-list{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.bss103-visual-library .bss079-scene-card.bss088-scene-card{display:flex;flex-direction:column;align-items:stretch;min-height:0;padding:8px;gap:7px;text-align:left}
.bss103-visual-library .bss088-scene-card .bss079-card-preview{width:100%;height:auto;aspect-ratio:16/9;background:#080c12}
.bss103-visual-library .bss088-scene-card-copy{padding:0 2px 3px}
.bss103-metadata-preview{position:relative;margin-top:10px;width:min(520px,100%);border:1px solid rgba(255,255,255,.12);border-radius:9px;overflow:hidden;background:#090d13}
.bss103-metadata-preview canvas{display:block;width:100%;aspect-ratio:16/9;image-rendering:pixelated}
.bss103-metadata-preview>span{position:absolute;right:7px;bottom:7px;padding:3px 6px;border-radius:5px;background:rgba(0,0,0,.72);font:9px monospace;color:#d8e6f5}
.bss079-map-row:has(.bss103-row-preview){grid-template-columns:170px minmax(120px,1fr) minmax(180px,1fr) auto;align-items:center}
.bss103-row-preview{width:160px;border-radius:6px;overflow:hidden;border:1px solid rgba(255,255,255,.1);background:#080c12}
.bss103-row-preview canvas{display:block;width:100%;aspect-ratio:16/9;image-rendering:pixelated}
@media(max-width:900px){.bss103-visual-library .bss089-library-list .bss088-scene-list{grid-template-columns:1fr}.bss079-map-row:has(.bss103-row-preview){grid-template-columns:1fr}.bss103-row-preview{width:100%;max-width:240px}}

/* BSS 0.8.35 F12-safe update pipeline */
.bss107-build{margin-left:auto;padding:5px 9px;border:1px solid rgba(116,186,255,.45);border-radius:7px;background:rgba(34,91,148,.18);font:700 11px monospace;color:#9fd3ff;white-space:nowrap}
.bss106-hidden{opacity:.45}.bss106-hidden .bss088-layer-main{text-decoration:line-through}.bss107-rescan{margin:6px 0 8px;width:100%}

`;

/* BSS 0.8.36 */
STYLES += `
.bss108-layer-legend .bss-row{display:flex;flex-wrap:wrap;gap:6px}.bss108-band{border:1px solid var(--line,#334357);border-radius:7px;padding:5px 7px;font-size:11px;background:rgba(255,255,255,.035)}

/* BSS Guionización & Midbattle Dialogues Engine */
.bss-dialogue-card{background:#111722;border:1px solid #283548;border-radius:10px;padding:12px;margin-bottom:12px;transition:border-color .2s,box-shadow .2s}
.bss-dialogue-card:hover{border-color:#3d5272;box-shadow:0 4px 16px rgba(0,0,0,.25)}
.bss-dialogue-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid #1e293c}
.bss-target-badge{display:inline-flex;align-items:center;font-size:10px;font-weight:700;padding:2px 8px;border-radius:999px;text-transform:uppercase;letter-spacing:.5px}
.bss-target-badge.target-boss{background:rgba(239,68,68,.15);color:#f87171;border:1px solid rgba(239,68,68,.35)}
.bss-target-badge.target-sos{background:rgba(16,185,129,.15);color:#34d399;border:1px solid rgba(16,185,129,.35)}
.bss-target-badge.target-player{background:rgba(59,130,246,.15);color:#60a5fa;border:1px solid rgba(59,130,246,.35)}
.bss-target-badge.target-global{background:rgba(168,85,247,.15);color:#c084fc;border:1px solid rgba(168,85,247,.35)}
.bss-dialogue-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:8px}
.bss-dialogue-speaker-row{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:8px}
.bss-dialogue-options{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-bottom:10px;background:rgba(0,0,0,.18);padding:8px 10px;border-radius:8px;border:1px solid #1e2838}
.bss-dialogue-text{width:100%;background:#0c1017;color:#e2e8f0;border:1px solid #283548;border-radius:8px;padding:8px 10px;font-family:inherit;font-size:12px;resize:vertical;line-height:1.4}
.bss-dialogue-text:focus{outline:none;border-color:#5d84f7}
`;
