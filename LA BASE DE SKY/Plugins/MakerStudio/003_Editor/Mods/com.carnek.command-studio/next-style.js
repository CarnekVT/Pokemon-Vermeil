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

/* v0.9.1: breathable layout, friendly command cards and true windowskin composition */
.csb .csb-events-content{max-width:1680px;width:100%;padding:0 4px}
.csb .csb-events-content>.csb-section-head{padding:6px 1px 2px}
.csb .csb-events-workspace{gap:12px;max-width:none}
.csb .csb-event-header{margin:5px 0 0;padding:5px 2px}
.csb .csb-event-header strong{font-size:16px}
.csb .csb-event-intro{padding:14px 18px;border:1px solid var(--border,#38465a);border-radius:12px;background:var(--bg-secondary,#203249)}
.csb .csb-event-intro strong{font-size:14px}
.csb .csb-event-intro p{margin:4px 0 0;font-size:12px}
.csb .csb-events-layout{display:grid;grid-template-columns:minmax(265px,355px) minmax(0,1fr);gap:16px;min-height:590px;max-height:calc(100vh - 245px);height:700px}
.csb .csb-event-list{max-height:none;overflow:hidden;min-height:0;border:1px solid var(--border,#38465a);border-radius:12px;padding:12px;background:var(--bg-secondary,#203249);display:flex;flex-direction:column;gap:9px}
.csb .csb-event-list>.search{min-height:42px;font-size:12px;flex:none}
.csb .csb-event-list>.csb-details{margin:0 0 3px;flex:none}
.csb .csb-event-results{display:flex;flex-direction:column;gap:7px;overflow-y:auto;overscroll-behavior:contain;min-height:0;padding:0 3px 10px}
.csb .csb-list-intro{display:flex;justify-content:space-between;align-items:baseline;gap:8px;margin:5px 1px 3px}
.csb .csb-list-intro strong{font-size:13px}
.csb .csb-event-entry{padding:9px 10px;border-radius:10px;background:var(--bg-primary,#142033);border-color:transparent;min-height:70px;transition:background .12s ease,border-color .12s ease}
.csb .csb-event-entry.active{background:rgba(74,145,221,.17);border-color:var(--accent,#5398df)}
.csb .csb-event-entry:hover{border-color:#648ab4}
.csb .csb-event-entry-details{gap:5px}
.csb .csb-event-entry-details strong{font-size:13px;line-height:1.25}
.csb .csb-event-entry-details small{font-size:11px;line-height:1.35}
.csb .csb-sprite{width:54px;height:54px;flex:0 0 54px;border-radius:9px;font-size:25px}
.csb .csb-sprite canvas{width:48px;height:48px;image-rendering:pixelated}
.csb .csb-event-details{display:flex;flex-direction:column;gap:9px;min-width:0;min-height:0;overflow:hidden;padding:15px 17px;border-radius:12px}
.csb .csb-event-detail-head{gap:15px;align-items:center}
.csb .csb-selected-name{display:flex;flex-direction:column;gap:5px}
.csb .csb-selected-name strong{font-size:17px;overflow-wrap:anywhere}
.csb .csb-eyebrow{letter-spacing:.7px;font-size:10px;color:var(--text-secondary,#b1becc)}
.csb .csb-page-tabs{gap:8px;margin:3px 0;flex:0 0 auto}
.csb .csb-page-tab{padding:9px 14px}
.csb .csb-event-helper{border-top:1px solid var(--border,#38465a);padding-top:10px}
.csb .csb-event-helper strong{font-size:12px}
.csb .csb-event-helper p{font-size:11px;margin:3px 0 0}
.csb .csb-command-list{min-height:170px;flex:1;max-height:none;overflow-y:auto;overscroll-behavior:contain;background:rgba(0,0,0,.11);padding:15px;border-radius:10px;border:1px solid var(--border,#38465a)}
.csb .csb-event-command{background:var(--bg-primary,#142033);padding:11px 12px;border-radius:9px;margin:7px 0 8px;border:1px solid var(--border,#38465a);border-left:3px solid #6d9bce}
.csb .csb-kind-dialogue{border-left-color:#84b5f1}
.csb .csb-kind-logic,.csb .csb-kind-choice{border-left-color:#dda964}
.csb .csb-kind-script{border-left-color:#ae8ddb}
.csb .csb-kind-audio{border-left-color:#6bc7a9}
.csb .csb-kind-state{border-left-color:#7cc9ad}
.csb .csb-event-command-row{display:flex;align-items:center;gap:12px}
.csb .csb-command-icon{font-size:23px;flex:0 0 27px;text-align:center}
.csb .csb-event-command-info{flex:1;min-width:0;display:flex;flex-direction:column;gap:5px}
.csb .csb-event-command-info strong{font-size:13px;line-height:1.3}
.csb .csb-command-snippet{font-size:11px;line-height:1.45;color:var(--text-secondary,#b1becc);word-break:break-word}
.csb .csb-command-count{white-space:nowrap;font-size:10px;color:var(--text-secondary,#b1becc)}
.csb .csb-command-code{margin:9px 0 0 36px;font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-command-code summary{cursor:pointer}
.csb .csb-command-raw{white-space:pre-wrap;overflow:auto;max-height:175px;border:1px solid var(--border,#38465a);border-radius:8px;padding:9px;margin:7px 0;font:11px/1.6 ui-monospace,Consolas,monospace}
.csb .csb-command-slot{margin-top:3px;margin-bottom:3px;padding:7px 12px;font-size:11px;border-radius:7px;min-height:29px;max-width:none;transition:background .12s}
.csb .csb-command-slot.active{font-weight:700;color:#a5d7ff}
.csb .csb-event-selection-bar{border-top:1px solid var(--border,#38465a);padding-top:11px;display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;flex:0 0 auto}
.csb .csb-selected-insertion{font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-name-editor{border:1px solid var(--border,#38465a);border-radius:11px;padding:13px;margin:12px 0;background:var(--bg-secondary,#203249)}
.csb .csb-name-head{display:flex;align-items:center;gap:9px;margin-bottom:10px}
.csb .csb-name-icon{font-size:22px}
.csb .csb-name-title{display:flex;flex-direction:column;gap:3px}
.csb .csb-name-title strong{font-size:13px}
.csb .csb-name-title small{font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-name-controls{display:flex;gap:7px;flex-wrap:wrap;align-items:center}
.csb .csb-name-controls input{min-width:190px;flex:1;width:auto!important}
.csb .csb-name-editor p.sub{margin:7px 0 0}
.csb .csb-preview-area{display:flex;flex-direction:column;gap:4px}
.csb .csb-skin-selectors{order:-1;flex-wrap:wrap;gap:10px;margin:0 0 8px}
.csb .csb-skin-selectors select{max-width:260px}
.csb .csb-dialog-window.csb-windowskin-applied{background:transparent!important;border:0!important;isolation:isolate;padding:16px 18px;overflow:hidden}
.csb .csb-dialog-window.csb-windowskin-applied .csb-rendered-skin{position:absolute;inset:0;width:100%;height:100%;z-index:0;image-rendering:pixelated;pointer-events:none}
.csb .csb-dialog-window.csb-windowskin-applied .csb-dialog-letters{position:relative;z-index:1}
.csb .csb-dialog-window.csb-windowskin-applied .csb-dialog-label{position:relative;z-index:1}
.csb .csb4-advanced-header{display:none}
.csb .cs4{font-size:13px}
.csb .cs4 .toolbar{display:none}
.csb .cs4 .tabs{padding:10px 15px}
.csb .cs4 .context{padding:12px 15px;gap:12px}
.csb .cs4 .grid{grid-template-columns:minmax(250px,.88fr) minmax(410px,1.55fr) minmax(300px,.95fr)}
.csb .cs4 .left,.csb .cs4 .center,.csb .cs4 .right{padding:19px}
.csb .cs4 .result{padding:13px;margin:8px 0}
.csb .cs4 .form{gap:14px;margin:16px 0}
.csb .cs4 .preview{font-size:12px;line-height:1.7;min-height:130px;max-height:300px}
.csb .cs4 .tip,.csb .cs4 .infobar{font-size:12px;line-height:1.55}
@media(max-width:1050px){.csb .csb-events-layout{grid-template-columns:minmax(240px,310px) minmax(0,1fr)}.csb .cs4 .grid{grid-template-columns:minmax(235px,.75fr) minmax(420px,1.25fr)}.csb .cs4 .right{grid-column:1/-1;border-top:1px solid var(--border,#38465a);max-height:270px}.csb .cs4 .left,.csb .cs4 .center{min-height:430px}}
@media(max-width:760px){.csb .csb-events-layout{grid-template-columns:1fr;height:auto;max-height:none}.csb .csb-event-list{max-height:320px}.csb .csb-event-details{min-height:420px;max-height:75vh}.csb .cs4 .grid{grid-template-columns:1fr}.csb .cs4 .left,.csb .cs4 .center,.csb .cs4 .right{grid-column:1/-1;min-height:250px;max-height:430px}.csb .csb-name-controls input{width:100%!important;min-width:100%}}

/* 0.9: create real events without a hidden technical panel. */
.csb .csb-event-create{border:1px solid var(--border,#38465a);border-radius:10px;padding:12px;background:var(--bg-primary,#142033);display:flex;flex-direction:column;gap:8px;flex:none}
.csb .csb-event-create>strong{font-size:13px}
.csb .csb-event-create>p{margin:0;font-size:11px;line-height:1.45}
.csb .csb-event-new-form{display:flex;flex-direction:column;gap:10px}
.csb .csb-event-new-field{display:flex;flex-direction:column;gap:4px;flex:1;min-width:0;font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-event-new-field>input{width:100%;min-height:36px;min-width:0;box-sizing:border-box;padding:8px 9px;border-radius:7px;background:var(--bg-secondary,#203249);border:1px solid var(--border,#38465a);color:inherit;font-size:12px}
.csb .csb-event-new-coords{display:flex;gap:9px}
.csb .csb-event-new-actions{display:flex;flex-wrap:wrap;gap:7px}
.csb .csb-event-new-actions>.btn{flex:1;min-width:105px;white-space:normal;min-height:36px}
.csb .csb-event-empty{display:flex;flex-direction:column;align-items:flex-start;gap:12px;padding:25px 17px;justify-content:center;min-height:200px}
.csb .csb-event-empty>strong{font-size:17px}
.csb .csb-event-empty>p{font-size:12px;max-width:430px}
.csb .csb-destination-create{margin-top:12px;border:1px solid var(--border,#38465a);border-radius:9px;padding:10px 12px}
.csb .csb-destination-create>summary{cursor:pointer;font-weight:600}
.csb .csb-destination-newrow{display:grid;grid-template-columns:minmax(160px,1fr) 70px 70px;gap:8px;align-items:center;padding-top:12px}
.csb .csb-destination-newrow>input{width:100%;min-width:0;box-sizing:border-box;padding:9px;border-radius:7px}
.csb .csb-destination-newrow>.btn{white-space:normal;min-height:36px}
@media(max-width:1100px){.csb .csb-destination-newrow{grid-template-columns:minmax(160px,1fr) 65px 65px}.csb .csb-destination-newrow>.btn{grid-column:1/-1}}
@media(max-width:760px){.csb .csb-destination-newrow{grid-template-columns:minmax(0,1fr) 65px 65px}.csb .csb-event-new-actions{flex-direction:column}}

.csb .csb-destination-actions{display:flex;gap:8px;align-items:center;justify-content:flex-start;flex-wrap:wrap;grid-column:1/-1}
.csb .csb-destination-actions>.btn{min-height:36px;white-space:normal;flex:1 1 150px}
.csb .csb-event-pick{flex-basis:100%!important}
`;