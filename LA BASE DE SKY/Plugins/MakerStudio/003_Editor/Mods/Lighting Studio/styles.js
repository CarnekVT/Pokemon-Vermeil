export const STYLES = [
".ls-root{--ls-line:var(--border);display:flex;flex-direction:column;height:100%;box-sizing:border-box;overflow:auto;background:var(--bg-primary);color:var(--text-primary);font:13px inherit;gap:0;min-width:285px}",
".ls-head{padding:14px 15px 12px;background:var(--bg-secondary);border-bottom:1px solid var(--border)}",
".ls-brand{display:flex;align-items:center;gap:10px}.ls-logo{display:grid;place-items:center;width:36px;height:36px;border-radius:10px;background:linear-gradient(145deg,#f0ca75,#b57b35);color:#241c12;font-size:23px}",
".ls-title{font-size:17px;font-weight:800;letter-spacing:-.45px}.ls-sub{font-size:11px;color:var(--text-secondary);margin-top:3px}",
".ls-toolbar{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;padding:12px 14px 7px}",
".ls-btn{min-width:0;display:inline-flex;justify-content:center;align-items:center;gap:5px;border:1px solid var(--border);border-radius:7px;padding:7px 9px;cursor:pointer;font:inherit;color:var(--text-primary);background:var(--bg-tertiary);transition:background .12s,border-color .12s}",
".ls-btn:hover{background:var(--bg-hover)}.ls-btn.active{color:var(--accent-text);background:var(--accent);border-color:var(--accent)}.ls-btn:disabled{cursor:default;opacity:.4}.ls-btn.warning:hover{color:var(--danger)}",
".ls-small{font-size:11px;padding:5px 7px}.ls-icon{font-size:15px}",
".ls-actions{display:flex;align-items:center;gap:6px;flex-wrap:wrap;padding:0 14px 11px}.ls-grow{flex:1}.ls-checkbox{display:inline-flex;gap:6px;align-items:center;font-size:11px;color:var(--text-secondary);cursor:pointer;white-space:nowrap}",
".ls-hint{font-size:11px;line-height:1.45;background:var(--bg-secondary);color:var(--text-secondary);padding:9px 11px;border:1px solid var(--border);border-radius:7px;margin:0 14px 12px}",
".ls-section{border-top:1px solid var(--border);padding:12px 14px}.ls-section-heading{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.45px;display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}",
".ls-muted{color:var(--text-secondary)}.ls-count{font-weight:600;color:var(--text-secondary);font-size:11px}.ls-list{display:flex;flex-direction:column;gap:4px;max-height:235px;overflow:auto;min-height:45px}",
".ls-item{display:flex;align-items:center;gap:7px;padding:5px;border:1px solid transparent;border-radius:7px;min-width:0}.ls-item:hover{background:var(--bg-hover)}.ls-item.selected{background:var(--bg-tertiary);border-color:var(--accent)}",
".ls-swatch{height:17px;width:17px;min-width:17px;border-radius:50%;box-shadow:0 0 0 1px var(--border),0 0 12px currentColor}",
".ls-item-main{border:none;background:transparent;color:inherit;text-align:left;flex:1;min-width:0;cursor:pointer;padding:2px 4px}.ls-item-name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;font-weight:600}.ls-item-meta{font-size:10px;color:var(--text-secondary)}",
".ls-ghost{background:transparent;border:none;color:var(--text-secondary);padding:4px;cursor:pointer;border-radius:4px}.ls-ghost:hover{background:var(--bg-hover);color:var(--text-primary)}",
".ls-field{margin-bottom:12px;display:grid;grid-template-columns:1fr auto;align-items:center;gap:7px}.ls-field-label{font-size:12px;display:flex;align-items:center;gap:6px}.ls-field-val{font-size:11px;color:var(--text-secondary)}",
".ls-range-row{display:flex;align-items:center;gap:8px;grid-column:1/-1}.ls-range{min-width:0;flex:1;accent-color:var(--accent);cursor:pointer}.ls-input{border:1px solid var(--border);border-radius:6px;box-sizing:border-box;background:var(--input-bg);color:var(--text-primary);padding:6px 7px;font:inherit;font-size:12px;max-width:100%;min-width:0}",
".ls-number{width:74px;text-align:right}.ls-color{height:31px;width:44px;cursor:pointer;background:none;border:none;padding:1px}.ls-two{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.ls-two .ls-field{margin-bottom:5px}",
".ls-inline{display:flex;gap:7px;flex-wrap:wrap}.ls-inline>*{flex:1}.ls-empty{padding:16px 8px;text-align:center;font-size:12px;color:var(--text-secondary)}",
".ls-preview-legend{border-top:1px solid var(--border);padding:11px 14px;color:var(--text-secondary);font-size:11px;line-height:1.4}",
".ls-bottom{margin-top:auto;padding:11px 14px;border-top:1px solid var(--border);background:var(--bg-secondary);display:flex;gap:6px;align-items:center}",
".ls-inline-note{font-size:11px;color:var(--text-secondary);line-height:1.45;margin:5px 0}",
".ls-ambient-chip{width:24px;height:24px;display:inline-block;vertical-align:middle;border:1px solid var(--border);border-radius:5px}"
].join("");

