// Commands registered in the native Maker Studio command picker (1.0.1+).
const BASE={page:"Pokémon Essentials",pageDescription:"Asistentes editables de Pokémon Essentials para eventos."};
const sym=v=>{const s=String(v??"").trim().replace(/^:/,"").toUpperCase();return /^[A-Z_][A-Z0-9_]*$/.test(s)?s:null;};
const num=(v,min,max)=>Math.min(max,Math.max(min,Number.isInteger(Number(v))?Number(v):min));
export function registerPickerCommands(ctx){
 if(typeof ctx.events?.registerCommand!=="function")return;
 const definitions=[
  {...BASE,id:"giveItem",name:"Entregar objeto Pokémon",
    fields:[{type:"text",key:"item",label:"Objeto PBS",default:"POTION"},
     {type:"number",key:"count",label:"Cantidad",default:1,min:1,max:999}],
    script:p=>"pbReceiveItem(:"+(sym(p.item)||"POTION")+", "+num(p.count,1,999)+")",
    parse:s=>{const m=/^pbReceiveItem\(:([A-Z0-9_]+),\s*(\d+)\)$/.exec(s.trim());return m?{item:m[1],count:Number(m[2])}:null;},
    summary:p=>"Entregar "+String(p.item||"POTION")+" ×"+p.count
  },
  {...BASE,id:"giftPokemon",name:"Regalar Pokémon",
    fields:[{type:"text",key:"species",label:"Especie PBS",default:"EEVEE"},
     {type:"number",key:"level",label:"Nivel",default:5,min:1,max:100}],
    script:p=>"pbAddPokemon(:"+(sym(p.species)||"EEVEE")+", "+num(p.level,1,100)+")",
    parse:s=>{const m=/^pbAddPokemon\(:([A-Z0-9_]+),\s*(\d+)\)$/.exec(s.trim());return m?{species:m[1],level:Number(m[2])}:null;},
    summary:p=>"Regalar "+String(p.species||"EEVEE")+" Nv."+p.level
  },
  {...BASE,id:"wildPokemon",name:"Combate Pokémon salvaje",
    fields:[{type:"text",key:"species",label:"Especie",default:"ZORUA"},
     {type:"number",key:"level",label:"Nivel",default:12,min:1,max:100}],
    script:p=>"WildBattle.start(:"+(sym(p.species)||"ZORUA")+", "+num(p.level,1,100)+")",
    parse:s=>{const m=/^WildBattle\.start\(:([A-Z0-9_]+),\s*(\d+)\)$/.exec(s.trim());return m?{species:m[1],level:Number(m[2])}:null;},
    summary:p=>"Salvaje "+String(p.species||"ZORUA")+" Nv."+p.level
  },
  {...BASE,id:"trainerBattle",name:"Combate de entrenador",
    fields:[{type:"text",key:"type",label:"Tipo entrenador PBS",default:"YOUNGSTER"},
     {type:"text",key:"name",label:"Nombre PBS",default:"Luis"},
     {type:"number",key:"version",label:"Versión",default:0,min:0,max:999}],
    script:p=>"TrainerBattle.start(:"+(sym(p.type)||"YOUNGSTER")+", "+JSON.stringify(String(p.name||"Luis"))+", "+num(p.version,0,999)+")",
    parse:s=>{const m=/^TrainerBattle\.start\(:([A-Z0-9_]+),\s*("(?:\\.|[^"\\])*"),\s*(\d+)\)$/.exec(s.trim());if(!m)return null;try{return{type:m[1],name:JSON.parse(m[2]),version:Number(m[3])};}catch{return null;}},
    summary:p=>"Entrenador "+String(p.type||"YOUNGSTER")+" "+String(p.name||"Luis")
  },
  {...BASE,id:"battleRule",name:"Regla del próximo combate",
    fields:[{type:"select",key:"rule",label:"Regla",default:"double",options:[
     {value:"single",label:"Individual"},{value:"double",label:"Doble"},
     {value:"triple",label:"Triple"},{value:"cannotrun",label:"Sin huida"},
     {value:"canlose",label:"Se puede perder"},{value:"disablebag",label:"Sin mochila"}]}],
    script:p=>"setBattleRule("+JSON.stringify(String(p.rule||"double"))+")",
    parse:s=>{const m=/^setBattleRule\(("(?:\\.|[^"\\])*")\)$/.exec(s.trim());if(!m)return null;try{return{rule:JSON.parse(m[1])};}catch{return null;}},
    summary:p=>"Regla: "+String(p.rule||"double")
  }
 ];
 for(const def of definitions)try{ctx.events.registerCommand(def);}catch(e){ctx.log?.warn?.("Command Studio picker: "+def.id+" "+e.message);}
}
