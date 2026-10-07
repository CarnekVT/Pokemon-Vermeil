import { renderBattleSceneStudio } from "./app.js";
var PANEL_ID="battle-scene-studio.main";
export function activate(ctx){
  ctx.log.info("Battle Scene Studio v0.8.24 activated · Phase 1 SOS + Boss/Totem aura");
  ctx.ui.registerPanel({id:PANEL_ID,title:"Battle Scene Studio",icon:"video",defaultPosition:"right",defaultSize:{width:1500,height:960},showInMenu:false,render:function(host){return renderBattleSceneStudio(ctx,host);}});
  ctx.menu.registerMenuItem({menu:"Mods",label:"Battle Scene Studio",icon:"video",shortcut:"Ctrl+Shift+B",handler:function(){return ctx.ui.openPanel(PANEL_ID);}});
  ctx.commands.register("battle-scene-studio.open",function(){return ctx.ui.openPanel(PANEL_ID);});
}
