export const UX_CSS = String.raw`
/* Command Studio 0.8 – progressive disclosure and readable beginner layout */
.csb .csb-intro{margin-bottom:15px}
.csb .csb-intro h3{margin-bottom:5px}
.csb .csb-intro p{font-size:12px}
.csb .csb-explore{margin:18px 0 13px;padding:13px;border:1px solid var(--border,#38465a);border-radius:11px;background:var(--bg-secondary,#203249)}
.csb .csb-explore-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
.csb .csb-explore-title{display:flex;flex-direction:column;gap:3px}
.csb .csb-explore-head .btn{white-space:nowrap}
.csb .csb-result-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:12px 0}
.csb .csb-task-result{min-width:0;display:flex;align-items:stretch;border:1px solid var(--border,#38465a);border-radius:9px;overflow:hidden;background:var(--bg-secondary,#203249)}
.csb .csb-task-result:hover{border-color:var(--accent,#5398df)}
.csb .csb-task-open{display:flex;align-items:center;gap:9px;flex:1;min-width:0;border:0;background:transparent;color:inherit;text-align:left;padding:10px 12px}
.csb .csb-task-icon{font-size:21px;flex:none}
.csb .csb-task-copy{display:flex;flex-direction:column;gap:2px;min-width:0}
.csb .csb-task-copy strong{font-size:12px}
.csb .csb-task-copy small{font-size:11px;color:var(--text-secondary,#b1becc);line-height:1.3}
.csb .csb-favorite{width:36px;flex:none;border:0;border-left:1px solid var(--border,#38465a);background:transparent;color:var(--text-secondary,#b1becc);font-size:20px}
.csb .csb-favorite:hover{color:#E7BB64;background:rgba(255,255,255,.04)}
.csb .csb-shortcuts{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0 19px}
.csb .csb-help{margin:14px 0;font-size:12px;padding:11px 13px;border:1px solid var(--border,#38465a);border-radius:9px}
.csb .csb-help summary,.csb .csb-more-settings summary,.csb .csb-details summary{cursor:pointer;font-weight:600}
.csb .csb-help>p{margin-bottom:0}
.csb .csb-wizard-step{display:flex;align-items:center;gap:10px;justify-content:space-between;margin-bottom:12px}
.csb .csb-step-badge{display:inline-flex;align-items:center;font-size:10px;letter-spacing:.2px;border:1px solid var(--border,#38465a);border-radius:999px;padding:5px 9px;margin:3px 0 12px;color:var(--text-secondary,#b1becc)}
.csb .csb-field-note{color:var(--text-secondary,#b1becc);font-size:10px;display:block;margin-top:5px}
.csb .csb-more-settings{border-top:1px solid var(--border,#38465a);margin-top:13px;padding-top:12px}
.csb .csb-more-settings .grid{margin-top:10px}
.csb .csb-quiet{background:transparent!important;border-color:transparent!important;color:var(--text-secondary,#b1becc)!important;font-weight:normal!important}
.csb .csb-quiet:hover{border-color:var(--border,#38465a)!important;color:inherit!important}
.csb .csb-value-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:14px 0}
.csb .csb-value{display:flex;flex-direction:column;min-width:0;border-radius:7px;background:rgba(255,255,255,.035);padding:7px 10px}
.csb .csb-value span{font-size:10px;color:var(--text-secondary,#b1becc)}
.csb .csb-value strong{font-size:12px;overflow-wrap:anywhere}
.csb .csb-catalog-toolbar{display:flex;align-items:center;gap:9px;flex-wrap:wrap;margin:15px 0}
.csb .csb-catalog-toolbar .chips{margin:0}
.csb .csb-catalog-toolbar .search{flex:1;min-width:180px}
.csb .csb-catalog-toolbar select{max-width:270px;min-width:180px}
.csb .csb-catalog-layout{display:grid;grid-template-columns:minmax(240px,.9fr) minmax(320px,1.1fr);gap:15px;margin:10px 0 18px;align-items:start}
.csb .csb-catalog-list{display:flex;flex-direction:column;gap:6px;max-height:540px;overflow:auto;padding-right:4px}
.csb .csb-ref-item{text-align:left;border:1px solid var(--border,#38465a);border-radius:8px;background:var(--bg-secondary,#203249);color:inherit;padding:10px;display:flex;flex-direction:column;gap:4px}
.csb .csb-ref-item.active,.csb .csb-ref-item:hover{border-color:var(--accent,#5398df)}
.csb .csb-ref-item small{font-size:10px;color:var(--text-secondary,#b1becc)}
.csb .csb-catalog-details{border:1px solid var(--border,#38465a);border-radius:10px;background:var(--bg-secondary,#203249);padding:15px;position:sticky;top:0;min-height:200px;overflow-wrap:anywhere}
.csb .csb-catalog-details h4{font-size:15px;margin:8px 0}
.csb .csb-catalog-details .preview{margin-top:14px}
.csb .csb-params{display:flex;flex-direction:column;gap:4px;margin:12px 0}
.csb .csb-catalog-actions{display:flex;align-items:center;flex-wrap:wrap;gap:10px;margin-top:15px}
.csb .csb-warning{color:#f0bc86;border-left:3px solid #c48a45;padding:8px 11px;background:rgba(182,111,49,.12);font-size:11px}
.csb .csb-source-list{display:flex;gap:15px;flex-wrap:wrap;font-size:11px;padding-bottom:12px}
.csb .csb-section-head{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin-top:14px}
.csb .csb-tools-tabs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin:11px 0}
.csb .csb-tool-tab{background:var(--bg-secondary,#203249);border:1px solid var(--border,#38465a);border-radius:8px;padding:11px 10px;font-size:12px;color:inherit;text-align:left}
.csb .csb-tool-tab.active{border-color:var(--accent,#5398df);background:rgba(76,149,223,.16);font-weight:700}
.csb .csb-tool-panel{border:1px solid var(--border,#38465a);background:var(--bg-secondary,#203249);border-radius:11px;padding:13px;margin-top:8px}
.csb .csb-tool-panel>h4{font-size:14px;margin:0}
.csb .csb-tool-panel>p.sub{margin:5px 0 10px}
.csb .csb-tool-note{font-size:11px;color:var(--text-secondary,#b1becc)}
.csb .csb-details{padding:8px 10px;border:1px solid var(--border,#38465a);border-radius:8px;margin:10px 0}
.csb .csb-details[open]{background:rgba(255,255,255,.025)}
.csb .csb-quick-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin:9px 0 14px}
.csb .csb-effect-card{border:1px solid var(--border,#38465a);border-radius:8px;background:var(--bg-primary,#142033);color:inherit;text-align:left;padding:11px;display:flex;flex-direction:column;gap:5px}
.csb .csb-effect-card small{font-size:10px;color:var(--text-secondary,#b1becc)}
.csb .csb-range-card{border:1px solid var(--border,#38465a);border-radius:9px;padding:11px;margin:11px 0;display:flex;flex-direction:column;gap:8px}
.csb .csb-range-card .btn{align-self:flex-start}
.csb .csb-effects-list{display:flex;flex-direction:column;gap:6px;max-height:290px;overflow:auto;margin:10px 0}
.csb .csb-effect-row{text-align:left;display:flex;flex-direction:column;gap:4px;background:var(--bg-primary,#142033);color:inherit;border:1px solid var(--border,#38465a);border-radius:8px;padding:9px 10px}
.csb .csb-effect-row small{color:var(--text-secondary,#b1becc);font-size:10px}
.csb .csb-effect-detail{border-top:1px solid var(--border,#38465a);margin-top:13px;padding-top:12px}
.csb .csb-effect-detail .preview{max-height:110px}
@media(max-width:950px){.csb .csb-catalog-layout{grid-template-columns:1fr}.csb .csb-catalog-details{position:static}}
@media(max-width:720px){.csb .csb-result-grid{grid-template-columns:1fr}.csb .csb-tools-tabs{grid-template-columns:repeat(2,minmax(0,1fr))}.csb .csb-value-grid{grid-template-columns:1fr}.csb .csb-catalog-toolbar select{width:100%;max-width:none}}
`;