export const LIGHTING_EXTRA_CSS = `
.ls-live-preview{box-shadow:inset 0 0 20px rgba(0,0,0,.28)}
.ls-effect-group{padding:10px 9px 3px;border:1px solid var(--border);border-radius:8px;background:var(--bg-secondary);margin:12px 0}
.ls-effect-group>b{display:block;margin-bottom:9px;font-size:12px;letter-spacing:.2px}
.ls-root{scrollbar-width:thin;scrollbar-color:var(--border) transparent}
.ls-root .ls-btn{min-height:30px;white-space:normal}
.ls-section{background:var(--bg-primary)}
.ls-head{background:var(--bg-secondary)}
`;

export const LIGHTING_LAYER_DIAGNOSTIC_CSS = `
.ls-layer-status{display:flex;align-items:center;gap:9px;flex-wrap:wrap;padding:9px 14px;background:#1e2630;border-bottom:1px solid var(--border);font-size:11px;}
.ls-layer-live{flex:1;min-width:140px;font-weight:600;}
.ls-layer-status .ls-btn{font-size:11px;padding:4px 8px;}
`;

export const LIGHTING_WORKSPACE_CSS = "\n.ls-inspector{background:var(--bg-secondary,#171b24);border-top:1px solid var(--border,#303745);padding:0}\n.ls-inspector>.ls-section-heading{margin:0;padding:12px 14px;background:var(--bg-tertiary,#202633);border-bottom:1px solid var(--border,#303745);letter-spacing:.65px}\n.ls-inspector-tabs{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:4px;padding:8px;border-bottom:1px solid var(--border,#303745);background:var(--bg-secondary,#171b24)}\n.ls-inspector-tabs .ls-btn{min-height:32px;padding:5px 3px;font-size:10px;border-radius:5px;text-align:center}\n.ls-inspector-tabs .ls-btn.active{background:rgba(105,139,205,.19);border-color:#8299c7;color:var(--text-primary,#eee)}\n.ls-tab-body{min-height:90px;padding:12px 14px 16px;background:var(--bg-primary,#131822)}\n.ls-tab-body[hidden]{display:none!important}\n.ls-group-label{font-size:10px;letter-spacing:.85px;color:#8ea8d0;margin:0 0 12px;font-weight:700;border-bottom:1px solid rgba(160,178,220,.19);padding-bottom:8px}\n.ls-tab-body .ls-field{padding:2px 0;margin-bottom:11px}\n.ls-tab-body .ls-input:focus,.ls-tab-body .ls-range:focus{outline:1px solid #8aa6df;outline-offset:1px}\n.ls-tab-body .ls-effect-group{margin:0 0 9px;padding:11px;background:var(--bg-secondary,#1c2230)}\n.ls-tab-body .ls-effect-group>b{color:#bdccea;letter-spacing:.4px}\n.ls-tab-body .ls-inline-note{margin:0 0 12px}\n@media(max-width:360px){.ls-inspector-tabs .ls-btn{font-size:9px;padding:5px 1px}}\n";

