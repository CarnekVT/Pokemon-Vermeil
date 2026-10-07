export const CSS = `
.cdx-root{
  --left:310px;--right:430px;
  height:100%;min-height:680px;display:grid;grid-template-rows:72px minmax(0,1fr) 28px;
  background:
    radial-gradient(circle at 48% 8%,rgba(112,118,255,.055),transparent 34%),
    var(--bg-primary,#11121a);
  color:var(--text-primary,#ececf2);font:12px/1.35 inherit;overflow:hidden;
}
.cdx-root *{box-sizing:border-box}.cdx-root button,.cdx-root input,.cdx-root textarea{font:inherit}
.cdx-toolbar{display:flex;align-items:center;gap:8px;padding:9px 12px;border-bottom:1px solid var(--border,#343641);background:linear-gradient(180deg,var(--bg-tertiary,#242633),#20222d);box-shadow:0 1px 0 rgba(255,255,255,.025) inset;min-width:0}
.cdx-brand{display:flex;align-items:center;gap:10px;min-width:290px}.cdx-brand-icon{width:34px;height:34px;border:1px solid rgba(124,130,255,.42);border-radius:9px;display:grid;place-items:center;background:linear-gradient(145deg,rgba(124,130,255,.24),rgba(124,130,255,.06));color:#aeb2ff;box-shadow:0 6px 18px rgba(40,45,120,.16)}.cdx-brand-icon svg{width:19px;height:19px}.cdx-brand-copy{min-width:0}.cdx-title{font-weight:850;font-size:15px;letter-spacing:.01em;white-space:nowrap}.cdx-sub{font-size:9px;color:var(--text-tertiary,#8e92a4);white-space:nowrap;margin-top:2px}.cdx-spacer{flex:1}
.cdx-btn{height:32px;padding:0 10px;border:1px solid var(--border,#3d4050);border-radius:7px;background:var(--bg-secondary,#1a1c25);color:inherit;cursor:pointer;white-space:nowrap;transition:.12s ease}.cdx-btn:hover{border-color:var(--accent,#7c82ff);background:var(--bg-hover,#292c38);transform:translateY(-1px)}.cdx-btn.primary{background:linear-gradient(180deg,#7f85ff,#696fe7);border-color:transparent;color:white;font-weight:800;box-shadow:0 4px 14px rgba(88,94,220,.2)}.cdx-btn.danger{color:#f0a1aa;border-color:rgba(224,105,118,.24)}.cdx-btn-soft{background:rgba(255,255,255,.025)}
.cdx-badge{padding:5px 8px;border:1px solid var(--border,#3d4050);border-radius:999px;font-size:9px;color:var(--text-secondary,#b9bdca);white-space:nowrap}.cdx-badge.ok{color:#76d89a;border-color:rgba(118,216,154,.42);background:rgba(78,170,111,.08)}.cdx-badge.warn{color:#efbd70;border-color:rgba(239,189,112,.42);background:rgba(190,126,34,.06)}

.cdx-main{display:grid;grid-template-columns:var(--left) minmax(460px,1fr) var(--right);min-height:0;min-width:0}.cdx-library{border-right:1px solid var(--border,#343641);display:grid;grid-template-rows:auto auto minmax(0,1fr);min-width:0;background:linear-gradient(180deg,rgba(255,255,255,.018),transparent 30%),var(--bg-secondary,#171922)}
.cdx-lib-head{padding:10px 10px 9px;border-bottom:1px solid var(--border,#343641);display:grid;gap:8px}.cdx-lib-title{display:flex;align-items:center;justify-content:space-between;color:var(--text-secondary,#c3c6d2);font-size:10px;text-transform:uppercase;letter-spacing:.07em}.cdx-count{display:inline-grid;place-items:center;min-width:22px;height:19px;padding:0 6px;border-radius:999px;background:rgba(127,127,127,.09);border:1px solid rgba(127,127,127,.16);font-size:9px;color:var(--text-secondary,#b9bdca)}.cdx-count.accent{border-color:rgba(124,130,255,.38);background:rgba(124,130,255,.13);color:#b6baff}
.cdx-search,.cdx-input,.cdx-textarea{width:100%;background:var(--input-bg,var(--bg-primary,#11131b));border:1px solid var(--border,#3a3d49);border-radius:6px;color:inherit;padding:7px 8px;outline:none}.cdx-search{height:32px}.cdx-search:focus,.cdx-input:focus,.cdx-textarea:focus{border-color:var(--accent,#7c82ff);box-shadow:0 0 0 2px rgba(124,130,255,.08)}
.cdx-filterbar{padding:7px 10px;display:flex;gap:5px;border-bottom:1px solid var(--border,#343641)}.cdx-chip{padding:4px 8px;border:1px solid var(--border,#3a3d49);border-radius:999px;font-size:9px;cursor:pointer;color:var(--text-secondary,#b8bbc8);background:transparent}.cdx-chip.active{border-color:var(--accent,#7c82ff);background:rgba(124,130,255,.13);color:#e7e8ff}
.cdx-list{overflow:auto;padding:6px 5px 12px}.cdx-row{display:grid;grid-template-columns:46px minmax(0,1fr) auto;gap:8px;align-items:center;min-height:52px;padding:4px 7px;margin:1px 0;border:1px solid transparent;border-radius:8px;cursor:pointer;transition:.1s ease}.cdx-row:hover{background:rgba(255,255,255,.035)}.cdx-row.active{background:linear-gradient(90deg,rgba(124,130,255,.16),rgba(124,130,255,.07));border-color:rgba(124,130,255,.34);box-shadow:0 4px 14px rgba(0,0,0,.08)}.cdx-icon{width:42px;height:42px;image-rendering:pixelated;border-radius:7px;background:radial-gradient(circle,rgba(255,255,255,.055),transparent 68%)}.cdx-row-copy{min-width:0}.cdx-row b{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:11px}.cdx-row small{display:block;color:var(--text-tertiary,#84899a);font-size:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-top:2px}.cdx-row-tail{display:flex;align-items:center;gap:6px}.cdx-row-count{min-width:18px;height:18px;padding:0 5px;display:grid;place-items:center;border-radius:999px;background:rgba(241,190,109,.12);border:1px solid rgba(241,190,109,.28);color:#f0c175;font-size:8px}.cdx-dot{width:7px;height:7px;border-radius:50%;background:transparent}.cdx-row.changed .cdx-dot{background:#efbd6d;box-shadow:0 0 8px rgba(239,189,109,.45)}

.cdx-center{min-width:0;display:grid;grid-template-rows:auto minmax(0,1fr);background:linear-gradient(180deg,rgba(124,130,255,.025),transparent 42%)}.cdx-center-head{min-height:134px;padding:11px 15px;border-bottom:1px solid var(--border,#343641);display:flex;align-items:center;gap:14px;background:linear-gradient(105deg,rgba(124,130,255,.035),transparent 62%)}.cdx-portrait{width:112px;height:112px;display:grid;place-items:center;flex:0 0 112px;border:1px solid rgba(127,127,127,.12);border-radius:18px;background:radial-gradient(circle at 50% 42%,rgba(124,130,255,.16),rgba(255,255,255,.025) 52%,transparent 72%);box-shadow:inset 0 0 30px rgba(0,0,0,.13)}.cdx-portrait canvas{width:112px;height:112px;image-rendering:pixelated}.cdx-name{min-width:0}.cdx-name-top{display:flex;align-items:center;gap:8px;min-width:0}.cdx-name h2{margin:0;font-size:19px;line-height:1.15;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.cdx-form-pill{padding:3px 6px;border-radius:999px;border:1px solid rgba(124,130,255,.3);background:rgba(124,130,255,.1);color:#b6baff;font-size:8px;white-space:nowrap}.cdx-selection-meta{margin:6px 0 0;color:var(--text-tertiary,#8f93a3);font-size:9px}.cdx-selection-meta code{color:var(--text-secondary,#c2c5d0);font:inherit}.cdx-type-line{display:flex;gap:5px;margin-top:8px;flex-wrap:wrap}.cdx-type-badge{padding:3px 8px;border-radius:999px;background:rgba(125,130,151,.2);border:1px solid rgba(125,130,151,.52);color:#fff;font-size:8px;font-weight:800;letter-spacing:.06em;box-shadow:inset 0 1px rgba(255,255,255,.06)}
.cdx-comparison{overflow:auto;padding:13px;display:grid;gap:11px}.cdx-summary-strip{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}.cdx-summary-metric{display:grid;grid-template-columns:1fr auto;grid-template-rows:auto auto;gap:1px 8px;padding:8px 9px;border:1px solid rgba(127,127,127,.12);border-radius:8px;background:rgba(255,255,255,.018)}.cdx-summary-metric small{font-size:8px;color:var(--text-tertiary,#8f93a3);text-transform:uppercase;letter-spacing:.07em}.cdx-summary-metric b{grid-column:2;grid-row:1/3;align-self:center;font-size:16px}.cdx-summary-metric span{font-size:8px;color:var(--text-secondary,#b8bbc8)}
.cdx-compare-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.cdx-card{border:1px solid var(--border,#343641);border-radius:11px;background:linear-gradient(180deg,rgba(255,255,255,.024),rgba(255,255,255,.01)),var(--bg-secondary,#191b24);padding:11px;min-width:0}.cdx-card.result{border-color:rgba(124,130,255,.28);box-shadow:inset 0 1px rgba(124,130,255,.05)}.cdx-card-title{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:9px}.cdx-card h3{margin:0;font-size:10px;text-transform:uppercase;letter-spacing:.09em;color:var(--text-secondary,#b8bbc8)}.cdx-card-kicker{font-size:7px;color:var(--text-tertiary,#85899a);border:1px solid rgba(127,127,127,.13);border-radius:999px;padding:2px 5px}.cdx-fieldline{display:grid;grid-template-columns:108px minmax(0,1fr);gap:8px;padding:6px 0;border-top:1px solid rgba(127,127,127,.09)}.cdx-fieldline span{font-size:8px;color:var(--text-tertiary,#9296a6)}.cdx-fieldline strong{font-size:9px;overflow-wrap:anywhere}.cdx-fieldline.changed strong{color:#f0c36f}.cdx-stat-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-bottom:8px}.cdx-stat{position:relative;padding:7px;border-radius:7px;background:rgba(127,127,127,.055);text-align:center;border:1px solid transparent}.cdx-stat.changed{background:rgba(240,190,109,.07);border-color:rgba(240,190,109,.18)}.cdx-stat b{display:block;font-size:14px}.cdx-stat small{font-size:8px;color:var(--text-tertiary,#9296a6)}.cdx-stat em{position:absolute;right:4px;top:3px;font-style:normal;font-size:7px;color:#f0c36f}.cdx-changes-card{padding-bottom:10px}.cdx-change-chips{display:flex;flex-wrap:wrap;gap:5px}.cdx-change-chips span{padding:3px 6px;border-radius:5px;background:rgba(240,190,109,.08);border:1px solid rgba(240,190,109,.18);color:#eec77f;font-size:8px}

.cdx-inspector{border-left:1px solid var(--border,#343641);display:grid;grid-template-rows:auto minmax(0,1fr);min-width:0;background:var(--bg-secondary,#171922)}.cdx-tabs{display:flex;gap:3px;padding:7px 7px 6px;border-bottom:1px solid var(--border,#343641);overflow-x:auto;background:rgba(255,255,255,.012)}.cdx-tab{padding:6px 8px;border:0;border-radius:6px;background:transparent;color:var(--text-secondary,#aeb2c0);font:inherit;cursor:pointer;white-space:nowrap;font-size:10px}.cdx-tab:hover{background:rgba(255,255,255,.035)}.cdx-tab.active{background:rgba(124,130,255,.15);color:#f0f1ff;box-shadow:inset 0 0 0 1px rgba(124,130,255,.16)}.cdx-inspect-body{overflow:auto;padding:10px}.cdx-group{border:1px solid var(--border,#343641);border-radius:10px;padding:10px;margin-bottom:9px;background:linear-gradient(180deg,rgba(255,255,255,.022),rgba(255,255,255,.008))}.cdx-group-title{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:8px}.cdx-group-title b{font-size:10px;text-transform:uppercase;letter-spacing:.06em}.cdx-group-title small{font-size:8px;color:var(--text-tertiary,#84899a);text-align:right;max-width:240px}.cdx-field{display:grid;gap:5px;margin:9px 0}.cdx-label{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:9px;color:var(--text-secondary,#b8bbc8)}.cdx-label-left{display:inline-flex;align-items:center;gap:5px}.cdx-before{font-size:8px;color:var(--text-tertiary,#7f8494);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:215px}.cdx-inherit{font-size:6px;letter-spacing:.06em;padding:2px 4px;border-radius:4px;border:1px solid rgba(98,192,225,.24);background:rgba(98,192,225,.07);color:#83d0e9}.cdx-reset{justify-self:start;border:0;background:transparent;color:#9da3ff;cursor:pointer;font-size:8px;padding:1px 0}.cdx-reset:hover{text-decoration:underline}.cdx-stats-edit{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.cdx-stat-input{padding:6px;border:1px solid rgba(127,127,127,.1);border-radius:7px;background:rgba(127,127,127,.025)}.cdx-stat-input.changed{border-color:rgba(240,190,109,.2);background:rgba(240,190,109,.045)}.cdx-stat-input-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:4px}.cdx-stat-input label{font-size:8px;color:var(--text-secondary,#b9bdca)}.cdx-stat-input small{font-size:7px;color:var(--text-tertiary,#818596)}.cdx-textarea{min-height:90px;resize:vertical;line-height:1.45}

.cdx-list-editor{display:grid;gap:5px}.cdx-list-edit-row{display:grid;grid-template-columns:minmax(0,1fr) 28px;gap:5px;align-items:start}.cdx-move-row{display:grid;grid-template-columns:26px 58px minmax(0,1fr) 28px;gap:5px;align-items:start}.cdx-level-prefix{align-self:center;text-align:right;font-size:8px;color:var(--text-tertiary,#85899a)}.cdx-level{height:29px;padding:4px 5px}.cdx-evo-row{display:grid;grid-template-columns:minmax(100px,1fr) 105px minmax(76px,.7fr) 28px;gap:5px;align-items:start}.cdx-x{height:29px;border:1px solid var(--border,#3a3d49);border-radius:5px;background:transparent;color:#e69ca5;cursor:pointer}.cdx-x:hover{border-color:rgba(230,156,165,.55);background:rgba(230,156,165,.06)}.cdx-add{width:100%;margin-top:1px;height:29px;border:1px dashed var(--border,#444756);border-radius:6px;background:rgba(255,255,255,.012);color:var(--text-secondary,#b8bbc8);cursor:pointer}.cdx-add:hover{border-color:var(--accent,#7c82ff);color:#dfe1ff;background:rgba(124,130,255,.05)}
.cdx-ref-wrap{position:relative;min-width:0}.cdx-ref-input{height:29px;padding:4px 7px}.cdx-ref-dropdown{display:none;position:absolute;left:0;right:0;top:calc(100% + 3px);max-height:225px;overflow:auto;z-index:40;border:1px solid var(--border,#434654);border-radius:7px;background:#20222d;box-shadow:0 12px 30px rgba(0,0,0,.34);padding:4px}.cdx-ref-dropdown.open{display:block}.cdx-ref-item{display:block;width:100%;text-align:left;padding:6px 7px;border:0;border-radius:5px;background:transparent;color:var(--text-primary,#eee);cursor:pointer;font-size:9px}.cdx-ref-item:hover,.cdx-ref-item.active{background:rgba(124,130,255,.16)}.cdx-ref-item strong{font-weight:650}

.cdx-migration-dialog{padding:4px 2px;display:grid;gap:10px}.cdx-migration-dialog h2{font-size:16px;margin:0}.cdx-migration-dialog p{font-size:10px;color:var(--text-secondary,#b8bbc8);line-height:1.5;margin:0 0 3px}.cdx-migration-option{display:grid;gap:3px;text-align:left;padding:11px;border:1px solid var(--border,#3b3e4a);border-radius:9px;background:rgba(255,255,255,.018);color:inherit;cursor:pointer}.cdx-migration-option:hover{border-color:var(--accent,#7c82ff);background:rgba(124,130,255,.06)}.cdx-migration-option b{font-size:11px}.cdx-migration-option small{font-size:9px;color:var(--text-tertiary,#8a8e9e)}
.cdx-empty{padding:25px;text-align:center;color:var(--text-tertiary,#9296a6)}.cdx-status{display:flex;align-items:center;gap:12px;padding:0 10px;border-top:1px solid var(--border,#343641);background:var(--bg-tertiary,#222430);font-size:8px;color:var(--text-tertiary,#85899a);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}

@media(max-width:1260px){.cdx-root{--left:260px;--right:380px}.cdx-toolbar .cdx-sub{display:none}.cdx-summary-strip{grid-template-columns:repeat(2,1fr)}.cdx-compare-grid{grid-template-columns:1fr}}
@media(max-width:1020px){.cdx-root{--left:230px;--right:340px}.cdx-toolbar .cdx-badge,.cdx-btn-soft{display:none}.cdx-center-head{min-height:104px}.cdx-portrait{width:84px;height:84px;flex-basis:84px}.cdx-portrait canvas{width:84px;height:84px}}


/* v0.2.0 — navigation/layout pass. Functionality must stay quick to reach. */
body.cdx-fullscreen-lock{overflow:hidden!important}
.cdx-root{height:100%!important;min-height:0!important;max-height:100%;--left:286px;--right:410px}
.cdx-root.cdx-fullscreen-active{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;height:100dvh!important;max-height:none!important;z-index:2147482000!important;background:var(--bg-primary,#11121a);box-shadow:none}
.cdx-root.cdx-fullscreen-active .cdx-toolbar{padding-left:16px;padding-right:16px}
.cdx-toolbar{min-height:0;overflow-x:auto;overflow-y:hidden;scrollbar-width:thin;flex-wrap:nowrap}
.cdx-toolbar .cdx-btn-soft,.cdx-toolbar .cdx-fullscreen-btn{display:inline-flex!important;align-items:center;justify-content:center}
.cdx-fullscreen-btn.active{border-color:rgba(124,130,255,.7);background:rgba(124,130,255,.16);color:#f4f4ff}

.cdx-main{grid-template-columns:var(--left) 5px minmax(420px,1fr) 5px var(--right)!important;min-height:0;overflow:hidden}
.cdx-resizer{position:relative;min-width:5px;width:5px;cursor:col-resize;background:transparent;z-index:8;transition:background .12s ease}
.cdx-resizer:after{content:"";position:absolute;top:0;bottom:0;left:2px;width:1px;background:var(--border,#343641)}
.cdx-resizer:hover,.cdx-resizer.dragging{background:rgba(124,130,255,.14)}
.cdx-resizer:hover:after,.cdx-resizer.dragging:after{background:var(--accent,#7c82ff)}
.cdx-library{grid-template-rows:auto auto minmax(0,1fr) auto!important;min-height:0;overflow:hidden;border-right:0!important}
.cdx-list{min-height:0!important;height:100%;overflow-y:auto!important;overflow-x:hidden!important;overscroll-behavior:contain;scrollbar-gutter:stable;padding:5px 4px 10px;outline:none}
.cdx-list:focus-visible{box-shadow:inset 0 0 0 1px rgba(124,130,255,.28)}
.cdx-lib-foot{height:25px;display:flex;align-items:center;justify-content:space-between;gap:8px;padding:0 9px;border-top:1px solid var(--border,#343641);color:var(--text-tertiary,#7f8494);font-size:7px;white-space:nowrap;background:rgba(255,255,255,.012)}
.cdx-filterbar{overflow-x:auto;scrollbar-width:none}.cdx-filterbar::-webkit-scrollbar{display:none}
.cdx-row{grid-template-columns:40px minmax(0,1fr) auto;min-height:47px;padding:3px 6px}
.cdx-icon-shell{width:38px;height:38px;position:relative;display:grid;place-items:center;overflow:visible}
.cdx-icon{width:38px;height:38px;border-radius:0!important;background:none!important;opacity:0;transition:opacity .08s linear}
.cdx-icon.loaded{opacity:1}
.cdx-icon.failed{display:none}
.cdx-icon-fallback{position:absolute;inset:0;display:grid;place-items:center;color:var(--text-tertiary,#7f8494);font-size:10px;opacity:.18;pointer-events:none}
.cdx-icon.loaded + .cdx-icon-fallback{display:none}
.cdx-icon-shell.missing .cdx-icon-fallback{opacity:.28}

/* No decorative empty sprite card: show the Pokémon, not an empty box. */
.cdx-center-head{min-height:118px;padding:9px 14px;gap:12px}
.cdx-portrait{width:104px;height:104px;flex:0 0 104px;border:0!important;border-radius:0!important;background:transparent!important;box-shadow:none!important;overflow:visible}
.cdx-portrait canvas{width:104px;height:104px;image-rendering:pixelated}
.cdx-portrait.missing{display:none}
.cdx-quick-nav{display:flex;align-items:center;gap:5px;padding:3px;border:1px solid rgba(127,127,127,.13);border-radius:7px;background:rgba(255,255,255,.018);white-space:nowrap;color:var(--text-tertiary,#8a8e9e);font-size:8px}
.cdx-nav-btn{width:27px;height:25px;border:0;border-radius:5px;background:transparent;color:var(--text-secondary,#c5c8d3);font-size:18px;line-height:1;cursor:pointer}
.cdx-nav-btn:hover{background:rgba(124,130,255,.14);color:#fff}

.cdx-center,.cdx-inspector{min-height:0;overflow:hidden}
.cdx-comparison,.cdx-inspect-body{overscroll-behavior:contain;scrollbar-gutter:stable}
.cdx-inspector{border-left:0!important}
.cdx-tabs{flex:0 0 auto;scrollbar-width:thin}
.cdx-inspect-body{min-height:0;overflow-y:auto!important;overflow-x:hidden!important}
.cdx-group{padding:9px;margin-bottom:8px}
.cdx-group-title{position:sticky;top:-10px;z-index:2;padding:2px 0 5px;background:linear-gradient(180deg,var(--bg-secondary,#171922) 72%,transparent)}

/* Move management: one compact workspace instead of three long form dumps. */
.cdx-moves-shell{position:sticky;top:-10px;z-index:12;margin:-10px -10px 8px;padding:8px 10px 7px;background:var(--bg-secondary,#171922);border-bottom:1px solid var(--border,#343641)}
.cdx-move-tabs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:5px}
.cdx-move-tab{height:31px;padding:0 8px;border:1px solid var(--border,#3a3d49);border-radius:6px;background:rgba(255,255,255,.015);color:var(--text-secondary,#afb3c1);display:flex;align-items:center;justify-content:space-between;gap:6px;cursor:pointer;font-size:9px}
.cdx-move-tab b{min-width:20px;padding:2px 5px;border-radius:999px;background:rgba(127,127,127,.09);font-size:7px;color:var(--text-tertiary,#9296a6)}
.cdx-move-tab:hover{border-color:rgba(124,130,255,.5)}
.cdx-move-tab.active{border-color:rgba(124,130,255,.55);background:rgba(124,130,255,.13);color:#f0f1ff}.cdx-move-tab.active b{background:rgba(124,130,255,.19);color:#d9dbff}
.cdx-move-toolbar{position:sticky;top:0;z-index:6;display:grid;grid-template-columns:minmax(130px,1fr) auto auto;gap:5px;padding:0 0 7px;background:linear-gradient(180deg,var(--bg-secondary,#171922) 82%,transparent)}
.cdx-btn.small{height:32px;padding:0 8px;font-size:8px}
.cdx-move-list{gap:4px}
.cdx-move-row{grid-template-columns:16px 22px 54px minmax(150px,1fr) minmax(72px,110px) 28px!important;gap:4px;align-items:center;padding:3px 2px;border-radius:6px;border:1px solid transparent}
.cdx-move-row:hover{background:rgba(255,255,255,.018);border-color:rgba(127,127,127,.09)}
.cdx-move-grip{color:var(--text-tertiary,#777c8d);font-size:9px;text-align:center;cursor:default}.cdx-move-name{font-size:7px;color:var(--text-tertiary,#858a9b);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.cdx-empty.compact{padding:12px 4px}
.cdx-ref-item{display:grid!important;grid-template-columns:minmax(82px,.55fr) minmax(0,1fr);gap:8px;align-items:center}
.cdx-ref-item strong{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.cdx-ref-item small{display:block;color:var(--text-tertiary,#8b90a0);font-size:8px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}

.cdx-migration-option.featured{border-color:rgba(124,130,255,.46);background:linear-gradient(135deg,rgba(124,130,255,.12),rgba(124,130,255,.035))}
.cdx-migration-stats{margin-top:4px;display:inline-flex;width:max-content;padding:3px 6px;border-radius:999px;background:rgba(124,130,255,.13);color:#cfd1ff;font-size:8px}

@media(max-width:1260px){.cdx-root{--left:240px;--right:360px}.cdx-main{grid-template-columns:var(--left) 5px minmax(390px,1fr) 5px var(--right)!important}.cdx-portrait{width:88px;height:88px;flex-basis:88px}.cdx-portrait canvas{width:88px;height:88px}.cdx-move-row{grid-template-columns:14px 20px 50px minmax(125px,1fr) 28px!important}.cdx-move-name{display:none}}
@media(max-width:1020px){.cdx-root{--left:220px;--right:330px}.cdx-main{min-width:940px}.cdx-toolbar .cdx-btn-soft,.cdx-toolbar .cdx-fullscreen-btn{display:inline-flex!important}.cdx-quick-nav{display:none}}


/* v0.4.0 — workflow / friendly-complete UI */
.cdx-library{grid-template-rows:auto auto auto auto minmax(0,1fr) auto!important}
.cdx-list-tools{display:grid;grid-template-columns:1fr 1fr;gap:5px;padding:6px 7px;border-bottom:1px solid var(--border,#343641);background:rgba(255,255,255,.008)}
.cdx-mini-select{min-width:0;height:28px;padding:0 6px;border:1px solid var(--border,#3b3e4a);border-radius:6px;background:var(--bg-secondary,#191b24);color:var(--text-secondary,#c4c7d3);font-size:8px}
.cdx-batchbar{display:grid;grid-template-columns:minmax(92px,1fr) auto auto;gap:5px;align-items:center;padding:6px 7px;border-bottom:1px solid rgba(124,130,255,.28);background:rgba(124,130,255,.075)}
.cdx-batchbar.hidden{display:none}.cdx-batchbar b{font-size:8px;color:#dfe1ff}.cdx-batchbar .danger{grid-column:1/-1;color:#ffc0c7;border-color:rgba(230,94,112,.4)}
.cdx-manage-toggle{margin-left:auto}.cdx-manage-toggle.active{border-color:rgba(124,130,255,.68)!important;background:rgba(124,130,255,.16)!important;color:#fff!important}
.cdx-row{transition:background .08s,border-color .08s}.cdx-row.multi-selected{background:rgba(124,130,255,.13)!important;box-shadow:inset 3px 0 0 var(--accent,#7c82ff)}
.cdx-multi-check{width:14px;height:14px;accent-color:var(--accent,#7c82ff);margin:0 2px 0 0}.cdx-list.manage-mode .cdx-row{grid-template-columns:18px 40px minmax(0,1fr) auto}
.cdx-row.compact{min-height:37px}.cdx-row.compact .cdx-icon-shell{width:30px;height:30px}.cdx-row.compact .cdx-icon{width:30px;height:30px}.cdx-row.compact small{display:none}
.cdx-row.detail{min-height:58px;padding-top:5px;padding-bottom:5px}.cdx-row.detail .cdx-icon-shell{width:46px;height:46px}.cdx-row.detail .cdx-icon{width:46px;height:46px}
.cdx-row-title{display:flex;align-items:center;gap:4px;min-width:0}.cdx-row-title b{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.cdx-row-title .cdx-type-badge{font-size:5px;padding:1px 3px;letter-spacing:.03em}
.cdx-summary-strip.friendly{grid-template-columns:repeat(3,minmax(0,1fr));gap:7px}.cdx-summary-strip.friendly .cdx-summary-metric{min-height:66px;justify-content:center}.cdx-summary-strip.friendly .cdx-summary-metric b{font-size:12px;line-height:1.15;white-space:normal}
.cdx-changes-card.friendly{margin-top:8px}.cdx-change-nav{height:26px;padding:0 8px;border:1px solid rgba(124,130,255,.22);border-radius:999px;background:rgba(124,130,255,.09);color:#dfe1ff;font-size:8px;cursor:pointer}.cdx-change-nav:hover{background:rgba(124,130,255,.18)}
.cdx-compare-details{margin-top:8px;border:1px solid var(--border,#353846);border-radius:9px;background:rgba(255,255,255,.01);overflow:hidden}.cdx-compare-details>summary{cursor:pointer;padding:10px 12px;color:var(--text-secondary,#c6c9d4);font-size:9px;font-weight:650;user-select:none}.cdx-compare-details[open]>summary{border-bottom:1px solid var(--border,#353846)}.cdx-compare-details .cdx-compare-grid{padding:8px}
.cdx-stat-input{position:relative}.cdx-stat-input.changed:after{content:"Modificado";position:absolute;right:4px;top:4px;padding:1px 4px;border-radius:999px;background:rgba(124,130,255,.14);color:#cfd1ff;font-size:6px}
.cdx-entity-manager{height:100%;display:grid;grid-template-rows:auto minmax(0,1fr);gap:8px;color:var(--text-primary,#eee)}.cdx-entity-top{display:grid;grid-template-columns:auto minmax(220px,1fr);gap:8px}.cdx-entity-tabs{display:flex;gap:5px}.cdx-entity-grid{display:grid;grid-template-columns:300px minmax(0,1fr);min-height:0;border:1px solid var(--border,#383b48);border-radius:10px;overflow:hidden}.cdx-entity-list{min-height:0;overflow:auto;border-right:1px solid var(--border,#383b48);padding:5px;background:rgba(0,0,0,.09)}.cdx-entity-row{display:grid;width:100%;text-align:left;gap:2px;padding:7px 8px;border:1px solid transparent;border-radius:6px;background:transparent;color:inherit;cursor:pointer}.cdx-entity-row:hover{background:rgba(255,255,255,.025)}.cdx-entity-row.active{background:rgba(124,130,255,.13);border-color:rgba(124,130,255,.35)}.cdx-entity-row.changed:before{content:"";position:absolute}.cdx-entity-row b{font-size:9px}.cdx-entity-row small{font-size:7px;color:var(--text-tertiary,#8e92a2)}
.cdx-entity-editor{min-height:0;overflow:auto;padding:12px}.cdx-entity-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:12px}.cdx-entity-head h2{margin:0 0 3px;font-size:17px}.cdx-entity-head code{font-size:8px;color:var(--text-tertiary,#8e92a2)}.cdx-entity-field{display:grid;grid-template-columns:180px minmax(0,1fr);gap:9px;align-items:start;padding:7px 0;border-bottom:1px solid rgba(127,127,127,.08)}.cdx-entity-field.changed{background:linear-gradient(90deg,rgba(124,130,255,.06),transparent)}.cdx-entity-label{display:grid;gap:3px}.cdx-entity-label b{font-size:9px}.cdx-entity-label small{font-size:7px;color:var(--text-tertiary,#858a9b);line-height:1.35}.cdx-textarea{min-height:58px;resize:vertical}.cdx-entity-notes{display:grid;gap:6px;margin:12px 0;padding:10px;border:1px solid rgba(255,199,89,.2);border-radius:8px;background:rgba(255,199,89,.035)}.cdx-entity-notes h3{margin:0;font-size:10px}.cdx-entity-notes p{margin:0 0 4px;color:var(--text-tertiary,#8f93a2);font-size:8px;line-height:1.5}.cdx-entity-notes label{font-size:8px;color:var(--text-secondary,#bdc0cd)}
.cdx-config{display:grid;gap:10px;color:var(--text-primary,#eee)}.cdx-config h2{margin:0;font-size:17px}.cdx-config p{margin:0 0 4px;font-size:9px;color:var(--text-tertiary,#8d91a0);line-height:1.5}.cdx-config-row{display:grid;grid-template-columns:190px minmax(0,1fr);gap:10px;align-items:center;padding:5px 0}.cdx-config-row>span{font-size:9px;color:var(--text-secondary,#c3c6d1)}
@media(max-width:1260px){.cdx-summary-strip.friendly{grid-template-columns:repeat(2,minmax(0,1fr))}.cdx-list-tools{grid-template-columns:1fr}.cdx-entity-grid{grid-template-columns:250px minmax(0,1fr)}}

/* v0.5.0 — panel-aware responsive layout. Maker Studio panels are not the browser viewport. */
.cdx-root{min-height:0!important}
.cdx-close-fullscreen{display:none!important;color:#ffc0c7!important;border-color:rgba(230,94,112,.35)!important}.cdx-close-fullscreen.visible{display:inline-flex!important}
.cdx-root:not(.cdx-fullscreen-active) .cdx-close-fullscreen{display:none!important}
.cdx-main{min-width:0!important;overflow:hidden}
.cdx-library,.cdx-center,.cdx-inspector{min-width:0!important;min-height:0!important}
.cdx-layout-medium .cdx-main,.cdx-layout-narrow .cdx-main{grid-template-columns:minmax(190px,25%) minmax(0,1fr)!important;grid-template-rows:minmax(270px,1.05fr) minmax(255px,.95fr)!important}
.cdx-layout-medium .cdx-library,.cdx-layout-narrow .cdx-library{grid-column:1;grid-row:1/3}
.cdx-layout-medium .cdx-center,.cdx-layout-narrow .cdx-center{grid-column:2;grid-row:1}
.cdx-layout-medium .cdx-inspector,.cdx-layout-narrow .cdx-inspector{grid-column:2;grid-row:2;border-top:1px solid var(--border,#343641)!important}
.cdx-layout-medium .cdx-resizer,.cdx-layout-narrow .cdx-resizer{display:none!important}
.cdx-layout-medium .cdx-toolbar,.cdx-layout-narrow .cdx-toolbar{gap:5px;padding-left:8px;padding-right:8px;overflow-x:auto;scrollbar-width:thin}
.cdx-layout-medium .cdx-brand,.cdx-layout-narrow .cdx-brand{min-width:185px}.cdx-layout-medium .cdx-sub,.cdx-layout-narrow .cdx-sub{display:none}
.cdx-layout-medium .cdx-brand-icon,.cdx-layout-narrow .cdx-brand-icon{width:30px;height:30px}.cdx-layout-medium .cdx-btn,.cdx-layout-narrow .cdx-btn{height:29px;padding:0 8px;font-size:9px}
.cdx-layout-medium .cdx-badge,.cdx-layout-narrow .cdx-badge{display:none}.cdx-layout-medium .cdx-center-head{min-height:104px;padding:7px 10px}.cdx-layout-medium .cdx-portrait{width:80px;height:80px;flex-basis:80px}.cdx-layout-medium .cdx-portrait canvas{width:80px;height:80px}
.cdx-layout-medium .cdx-summary-strip.friendly,.cdx-layout-narrow .cdx-summary-strip.friendly{grid-template-columns:repeat(3,minmax(0,1fr))}
.cdx-layout-narrow .cdx-main{grid-template-columns:178px minmax(0,1fr)!important;grid-template-rows:minmax(250px,1fr) minmax(270px,1fr)!important}.cdx-layout-narrow .cdx-list-tools{grid-template-columns:1fr}.cdx-layout-narrow .cdx-filterbar{overflow-x:auto}.cdx-layout-narrow .cdx-center-head{min-height:86px;padding:6px 8px;gap:8px}.cdx-layout-narrow .cdx-portrait{width:66px;height:66px;flex-basis:66px;border-radius:12px}.cdx-layout-narrow .cdx-portrait canvas{width:66px;height:66px}.cdx-layout-narrow .cdx-name h2{font-size:15px}.cdx-layout-narrow .cdx-summary-strip.friendly{grid-template-columns:repeat(2,minmax(0,1fr))}.cdx-layout-narrow .cdx-comparison{padding:7px}.cdx-layout-narrow .cdx-inspect-body{padding:7px}.cdx-layout-narrow .cdx-toolbar .cdx-brand-copy{display:none}.cdx-layout-narrow .cdx-brand{min-width:34px}.cdx-layout-narrow .cdx-row{grid-template-columns:38px minmax(0,1fr) auto;gap:4px;padding-left:4px;padding-right:4px}.cdx-layout-narrow .cdx-row-title .cdx-type-badge{display:none}
@media(max-width:1020px){.cdx-main{min-width:0!important}}
.cdx-config-note{padding:8px 10px;border:1px solid rgba(124,130,255,.2);border-radius:8px;background:rgba(124,130,255,.055);font-size:8px;color:var(--text-secondary,#c3c6d1);line-height:1.45}.cdx-config-heading{margin:4px 0 0;font-size:10px}.cdx-color-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px}.cdx-color-item{display:grid;grid-template-columns:minmax(0,1fr) 34px;grid-template-rows:auto auto;gap:2px 7px;align-items:center;padding:7px;border:1px solid rgba(127,127,127,.12);border-radius:7px;background:rgba(255,255,255,.018)}.cdx-color-item span{font-size:8px;color:var(--text-secondary,#c3c6d1)}.cdx-color-item code{font-size:7px;color:var(--text-tertiary,#8d91a0)}.cdx-color-input{grid-column:2;grid-row:1/3;width:34px;height:30px;padding:1px;border:1px solid var(--border,#3b3e4a);border-radius:5px;background:transparent}.cdx-config-actions{display:flex;justify-content:flex-end;gap:7px;padding-top:3px}

/* v0.6.0 — responsive without forcing the user to stretch Maker Studio. */
.cdx-root{grid-template-rows:auto minmax(0,1fr) 28px!important;min-width:0!important}
.cdx-toolbar{display:grid!important;grid-template-columns:auto minmax(0,1fr)!important;align-items:center!important;gap:8px!important;height:auto!important;min-height:54px!important;overflow:visible!important;padding:7px 10px!important}
.cdx-toolbar-actions{min-width:0;display:flex;align-items:center;justify-content:flex-end;gap:6px;flex-wrap:wrap}
.cdx-toolbar-actions .cdx-btn{flex:0 0 auto}.cdx-toolbar-actions .cdx-badge{flex:0 0 auto}
.cdx-brand{min-width:220px!important}.cdx-filterbar{flex-wrap:wrap!important;overflow:visible!important;align-content:flex-start}.cdx-chip{flex:0 0 auto}
.cdx-tabs{flex-wrap:wrap!important;overflow:visible!important;scrollbar-width:none!important}.cdx-tab{flex:1 1 58px;min-width:0;text-align:center;padding-left:5px!important;padding-right:5px!important}
.cdx-main{grid-template-columns:minmax(230px,var(--left)) 5px minmax(0,1fr) 5px minmax(330px,var(--right))!important}
.cdx-center-head{min-width:0}.cdx-name{flex:1 1 auto}.cdx-center-head>.cdx-btn{flex:0 0 auto}
.cdx-entity-top{grid-template-columns:auto auto minmax(180px,1fr)!important;align-items:center}.cdx-entity-tabs{min-width:max-content}
.cdx-color-grid{grid-template-columns:repeat(auto-fit,minmax(155px,1fr))!important}
.cdx-layout-medium .cdx-toolbar,.cdx-layout-narrow .cdx-toolbar{overflow:visible!important;display:grid!important;grid-template-columns:1fr!important;gap:5px!important}
.cdx-layout-medium .cdx-toolbar-actions,.cdx-layout-narrow .cdx-toolbar-actions{justify-content:flex-start!important}
.cdx-layout-medium .cdx-brand,.cdx-layout-narrow .cdx-brand{min-width:0!important}.cdx-layout-medium .cdx-brand-copy{display:block!important}
.cdx-layout-medium .cdx-main{grid-template-columns:minmax(210px,27%) minmax(0,1fr)!important;grid-template-rows:minmax(300px,1.08fr) minmax(250px,.92fr)!important}
.cdx-layout-narrow .cdx-main{grid-template-columns:minmax(170px,24%) minmax(0,1fr)!important;grid-template-rows:minmax(280px,1fr) minmax(265px,1fr)!important}
.cdx-layout-medium .cdx-filterbar,.cdx-layout-narrow .cdx-filterbar{overflow:visible!important}
.cdx-layout-medium .cdx-tabs,.cdx-layout-narrow .cdx-tabs{padding:5px!important;gap:2px!important}.cdx-layout-medium .cdx-tab,.cdx-layout-narrow .cdx-tab{font-size:8px!important;padding-top:4px!important;padding-bottom:4px!important}
@media(max-width:1060px){.cdx-entity-top{grid-template-columns:1fr 1fr!important}.cdx-entity-top .cdx-search{grid-column:1/-1}.cdx-entity-grid{grid-template-columns:220px minmax(0,1fr)!important}.cdx-config-row{grid-template-columns:150px minmax(0,1fr)!important}}
@media(max-width:760px){.cdx-toolbar-actions{justify-content:flex-start}.cdx-brand-copy{display:block!important}.cdx-entity-grid{grid-template-columns:1fr!important;grid-template-rows:190px minmax(0,1fr)}.cdx-entity-list{border-right:0!important;border-bottom:1px solid var(--border,#383b48)}.cdx-entity-field{grid-template-columns:1fr!important}}


/* v0.7.0 — expand inside Maker Studio instead of covering the application. */
.cdx-panel-expanded{height:100%!important;max-height:100%!important;min-height:0!important}
.cdx-panel-expanded .cdx-main{grid-template-columns:minmax(250px,300px) 5px minmax(0,1fr) 5px minmax(330px,400px)!important}
.cdx-dialog-head{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;padding:10px 12px;border:1px solid rgba(124,130,255,.18);border-radius:10px;background:linear-gradient(135deg,rgba(124,130,255,.08),rgba(255,255,255,.015))}
.cdx-dialog-head h2{margin:0 0 4px;font-size:16px}.cdx-dialog-head p{margin:0;color:var(--text-tertiary,#969aaa);font-size:8px;line-height:1.5;max-width:720px}
.cdx-locale-manager{height:100%;min-height:0;display:grid;grid-template-rows:auto auto minmax(0,1fr);gap:9px;color:var(--text-primary,#eee)}
.cdx-locale-tools{display:grid;grid-template-columns:auto auto minmax(220px,1fr);gap:8px;align-items:center;padding:8px;border:1px solid var(--border,#383b48);border-radius:9px;background:rgba(0,0,0,.08)}
.cdx-locale-grid{min-height:0;display:grid;grid-template-columns:320px minmax(0,1fr);overflow:hidden;border:1px solid var(--border,#383b48);border-radius:10px;background:rgba(0,0,0,.05)}
.cdx-locale-textarea{min-height:110px!important}
.cdx-entity-manager{padding:2px}.cdx-entity-top{padding:8px;border:1px solid var(--border,#383b48);border-radius:9px;background:rgba(0,0,0,.07)}
.cdx-entity-editor>.cdx-config-note{margin-bottom:10px}
@media(max-width:980px){.cdx-locale-tools{grid-template-columns:1fr 1fr}.cdx-locale-tools .cdx-search{grid-column:1/-1}.cdx-locale-grid{grid-template-columns:250px minmax(0,1fr)}}
@media(max-width:720px){.cdx-locale-grid{grid-template-columns:1fr;grid-template-rows:190px minmax(0,1fr)}}


/* v0.8.0 — editor-first workspace, stable search and real panel maximize. */
.cdx-toolbar-lang{height:32px;max-width:154px;padding:0 8px;border:1px solid var(--border,#3d4050);border-radius:7px;background:var(--bg-secondary,#1a1c25);color:var(--text-secondary,#c7cad6);font-size:9px}
/* Editing belongs in the large middle pane; the Pokémon overview is contextual support on the right. */
.cdx-main{grid-template-columns:var(--left) 5px minmax(520px,1fr) 5px var(--right)!important}
.cdx-inspector{grid-column:3!important;grid-row:1!important;border-left:0!important;border-right:1px solid var(--border,#343641)!important}
.cdx-resizer-left{grid-column:2!important;grid-row:1!important}.cdx-resizer-right{grid-column:4!important;grid-row:1!important}
.cdx-center{grid-column:5!important;grid-row:1!important;background:linear-gradient(180deg,rgba(124,130,255,.035),transparent 38%),var(--bg-secondary,#171922)}
.cdx-center-head{flex-wrap:wrap;align-content:center;min-height:144px}.cdx-center-head .cdx-spacer{display:none}.cdx-center-head>.cdx-btn{height:29px}
.cdx-comparison{padding:10px}.cdx-summary-strip.friendly{grid-template-columns:repeat(2,minmax(0,1fr))!important}.cdx-changes-card.friendly{grid-column:1/-1}
.cdx-panel-expanded{--left:280px;--right:370px;width:100%!important;height:100%!important;min-height:0!important}
.cdx-maker-maximized{overflow:hidden!important}
.cdx-panel-expanded .cdx-main{grid-template-columns:var(--left) 5px minmax(620px,1fr) 5px var(--right)!important}
.cdx-panel-expanded .cdx-inspect-body{padding:14px}.cdx-panel-expanded .cdx-group{padding:12px}
.cdx-section-copy-editor{display:grid;grid-template-columns:1fr 1fr;gap:10px}.cdx-section-copy-col{display:grid;gap:6px;padding:8px;border:1px solid var(--border,#383b48);border-radius:9px;background:rgba(0,0,0,.06)}.cdx-section-copy-col h4{margin:0 0 3px}.cdx-section-copy-item{display:grid;gap:4px}.cdx-section-copy-item span{font-size:8px;color:var(--text-secondary,#c3c6d1)}.cdx-section-copy{min-height:48px!important;resize:vertical;font-size:8px!important}
.cdx-config{padding-right:4px}.cdx-config-row:has(textarea){align-items:start}
@media(max-width:1200px){.cdx-main{grid-template-columns:minmax(210px,25%) 5px minmax(0,1fr)!important;grid-template-rows:minmax(310px,1.05fr) minmax(260px,.95fr)!important}.cdx-library{grid-column:1!important;grid-row:1/3!important}.cdx-resizer{display:none!important}.cdx-inspector{grid-column:2!important;grid-row:1!important;border-right:0!important}.cdx-center{grid-column:2!important;grid-row:2!important;border-top:1px solid var(--border,#343641)!important}.cdx-center-head{min-height:94px;padding:7px 10px}.cdx-portrait{width:74px!important;height:74px!important;flex-basis:74px!important}.cdx-portrait canvas{width:74px!important;height:74px!important}.cdx-comparison{padding:7px}.cdx-summary-strip.friendly{grid-template-columns:repeat(3,minmax(0,1fr))!important}}
@media(max-width:820px){.cdx-main{grid-template-columns:190px minmax(0,1fr)!important}.cdx-summary-strip.friendly{grid-template-columns:repeat(2,minmax(0,1fr))!important}.cdx-toolbar-lang{max-width:135px}.cdx-section-copy-editor{grid-template-columns:1fr}}

.cdx-panel-expanded .cdx-close-fullscreen.visible{display:inline-flex!important}


/* v0.9.0 — BAS-style fullscreen + clearer editor hierarchy. */
body.cdx-fullscreen-lock{overflow:hidden!important;overscroll-behavior:none!important}
.cdx-root.cdx-fullscreen-active{
  position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;
  min-width:0!important;min-height:0!important;max-width:none!important;max-height:none!important;
  margin:0!important;border:0!important;border-radius:0!important;z-index:5000!important;
  box-shadow:none!important;background:var(--bg-primary,#12131a)!important
}
@supports(height:100dvh){.cdx-root.cdx-fullscreen-active{height:100dvh!important}}
.cdx-root.cdx-fullscreen-active .cdx-close-fullscreen.visible{display:inline-flex!important}
.cdx-root.cdx-fullscreen-active .cdx-toolbar{padding-left:12px!important;padding-right:12px!important}

/* Selected Pokémon identity belongs above the actual editor. */
.cdx-main{grid-template-columns:minmax(245px,var(--left)) 5px minmax(520px,1fr) 5px minmax(320px,var(--right))!important}
.cdx-inspector{
  grid-column:3!important;grid-row:1!important;display:grid!important;
  grid-template-rows:auto auto minmax(0,1fr)!important;min-width:0!important;
  border-left:0!important;border-right:1px solid var(--border,#343641)!important;
  background:var(--bg-primary,#12131a)!important
}
.cdx-center{grid-column:5!important;grid-row:1!important;min-width:0!important}
.cdx-center-head{
  min-height:108px!important;padding:10px 14px!important;border-bottom:1px solid var(--border,#343641)!important;
  background:linear-gradient(90deg,rgba(124,130,255,.055),transparent 68%)!important
}
.cdx-tabs{position:relative!important;z-index:2!important;border-bottom:1px solid var(--border,#343641)!important}
.cdx-inspect-body{min-height:0!important;overflow:auto!important;padding:12px!important}
.cdx-comparison{min-height:0!important;overflow:auto!important;padding:12px!important}
.cdx-summary-strip.friendly{grid-template-columns:1fr!important;gap:8px!important}
.cdx-summary-metric{min-height:76px!important}
.cdx-changes-card.friendly{margin-top:8px!important}

/* The global Move/Ability editor had three children but only two grid rows,
   which caused its tabs/new button to overlap the first record. */
.cdx-entity-manager{
  height:100%!important;min-height:0!important;display:grid!important;
  grid-template-rows:auto auto minmax(0,1fr)!important;gap:9px!important
}
.cdx-entity-top{
  display:grid!important;grid-template-columns:minmax(210px,auto) auto minmax(240px,1fr)!important;
  align-items:center!important;gap:8px!important;padding:8px!important
}
.cdx-entity-tabs{display:flex!important;gap:5px!important;min-width:0!important}
.cdx-entity-tabs .cdx-btn{min-width:104px!important}
.cdx-entity-grid{min-height:0!important;grid-template-columns:minmax(235px,290px) minmax(0,1fr)!important}
.cdx-entity-list{scrollbar-gutter:stable!important}
.cdx-entity-row{position:relative!important;padding:8px 10px!important}
.cdx-entity-editor{padding:14px 16px!important}
.cdx-entity-field{grid-template-columns:minmax(150px,190px) minmax(0,1fr)!important}

/* Bulk-management controls should remain readable instead of becoming a
   compressed strip when more actions are available. */
.cdx-batchbar{display:flex!important;flex-wrap:wrap!important;align-items:center!important;gap:5px!important}
.cdx-batchbar.hidden{display:none!important}

/* Fullscreen gets the spacious three-pane workspace; normal narrow panels
   gracefully stack the context below editing instead of crushing fields. */
.cdx-fullscreen-active{--left:275px;--right:345px}
.cdx-fullscreen-active .cdx-main{grid-template-columns:var(--left) 5px minmax(600px,1fr) 5px var(--right)!important}
@media(max-width:1180px){
  .cdx-root:not(.cdx-fullscreen-active) .cdx-main{
    grid-template-columns:minmax(205px,25%) 5px minmax(0,1fr)!important;
    grid-template-rows:minmax(380px,1fr) minmax(220px,.55fr)!important
  }
  .cdx-root:not(.cdx-fullscreen-active) .cdx-library{grid-column:1!important;grid-row:1/3!important}
  .cdx-root:not(.cdx-fullscreen-active) .cdx-resizer{display:none!important}
  .cdx-root:not(.cdx-fullscreen-active) .cdx-inspector{grid-column:3!important;grid-row:1!important;border-right:0!important}
  .cdx-root:not(.cdx-fullscreen-active) .cdx-center{grid-column:3!important;grid-row:2!important;border-top:1px solid var(--border,#343641)!important}
  .cdx-root:not(.cdx-fullscreen-active) .cdx-summary-strip.friendly{grid-template-columns:repeat(3,minmax(0,1fr))!important}
}
@media(max-width:760px){
  .cdx-entity-top{grid-template-columns:1fr!important}
  .cdx-entity-grid{grid-template-columns:1fr!important;grid-template-rows:190px minmax(0,1fr)!important}
}


/* v0.9.0 — workspace polish + ShadowRoot-safe fullscreen */
.cdx-root.cdx-fullscreen-active{
  position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;
  min-width:0!important;min-height:0!important;max-width:none!important;max-height:none!important;
  margin:0!important;border:0!important;border-radius:0!important;z-index:5000!important;
  box-shadow:none!important;background:var(--bg-primary,#12131a)!important;
  grid-template-rows:auto minmax(0,1fr) 26px!important;
}
@supports(height:100dvh){.cdx-root.cdx-fullscreen-active{height:100dvh!important}}
.cdx-root.cdx-fullscreen-active .cdx-toolbar{min-height:62px!important;overflow:visible!important}
.cdx-root.cdx-fullscreen-active .cdx-toolbar-actions{flex-wrap:wrap!important;row-gap:5px!important}
.cdx-root.cdx-fullscreen-active .cdx-main{min-height:0!important;height:auto!important}
.cdx-toolbar-lang{height:32px;max-width:190px;border:1px solid var(--border,#3d4050);border-radius:7px;background:var(--bg-secondary,#1a1c25);color:inherit;padding:0 8px;font:inherit;font-weight:700}
.cdx-center{background:var(--bg-primary,#12131a)!important}
.cdx-comparison{background:linear-gradient(180deg,rgba(124,130,255,.02),transparent 32%)!important}
.cdx-inspector{background:var(--bg-secondary,#171922)!important}
.cdx-center-head{border-bottom:1px solid var(--border,#343641)!important}
.cdx-tabs{padding:6px 10px!important;gap:5px!important}
.cdx-tab{min-height:30px!important;padding:6px 11px!important}
.cdx-inspect-body{padding:14px!important}
.cdx-center .cdx-card,.cdx-inspector .cdx-group{box-shadow:0 1px 0 rgba(255,255,255,.018) inset!important}
.cdx-entity-manager{padding:4px!important}
.cdx-entity-top{border:1px solid var(--border,#343641)!important;border-radius:9px!important;background:rgba(255,255,255,.018)!important}
.cdx-entity-grid{border:1px solid var(--border,#343641)!important;border-radius:10px!important;overflow:hidden!important;background:var(--bg-primary,#12131a)!important}
.cdx-entity-list{background:var(--bg-secondary,#171922)!important;border-right:1px solid var(--border,#343641)!important}
.cdx-entity-editor{background:var(--bg-primary,#12131a)!important}
.cdx-locale-textarea{min-height:72px!important}
@media(max-width:1180px){
  .cdx-root:not(.cdx-fullscreen-active) .cdx-toolbar{align-items:flex-start!important;height:auto!important;min-height:68px!important}
  .cdx-root:not(.cdx-fullscreen-active) .cdx-toolbar-actions{overflow-x:auto!important;flex-wrap:nowrap!important;padding-bottom:3px!important}
}

/* v0.10 entity blacklist management */
.cdx-entity-row.hidden-in-dex{opacity:.62}
.cdx-entity-row.multi-selected{outline:1px solid rgba(112,118,255,.72);background:rgba(112,118,255,.12)}
.cdx-manage-check{display:inline-flex;width:18px;justify-content:center;align-items:center;margin-right:4px;color:#aeb3ff}
.cdx-entity-head-actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap;justify-content:flex-end}

/* v0.10.4 · gestores de limpieza/localización: no comprimir controles en columnas imposibles */
.cdx-entity-top{display:flex!important;flex-wrap:wrap!important;align-items:center!important;gap:7px!important;grid-template-columns:none!important}
.cdx-entity-top .cdx-search{flex:1 1 220px!important;min-width:180px}
.cdx-entity-top .cdx-mini-select{flex:0 1 150px;min-width:118px}
.cdx-locale-tools{display:flex!important;flex-wrap:wrap!important;align-items:center!important;gap:7px!important;grid-template-columns:none!important}
.cdx-locale-tools .cdx-search{flex:1 1 240px!important;min-width:200px}
.cdx-locale-tools .cdx-mini-select{flex:0 1 160px;min-width:125px}
.cdx-entity-row.imported-change{box-shadow:inset 2px 0 0 rgba(255,185,85,.55)}

.cdx-language-runtime-bar{display:grid;grid-template-columns:max-content 220px max-content 1fr;gap:10px;align-items:center;padding:10px 12px;margin:0 0 10px;border:1px solid var(--cdx-border,#34364e);border-radius:10px;background:rgba(255,255,255,.025)}
.cdx-language-toggle{display:flex;align-items:center;gap:8px;font-weight:700;white-space:nowrap}.cdx-language-toggle input{accent-color:#7774ff}.cdx-language-runtime-bar .cdx-config-note{margin:0;padding:0;background:none;border:0}
.cdx-intl-bridge{display:grid;gap:6px;padding:11px 13px;margin:0 0 10px;border:1px solid var(--cdx-border,#34364e);border-radius:10px;background:rgba(92,104,255,.055)}
.cdx-intl-bridge>b{font-size:13px}.cdx-intl-bridge>span{font-size:12px;line-height:1.45;color:var(--text-muted,#a6a8b3)}
@media(max-width:900px){.cdx-language-runtime-bar{grid-template-columns:1fr}.cdx-language-toggle{white-space:normal}}

/* v0.11.14 · new Move visibility */
.cdx-entity-row.new-entity{border-color:rgba(100,255,120,.34)!important;background:linear-gradient(90deg,rgba(100,255,120,.10),rgba(100,255,120,.025))!important;box-shadow:inset 3px 0 0 rgba(100,255,120,.72)}
.cdx-entity-titleline{display:flex;align-items:center;gap:6px;min-width:0}.cdx-entity-titleline b{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cdx-entity-new-badge,.cdx-inline-new-badge{display:inline-flex;align-items:center;flex:0 0 auto;border:1px solid rgba(100,255,120,.42);background:rgba(100,255,120,.11);color:#83ff94;border-radius:999px;padding:1px 5px;font-size:7px;font-weight:800;letter-spacing:.35px}
.cdx-move-row.new-global-move,.cdx-list-edit-row.new-global-move{border-color:rgba(100,255,120,.34)!important;background:linear-gradient(90deg,rgba(100,255,120,.08),transparent)!important;box-shadow:inset 2px 0 0 rgba(100,255,120,.65)}
.cdx-move-row.added-move:not(.new-global-move){border-color:rgba(241,190,109,.22)!important;background:rgba(241,190,109,.035)}
.cdx-move-name{display:flex;align-items:center;gap:5px;min-width:0}.cdx-move-name>.cdx-inline-new-badge{margin-left:3px}


/* v0.11.16 · CANON vs JSON provenance + ACL-safe in-Studio dialogs */
.cdx-root{position:relative!important}
.cdx-origin-legend{display:flex;align-items:center;gap:5px;flex-wrap:wrap;margin:4px 0 8px;padding:6px 7px;border:1px solid rgba(127,127,127,.11);border-radius:7px;background:rgba(255,255,255,.014)}
.cdx-origin-legend.compact{padding:4px 6px;margin:3px 0 6px}
.cdx-origin-legend.entity-manager{margin:0;padding:6px 9px;background:rgba(255,255,255,.018)}
.cdx-origin-badges{display:inline-flex;align-items:center;justify-content:flex-end;gap:4px;flex-wrap:wrap;min-width:72px}
.cdx-origin-badge{display:inline-flex;align-items:center;flex:0 0 auto;min-height:17px;padding:1px 6px;border-radius:999px;font-size:7px;font-weight:850;letter-spacing:.045em;white-space:nowrap;border:1px solid rgba(127,127,127,.25);background:rgba(127,127,127,.08);color:#c9ccd7}
.cdx-origin-badge.canon{border-color:rgba(91,177,255,.38);background:rgba(72,152,225,.09);color:#8fcaff}
.cdx-origin-badge.json{border-color:rgba(241,190,109,.42);background:rgba(241,190,109,.10);color:#f2c67a}
.cdx-origin-badge.level{border-color:rgba(197,147,255,.42);background:rgba(197,147,255,.10);color:#d5aaff}
.cdx-origin-badge.retouched{border-color:rgba(255,150,87,.48);background:rgba(255,132,64,.11);color:#ffad78}
.cdx-origin-badge.new{border-color:rgba(100,255,120,.44);background:rgba(100,255,120,.10);color:#87ff98}
.cdx-label-left>.cdx-origin-badge{margin-left:2px}
.cdx-list-edit-row.cdx-provenance-row{grid-template-columns:minmax(0,1fr) minmax(72px,auto) 28px!important;align-items:center}
.cdx-evo-row.cdx-provenance-row{grid-template-columns:minmax(100px,1fr) 105px minmax(76px,.7fr) minmax(64px,auto) 28px!important;align-items:center}
.cdx-move-row.cdx-provenance-row .cdx-move-name{gap:4px;flex-wrap:wrap;line-height:1.15}
.cdx-assignment-diff{display:grid;gap:5px;margin-top:6px;padding:7px;border:1px solid rgba(241,190,109,.16);border-radius:7px;background:rgba(241,190,109,.035)}
.cdx-assignment-diff.empty{display:none}
.cdx-assignment-diff>b{font-size:8px;color:#e8bd72;text-transform:uppercase;letter-spacing:.05em}
.cdx-assignment-diff-chips{display:flex;gap:4px;flex-wrap:wrap}
.cdx-assignment-diff-chip{display:inline-flex;align-items:center;padding:2px 6px;border-radius:5px;font-size:7px;border:1px solid rgba(127,127,127,.18);background:rgba(127,127,127,.05);color:var(--text-secondary,#c4c7d0)}
.cdx-assignment-diff-chip.removed{border-color:rgba(224,105,118,.26);background:rgba(224,105,118,.07);color:#eba4ac}
.cdx-assignment-diff-chip.moved{border-color:rgba(197,147,255,.26);background:rgba(197,147,255,.07);color:#d6b1ff}
.cdx-entity-row.retouched-entity{box-shadow:inset 3px 0 0 rgba(255,132,64,.58);background:linear-gradient(90deg,rgba(255,132,64,.065),transparent)}
.cdx-entity-idline{display:flex;align-items:center;gap:7px;margin-top:3px;flex-wrap:wrap}
.cdx-provenance-banner{margin:0 0 9px;padding:8px 10px;border-radius:7px;border:1px solid rgba(127,127,127,.15);font-size:8px;line-height:1.45}
.cdx-provenance-banner.canon{border-color:rgba(91,177,255,.22);background:rgba(72,152,225,.055);color:#b6ddff}
.cdx-provenance-banner.retouched{border-color:rgba(255,150,87,.24);background:rgba(255,132,64,.06);color:#ffc19a}
.cdx-provenance-banner.new{border-color:rgba(100,255,120,.22);background:rgba(100,255,120,.055);color:#b7ffc0}
/* 4 children: header, provenance legend, controls, catalog/editor */
.cdx-entity-manager{grid-template-rows:auto auto auto minmax(0,1fr)!important}

/* Browser confirm/prompt can be routed through forbidden ACL commands.
   This local overlay never leaves ChangeDex Studio. */
.cdx-acl-modal-layer{position:absolute;inset:0;z-index:2147483000;display:grid;place-items:center;padding:20px;background:rgba(5,6,10,.72);backdrop-filter:blur(2px)}
.cdx-acl-modal{width:min(520px,calc(100% - 24px));display:grid;gap:0;border:1px solid rgba(124,130,255,.34);border-radius:12px;overflow:hidden;background:var(--bg-secondary,#1a1c25);box-shadow:0 24px 70px rgba(0,0,0,.45)}
.cdx-acl-modal-head{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:11px 13px;border-bottom:1px solid var(--border,#343641);background:rgba(124,130,255,.055)}
.cdx-acl-modal-head>b{font-size:12px}
.cdx-acl-modal-x{width:26px;height:26px;border:0;border-radius:6px;background:transparent;color:var(--text-secondary,#c4c7d0);font-size:18px;cursor:pointer}
.cdx-acl-modal-x:hover{background:rgba(255,255,255,.055);color:#fff}
.cdx-acl-modal-body{display:grid;gap:10px;padding:14px}
.cdx-acl-modal-body p{margin:0;color:var(--text-secondary,#c4c7d0);font-size:10px;line-height:1.55}
.cdx-acl-modal-input{height:34px!important}
.cdx-acl-modal-actions{display:flex;justify-content:flex-end;gap:7px;padding:10px 13px;border-top:1px solid var(--border,#343641);background:rgba(255,255,255,.012)}
@media(max-width:1260px){
  .cdx-list-edit-row.cdx-provenance-row{grid-template-columns:minmax(0,1fr) 28px!important}
  .cdx-list-edit-row.cdx-provenance-row>.cdx-origin-badges{grid-column:1/2;justify-content:flex-start}
  .cdx-list-edit-row.cdx-provenance-row>.cdx-x{grid-column:2;grid-row:1}
  .cdx-evo-row.cdx-provenance-row{grid-template-columns:minmax(90px,1fr) 90px minmax(70px,.7fr) 28px!important}
  .cdx-evo-row.cdx-provenance-row>.cdx-origin-badges{grid-column:1/4;justify-content:flex-start}
  .cdx-evo-row.cdx-provenance-row>.cdx-x{grid-column:4;grid-row:1}
}
`;
