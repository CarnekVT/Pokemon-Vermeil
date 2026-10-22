// Configurable Pokémon gifts for Essentials 21.1 (Pokémon Vermeil).
// The existing pbAddPokemon accepts a fully configured Pokemon object.
const field=(key,label,type,value,extra={})=>({key,label,type,value,...extra});
const txt=(key,label,value="",group="Otros")=>field(key,label,"text",value,{group});
const sel=(key,label,value,options,group)=>field(key,label,"select",value,{options,group});
const num=(key,label,value,min,max,group)=>field(key,label,"number",value,{min,max,group});
const statCodes=["HP","ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED"];
const statNames=["PS","Ataque","Defensa","Ataque especial","Defensa especial","Velocidad"];
export const POKEMON_GROUPS=["Básico","Aspecto","Combate","Estadísticas","Identidad","Entrega"];
export function giftFields(oneTime=false){
 const base=[
 field("species","Especie PBS","symbol","EEVEE",{group:"Básico"}),
 num("level","Nivel",5,1,100,"Básico"),
 txt("intro","Texto introductorio","¡Tengo un Pokémon para ti!","Básico"),
 txt("nickname","Mote (opcional)","","Básico"),
 sel("gender","Género","auto",[["auto","Según especie"],["male","Macho"],["female","Hembra"]],"Básico"),
 num("form","Forma",0,0,100,"Aspecto"),
 sel("shiny","Variación de color","normal",[["normal","Normal"],["shiny","Shiny"],["super","Super Shiny"]],"Aspecto"),
 txt("ball","Poké Ball (PBS)","POKEBALL","Aspecto"),
 txt("nature","Naturaleza PBS (opcional)","","Combate"),
 txt("ability","Habilidad PBS (opcional)","","Combate"),
 txt("held","Objeto equipado PBS (opcional)","","Combate"),
 ...[1,2,3,4].map(i=>txt("move"+i,"Movimiento "+i+" (PBS)","","Combate")),
 ...statCodes.map((s,i)=>num("iv"+s,"IV · "+statNames[i],-1,-1,31,"Estadísticas")),
 ...statCodes.map((s,i)=>num("ev"+s,"EV · "+statNames[i],0,0,252,"Estadísticas")),
 num("friendship","Felicidad (-1 = predeterminado)",-1,-1,255,"Estadísticas"),
 txt("ot","Entrenador original (vacío = jugador)","","Identidad"),
 sel("otGender","Género del entrenador original","2",[["0","Masculino"],["1","Femenino"],["2","Desconocido"]],"Identidad"),
 num("otLanguage","Idioma del entrenador original",2,0,30,"Identidad"),
 txt("obtain","Texto de obtención (opcional)","","Identidad"),
 txt("ribbon","Cinta PBS (opcional)","","Identidad"),
 sel("pokerus","Pokérus","false",[["false","No"],["true","Sí"]],"Identidad"),
 sel("silent","Modo de entrega","false",[["false","Con animación y mensaje"],["true","Silencioso"]],"Entrega"),
 txt("success","Mensaje después del regalo","¡Cuídalo mucho!","Entrega")
 ];
 if(oneTime)base.push(
  sel("letter","Interruptor local","A",[["A","A"],["B","B"],["C","C"],["D","D"]],"Entrega"),
  txt("again","Mensaje al regresar","¡Espero que tu nuevo amigo esté bien!","Entrega")
 );
 return base;
}
export function giftDefaults(oneTime=false){return Object.fromEntries(giftFields(oneTime).map(x=>[x.key,x.value]));}
const sym=(v,optional=false)=>{
 const s=String(v??"").trim().replace(/^:/,"");
 if(optional&&!s)return null;
 if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(s))throw Error("Identificador PBS inválido: "+v);
 return ":"+s.toUpperCase();
};
const lit=v=>JSON.stringify(String(v??""));
const intval=(v,min,max,key)=>{
 const n=Number(v);
 if(!Number.isSafeInteger(n)||n<min||n>max)throw Error(key+": rango "+min+"–"+max);
 return n;
};
export function giftCheck(v){
 const errors=[];
 try{
  sym(v.species);intval(v.level,1,100,"Nivel");intval(v.form,0,100,"Forma");
  const total=statCodes.reduce((sum,k)=>{
   const n=intval(v["ev"+k]??0,0,252,"EV "+k);
   intval(v["iv"+k]??-1,-1,31,"IV "+k);return sum+n;
  },0);
  if(total>510)errors.push("Los EV suman "+total+"; el máximo habitual es 510.");
  intval(v.friendship??-1,-1,255,"Felicidad");
  for(const field of ["nature","ability","held","ball","ribbon","move1","move2","move3","move4"])sym(v[field],true);
  if(v.ot)intval(v.otLanguage??2,0,30,"Idioma OT");
  if(!["auto","male","female"].includes(v.gender))errors.push("Género desconocido");
  if(!["normal","shiny","super"].includes(v.shiny))errors.push("Variación cromática desconocida");
  if(v.letter&&!["A","B","C","D"].includes(v.letter))errors.push("Interruptor local inválido");
 }catch(e){errors.push(e.message);}
 return errors;
}
export function buildGiftRuby(v,oneTime=false){
 const issues=giftCheck(v);if(issues.length)throw Error(issues.join("; "));
 const lines=[
 "pkmn = Pokemon.new("+sym(v.species)+", "+intval(v.level,1,100,"Nivel")+")"
 ];
 const emit=(expr,value)=>{if(value)lines.push("pkmn."+expr+" = "+value)};
 if(Number(v.form)>0)emit("form",String(v.form));
 if(v.gender==="male")emit("gender","0");
 if(v.gender==="female")emit("gender","1");
 if(v.shiny==="shiny")emit("shiny","true");
 if(v.shiny==="super")emit("super_shiny","true");
 if(v.nickname?.trim())emit("name",lit(v.nickname.trim()));
 if(v.ball?.trim())emit("poke_ball",sym(v.ball));
 if(v.nature?.trim())emit("nature",sym(v.nature));
 if(v.ability?.trim())emit("ability",sym(v.ability));
 if(v.held?.trim())emit("item",sym(v.held));
 const moves=[1,2,3,4].map(i=>sym(v["move"+i],true)).filter(Boolean);
 if(moves.length)lines.push("pkmn.moves = ["+moves.map(x=>"Pokemon::Move.new("+x+")").join(", ")+"]");
 for(const stat of statCodes){
  const iv=Number(v["iv"+stat]??-1),ev=Number(v["ev"+stat]??0);
  if(iv>=0)lines.push("pkmn.iv[:"+stat+"] = "+iv);
  if(ev>0)lines.push("pkmn.ev[:"+stat+"] = "+ev);
 }
 if(Number(v.friendship)>=0)emit("happiness",String(v.friendship));
 if(v.ot?.trim())lines.push("pkmn.owner = Pokemon::Owner.new_foreign("+lit(v.ot.trim())+", "+intval(v.otGender??2,0,2,"OT")+", "+intval(v.otLanguage??2,0,30,"Idioma")+")");
 if(v.obtain?.trim())emit("obtain_text",lit(v.obtain.trim()));
 if(v.ribbon?.trim())lines.push("pkmn.giveRibbon("+sym(v.ribbon)+")");
 if(String(v.pokerus)==="true")lines.push("pkmn.givePokerus");
 lines.push("pkmn.calc_stats");
 const fn=String(v.silent)==="true"?"pbAddPokemonSilent":"pbAddPokemon";
 lines.push("if "+fn+"(pkmn)");
 if(oneTime){
  lines.push("  $game_self_switches[[$game_map.map_id, @event_id, "+lit(v.letter||"A")+"]] = true");
  lines.push("  $game_map.need_refresh = true");
 }
 if(v.success?.trim())lines.push("  pbMessage("+lit(v.success.trim())+")");
 lines.push("end");
 const given=lines.join("\n");
 if(!oneTime)return (v.intro?.trim()?"pbMessage("+lit(v.intro.trim())+")\n":"")+given;
 const flag="$game_self_switches[[$game_map.map_id, @event_id, "+lit(v.letter||"A")+"]]";
 // The flag changes ONLY after the delivery API returns true; full boxes can be retried.
 const guarded=(v.intro?.trim()?"  pbMessage("+lit(v.intro.trim())+")\n":"")
  +given.split("\n").map(x=>"  "+x).join("\n");
 return "if !"+flag+"\n"+guarded+"\nelse\n  pbMessage("+lit(v.again||"¡Gracias por cuidar de él!")+")\nend";
}
export function enhancePokemonActions(actions,ruby){
 for(const id of ["give_pokemon","gift_pokemon_once"]){
  const entry=actions.find(a=>a.id===id);if(!entry)continue;
  const once=id==="gift_pokemon_once";
  entry.title=once?"Regalar Pokémon una sola vez":"Crear y entregar un Pokémon";
  entry.description=once?"Personaliza un Pokémon y marca su entrega solo al recibirlo correctamente.":"Configura especie, forma, atributos, movimientos, naturaleza y más.";
  entry.fields=giftFields(once);
  entry.build=v=>ruby(buildGiftRuby(v,once));
  entry.keywords+=" movimientos habilidad naturaleza shiny iv ev mote pokeball entrenador original objeto";
 }
}
