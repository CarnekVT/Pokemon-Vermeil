export const EXTRA_CSS = String.raw`
.csb.csb-fullscreen-active{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;min-width:0!important;min-height:0!important;max-width:none!important;max-height:none!important;z-index:5000!important;border-radius:0!important;margin:0!important;box-shadow:none!important}
@supports(height:100dvh){.csb.csb-fullscreen-active{height:100dvh!important}}
body.csb-fullscreen-lock{overflow:hidden!important;overscroll-behavior:none!important}
.csb .csb-fullscreen-controls[hidden]{display:none!important}
.csb .csb-fullscreen-controls{display:flex;gap:6px;align-items:center;position:fixed;top:8px;right:12px;z-index:5100;padding:5px;border-radius:9px;border:1px solid #495569;background:rgba(21,29,43,.97);box-shadow:0 7px 24px #080c16aa}
.csb.csb-fullscreen-active header{padding-right:315px}
.csb.csb-fullscreen-active>.stage{padding:20px 26px}
.csb.csb-fullscreen-active .content{max-width:1540px}
.csb.csb-fullscreen-active .narrow{max-width:1050px}
.csb.csb-fullscreen-active .widegrid{grid-template-columns:minmax(400px,1.16fr) minmax(350px,1fr)}
.csb.csb-fullscreen-active .resultlist{max-height:calc(100dvh - 370px)}
.csb .color-swatches{display:flex;flex-wrap:wrap;gap:6px;padding:9px 0}
.csb .color-swatch{display:flex;align-items:center;gap:6px;border-radius:7px;padding:6px 9px;background:var(--bg-secondary,#203249);color:inherit;border:1px solid var(--border,#38465a);font-size:11px}
.csb .color-swatch:hover,.csb .color-swatch:focus-visible{border-color:var(--accent,#5398df)}
.csb .swatch-dot{display:inline-block;width:22px;height:22px;border-radius:6px;border:2px solid rgba(255,255,255,.4);box-shadow:0 0 0 1px #0005;flex:none}
.csb .csb-color-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:6px 0 13px}
.csb .csb-color-tools input[type=color]{width:54px;height:39px;padding:3px;cursor:pointer}
.csb .csb-position-controls{display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin:9px 0 13px}
.csb .csb-pos{display:flex;flex-direction:column;align-items:center;gap:4px;padding:7px 9px;background:var(--bg-secondary,#203249);border:1px solid var(--border,#38465a);border-radius:7px;min-width:85px}
.csb .csb-pos.active{border-color:var(--accent,#5398df)}
.csb .csb-pos .mini-screen{position:relative;width:60px;height:41px;background:linear-gradient(140deg,#2b5148,#587d62);border-radius:4px;overflow:hidden}
.csb .csb-pos .mini-screen:after{content:'';position:absolute;left:4px;right:4px;height:10px;border:2px solid #a4c4e2;background:#1b2e50;border-radius:2px;bottom:3px}
.csb .csb-pos[data-pos=wu] .mini-screen:after{top:3px;bottom:auto}
.csb .csb-pos[data-pos=wm] .mini-screen:after{top:50%;bottom:auto;transform:translateY(-50%)}
.csb .csb-preview-canvas{padding-top:8px}
.csb .csb-dialog-stage{height:210px;max-width:650px;width:100%;position:relative;overflow:hidden;background:linear-gradient(145deg,#234f47,#53765b 40%,#364c6b 70%,#1c2f48);border:1px solid #5b6984;border-radius:9px;margin:6px 0}
.csb .csb-dialog-scenery{position:absolute;inset:0;background:repeating-linear-gradient(0deg,transparent 0 38px,rgba(255,255,255,.08) 38px 40px)}
.csb .csb-dialog-window{position:absolute;left:5%;right:5%;bottom:10px;padding:7px 12px 11px;min-height:78px;background:#212b48;border:3px double #a0b9e5;border-radius:10px;box-shadow:0 6px 15px #0009;white-space:pre-wrap;overflow-wrap:anywhere}
.csb .csb-dialog-stage.wu .csb-dialog-window{top:10px;bottom:auto}
.csb .csb-dialog-stage.wm .csb-dialog-window{top:50%;bottom:auto;transform:translateY(-50%)}
.csb .csb-dialog-label{font-size:8px;color:#9db9de;letter-spacing:1px;display:block;margin:0 0 4px}
.csb .csb-dialog-letters{font-size:14px;line-height:1.45;color:#fff;min-height:38px}
.csb .csb-preview-badges{display:flex;gap:5px;flex-wrap:wrap;margin:6px 0}
.csb .csb-preview-badges span{font-size:10px;color:var(--text-secondary,#b1becc);border:1px solid var(--border,#38465a);border-radius:6px;padding:3px 6px}
.csb .csb-color-example{display:inline-block;padding:6px 11px;margin:7px 0;border-radius:7px;background:#232c48;color:#fff;border:1px solid #748bb5;min-width:115px;text-shadow:1px 1px #111}
.csb .csb-visual-hint{font-size:10px;color:var(--text-secondary,#b1becc);margin:6px 0}
.csb .csb-token-row{display:flex;align-items:center;gap:7px;width:100%;justify-content:flex-start;text-align:left}
.csb .csb-token-row .token-title{flex:1;font-size:12px}
@media(max-width:900px){.csb.csb-fullscreen-active .widegrid{grid-template-columns:1fr}}
@media(max-width:680px){
.csb.csb-fullscreen-active header{padding-right:8px;padding-top:55px}
.csb .csb-fullscreen-controls{left:7px;right:7px;justify-content:flex-end}
.csb .csb-pos{min-width:75px}
}
`;