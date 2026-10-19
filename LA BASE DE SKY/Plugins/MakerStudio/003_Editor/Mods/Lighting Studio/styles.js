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
