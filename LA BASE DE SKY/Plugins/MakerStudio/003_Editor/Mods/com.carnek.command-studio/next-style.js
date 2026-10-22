export const NEXT_CSS=String.raw`
.csb .csb-events-workspace{display:flex;flex-direction:column;gap:10px;max-width:1450px}
.csb .csb-event-header,.csb .csb-event-detail-head{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}
.csb .csb-events-layout{display:grid;grid-template-columns:minmax(235px,31%) minmax(360px,69%);gap:12px;min-height:0}
.csb .csb-event-list{display:flex;flex-direction:column;gap:6px;max-height:65vh;overflow:auto;padding:3px;border-right:1px solid var(--border,#38465a)}
.csb .csb-event-entry{display:flex;align-items:center;gap:10px;padding:8px;border-radius:8px;border:1px solid var(--border,#38465a);background:var(--bg-secondary,#203249);color:inherit;text-align:left}
.csb .csb-event-entry.active{border-color:var(--accent,#5398df);background:rgba(80,148,225,.13)}
.csb .csb-event-entry-details{display:flex;flex-direction:column;min-width:0;gap:2px}
.csb .csb-event-entry-details small{font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-sprite{display:grid;place-items:center;width:46px;height:46px;border-radius:8px;background:rgba(95,120,148,.25);border:1px solid var(--border,#38465a);font-size:21px;flex-shrink:0;overflow:hidden}
.csb .csb-sprite canvas{width:40px;height:40px;image-rendering:pixelated}
.csb .csb-event-details{padding:10px 12px;min-width:0;border-radius:9px;border:1px solid var(--border,#38465a);background:var(--bg-secondary,#203249)}
.csb .csb-page-tabs{display:flex;flex-wrap:wrap;gap:5px;margin:8px 0}
.csb .csb-page-tab{padding:7px 11px;border-radius:8px;border:1px solid var(--border,#38465a);background:var(--bg-primary,#142033);color:inherit}
.csb .csb-page-tab.selected{border-color:var(--accent,#5398df);background:rgba(80,148,225,.14)}
.csb .csb-command-list{max-height:54vh;overflow:auto;border-radius:8px;padding:10px;background:rgba(0,0,0,.12)}
.csb .csb-command-entry{padding:8px 10px;margin:3px 0;background:var(--bg-secondary,#203249);border-left:2px solid #7894b5;border-radius:6px;font-size:12px;overflow-wrap:anywhere}
.csb .csb-command-slot{display:block;width:calc(100% - 20px);max-width:680px;padding:4px 9px;border:1px dashed rgba(112,160,208,.35);border-radius:6px;color:var(--text-secondary,#b1becc);background:transparent;text-align:center;font-size:10px}
.csb .csb-command-slot:hover,.csb .csb-command-slot.active{color:#b7ddff;border-color:var(--accent,#5398df);background:rgba(75,151,223,.13)}
.csb .csb-event-crud{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-top:10px}
.csb .csb-event-crud input{width:105px;min-width:0}
.csb .csb-event-crud input:first-child{min-width:160px;flex:1}
.csb .csb-event-browser-host{margin-top:14px}
.csb .csb-event-browser-host .search{margin:0}
.csb .csb-dialog-stage .csb-namebox{position:absolute;bottom:92px;left:6%;z-index:3;padding:3px 11px;border:2px solid #aac8f0;border-radius:6px;background:#253454;color:#fff;font-size:12px;box-shadow:0 3px 12px #0007}
.csb .csb-dialog-stage.wu .csb-namebox{top:2px;bottom:auto;left:auto;right:7%;transform:translateY(0)}
.csb .csb-dialog-stage.wm .csb-namebox{top:calc(50% - 57px);bottom:auto}
.csb .csb-correction-list{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0}
.csb .csb-correction-list .btn{font-size:11px}
.csb .csb-skin-selectors{display:flex;gap:7px;align-items:center;flex-wrap:wrap;padding:6px 0;margin:5px 0}
.csb .csb-skin-selectors label{font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-skin-selectors select{max-width:200px}
.csb .csb-skin-selectors span{font-size:10px}
.csb .csb-preview-area .csb-dialog-window{background-repeat:no-repeat;background-size:cover}
.csb .csb-audit-verified,.csb .csb-audit-pending,.csb .csb-audit-plugin,.csb .csb-audit-missing{border-left:3px solid #90a7c1;padding:7px 11px;font-size:11px;background:rgba(110,155,195,.10)}
.csb .csb-audit-verified{border-color:#56b99a}
.csb .csb-audit-plugin{border-color:#e3b16e}
.csb .csb-audit-missing{border-color:#db8c85}
@media(max-width:950px){.csb .csb-events-layout{grid-template-columns:1fr}.csb .csb-event-list{max-height:230px;border-right:0;border-bottom:1px solid var(--border,#38465a)}.csb .csb-command-list{max-height:420px}}
`;