export const LIGHTING_WIDE_WORKSPACE_CSS = `
.ls-root{container-type:inline-size;overflow-x:hidden;min-width:0}
.ls-workspace-nav{display:flex;gap:7px;flex-wrap:wrap;position:sticky;top:0;z-index:4;padding:11px 14px;background:var(--bg-secondary,#20242e);border-bottom:1px solid var(--border,#354057)}
.ls-workspace-tab{flex:1 1 135px;min-height:36px;font-weight:700!important;white-space:normal}
.ls-workspace{display:block;padding:12px 14px;min-height:290px}
.ls-workspace-view[hidden]{display:none!important}
.ls-workspace-view{max-width:1150px;margin:0 auto}
.ls-wide-light-layout{display:grid;grid-template-columns:minmax(255px,36%) minmax(340px,1fr);gap:14px;align-items:start}
.ls-wide-light-layout>.ls-section{min-width:0}
.ls-wide-light-layout .ls-list{max-height:min(58vh,590px);min-height:90px}
.ls-wide-light-layout .ls-inspector{border:1px solid var(--border,#354057);border-radius:9px;overflow:hidden}
.ls-workspace-view>.ls-section,.ls-wide-light-layout>.ls-section{border:1px solid var(--border,#354057);border-radius:9px;background:var(--bg-primary,#171d27)}
.ls-workspace-view>.ls-section{padding:17px 19px}
.ls-workspace-view .ls-field{grid-template-columns:minmax(0,1fr) auto}
.ls-workspace-view .ls-inline{row-gap:8px}
.ls-workspace-view .ls-inspector-tabs{grid-template-columns:repeat(4,minmax(0,1fr))}
.ls-workspace-view .ls-effect-group{max-width:100%}
@container (max-width:780px){
 .ls-wide-light-layout{grid-template-columns:minmax(0,1fr)}
 .ls-wide-light-layout .ls-list{max-height:250px}
 .ls-workspace{padding:8px}
 .ls-workspace-tab{flex:1 1 110px}
}
/* Refined desktop workflow; compact readable controls with a true clock editor */
.ls-root{min-height:0;display:flex;flex-direction:column;overflow-y:auto;overflow-x:hidden}
.ls-head{flex-shrink:0;padding:12px 18px}
.ls-toolbar,.ls-actions{flex-shrink:0}
.ls-workspace-nav{position:sticky;top:0;z-index:12;flex-shrink:0;gap:5px;padding:8px 12px;
  background:var(--bg-primary,#161d27);box-shadow:0 3px 12px rgba(0,0,0,.20)}
.ls-workspace-nav .ls-btn{flex:1 1 145px;border-radius:7px;min-height:38px;font-size:12px;padding:7px 9px}
.ls-workspace-nav .ls-btn.active{box-shadow:inset 0 -2px var(--accent,#93b9f2)}
.ls-workspace{padding:12px 18px}
.ls-workspace-view{max-width:1400px}
.ls-wide-light-layout{grid-template-columns:minmax(240px,31%) minmax(360px,1fr);gap:16px}
.ls-wide-light-layout>.ls-section{position:relative;min-width:0}
.ls-wide-light-layout .ls-list{max-height:min(65vh,680px)}
.ls-item.selected{outline:1px solid var(--accent,#8dbbde)}
.ls-inspector .ls-inspector-tabs{position:sticky;top:0;z-index:2}
.ls-time-editor-grid{display:grid;grid-template-columns:minmax(235px,.85fr) minmax(410px,1.6fr);gap:18px;align-items:start}
.ls-time-settings,.ls-time-palette{min-width:0;border:1px solid var(--border,#343c4a);
  border-radius:10px;padding:16px;background:var(--bg-secondary,#202733)}
.ls-time-settings .ls-field{grid-template-columns:minmax(0,1fr) minmax(110px,auto);align-items:center}
.ls-time-palette>.ls-section-heading{margin-bottom:6px}
.ls-time-preview-status{padding:8px 10px;margin:8px 0 12px;border-left:4px solid #ead2a7;
  border-radius:5px;background:var(--bg-tertiary,#2a3343);font-size:12px;font-weight:600}
.ls-time-track{display:grid;grid-template-columns:repeat(24,minmax(0,1fr));gap:2px;margin-bottom:17px;
  padding:6px;border-radius:7px;background:var(--bg-primary,#121923)}
.ls-time-slot{min-width:0;border:1px solid rgba(255,255,255,.12);height:39px;cursor:pointer;
  border-radius:2px;transition:transform 100ms ease}
.ls-time-slot:hover,.ls-time-slot.active{outline:2px solid var(--accent,#88b8f2);outline-offset:1px;transform:translateY(-2px)}
.ls-time-table{display:grid;gap:4px;overflow-x:auto}
.ls-time-table-head,.ls-time-row{display:grid;grid-template-columns:minmax(105px,1fr) minmax(115px,1fr) minmax(155px,1.7fr) 40px;
  gap:12px;align-items:center;min-width:450px}
.ls-time-table-head{font-size:10px;letter-spacing:.65px;font-weight:700;color:var(--text-secondary);
  padding:6px 9px;border-bottom:1px solid var(--border)}
.ls-time-row{padding:7px 9px;border-radius:6px;background:var(--bg-primary,#151b26)}
.ls-time-row:hover{background:var(--bg-tertiary,#293343)}
.ls-clock-input{width:100%;font-variant-numeric:tabular-nums}
.ls-time-color-cell,.ls-time-darkness-cell{display:flex;gap:9px;align-items:center;min-width:0}
.ls-time-color-cell .ls-color{min-width:45px}
.ls-hex-value{font-family:monospace;font-size:11px;color:var(--text-secondary);overflow:hidden}
.ls-time-darkness-cell .ls-range{min-width:65px}
.ls-time-percent{font-variant-numeric:tabular-nums;min-width:36px;font-size:11px;text-align:right}
.ls-time-remove{min-width:33px;min-height:31px;font-size:19px!important}
.ls-add-keyframe{margin-top:12px;width:100%}
@container (max-width:1100px){
 .ls-time-editor-grid{grid-template-columns:minmax(0,1fr)}
 .ls-time-settings{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px 12px}
 .ls-time-settings .ls-field{margin:0;align-items:center}
 .ls-time-settings .ls-inline-note{grid-column:1/-1}
}
@container (max-width:680px){
 .ls-time-settings{display:block}
 .ls-time-settings .ls-field{margin-bottom:10px}
 .ls-time-table-head,.ls-time-row{gap:7px;grid-template-columns:105px 110px minmax(135px,1fr) 38px;min-width:420px}
 .ls-time-settings,.ls-time-palette{padding:10px}
 .ls-workspace-nav .ls-btn{flex:1 1 110px}
 .ls-workspace{padding:7px}
}

/* Workspace actions only appear within the Lights tab */
.ls-light-quickbar{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,1fr);gap:12px;
  align-items:center;margin:0 0 10px}
.ls-light-quickbar .ls-toolbar,.ls-light-quickbar .ls-actions{padding:7px 9px;margin:0;
  background:var(--bg-secondary,#202733);border:1px solid var(--border,#354057);
  border-radius:8px;justify-content:flex-start;display:flex;flex-wrap:wrap}
.ls-light-quickbar .ls-btn{flex:0 1 auto;min-height:33px}
.ls-context-hint{margin:0 0 12px!important;padding:8px 11px!important;font-size:11px;
  white-space:normal;border-radius:6px}
.ls-debug-details{margin:5px 16px 12px;flex-shrink:0;border:1px solid var(--border,#303745);border-radius:7px;
  background:var(--bg-secondary,#202733)}
.ls-debug-details>summary{cursor:pointer;padding:8px 12px;font-size:11px;color:var(--text-secondary);
  user-select:none}
.ls-debug-details .ls-layer-status{border-top:1px solid var(--border,#303745);border-bottom:0}
@container (max-width:980px){
 .ls-light-quickbar{grid-template-columns:minmax(0,1fr)}
 .ls-light-quickbar .ls-btn{flex:1 1 auto}
}

`;
