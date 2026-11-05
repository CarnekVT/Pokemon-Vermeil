import { renderBattleSceneStudio } from "./app.js";

var PANEL_ID="battle-scene-studio.main";
const BSS_DATA="Data/BattleSceneStudio/";
const ADDON_FILE=BSS_DATA+"scripted_battles.json";

// Show additive authored battles even when battles.json was last saved by an
// older Studio session. Recovery and edited primary Blueprints take priority.
// Only the BSS panel receives this scoped reader; no other MakerStudio mods
// or game files are monkey-patched.
function withScriptedBlueprints(ctx){
  if(!ctx||!ctx.fs||typeof ctx.fs.readProjectFile!=="function")return ctx;
  const scoped=Object.create(ctx);
  const fs=Object.create(ctx.fs);
  fs.readProjectFile=async function(path,...args){
    const value=await ctx.fs.readProjectFile(path,...args);
    const name=String(path||"").replace(/\\/g,"/");
    if(name!==BSS_DATA+"battles.json" && name!==BSS_DATA+"battles.recovery.json")return value;
    try{
      if(!await ctx.fs.projectExists(ADDON_FILE))return value;
      const addon=JSON.parse(String(await ctx.fs.readProjectFile(ADDON_FILE)));
      const data=JSON.parse(String(value));
      if(!data||typeof data!=="object")return value;
      data.groups=Array.isArray(data.groups)?data.groups:[];
      data.blueprints=Array.isArray(data.blueprints)?data.blueprints:[];
      for(const group of (Array.isArray(addon.groups)?addon.groups:[])){
        if(group&&group.id&&!data.groups.some(g=>g&&g.id===group.id))data.groups.push(group);
      }
      for(const battle of (Array.isArray(addon.blueprints)?addon.blueprints:[])){
        if(battle&&battle.key&&!data.blueprints.some(b=>b&&(b.key===battle.key||b.id===battle.id))){
          data.blueprints.push(battle);
        }
      }
      return JSON.stringify(data);
    }catch(err){
      ctx.log?.warn?.("BSS additional scripted battles: "+String(err&&err.message||err));
      return value;
    }
  };
  scoped.fs=fs;
  return scoped;
}

export function activate(ctx){
  ctx.log.info("Battle Scene Studio v0.8.36 activated");
  ctx.ui.registerPanel({id:PANEL_ID,title:"Battle Scene Studio",icon:"video",defaultPosition:"right",defaultSize:{width:1500,height:960},showInMenu:false,render:function(host){return renderBattleSceneStudio(withScriptedBlueprints(ctx),host);}});
  ctx.menu.registerMenuItem({menu:"Mods",label:"Battle Scene Studio",icon:"video",shortcut:"Ctrl+Shift+B",handler:function(){return ctx.ui.openPanel(PANEL_ID);}});
  ctx.commands.register("battle-scene-studio.open",function(){return ctx.ui.openPanel(PANEL_ID);});
}
