// Additive BSS dialogue control. The large Studio application already routes
// data-dialogue-field inputs into its real Blueprint state/save pipeline.
// Keep this small UI extension independent of the main application bundle.
const DATA="Data/BattleSceneStudio/";
const files=[DATA+"battles.json",DATA+"battles.recovery.json"];
const modes=new Set(["hidden","behind"]);

async function read(ctx,path){
  try{
    if(!await ctx.fs.projectExists(path))return null;
    const row=JSON.parse(String(await ctx.fs.readProjectFile(path)||"{}"));
    return row&&typeof row==="object"?row:null;
  }catch(_){return null;}
}

export function installTrainerPortraitChoice(ctx,host){
  const saved=new Map();
  let disposed=false;
  Promise.all(files.map(file=>read(ctx,file))).then(([main,recovery])=>{
    if(disposed)return;
    // Match BSS' recovery priority. The scoped reader already merges
    // scripted_battles.json, so it participates in the chosen payload.
    const mainTime=Number(main&&main._bssSavedAt)||0;
    const recTime=Number(recovery&&recovery._bssSavedAt)||0;
    const ordered=recTime>mainTime?[recovery,main]:[main,recovery];
    for(const data of ordered){
      for(const bp of (data&&Array.isArray(data.blueprints)?data.blueprints:[])){
        for(const t of (bp.dialogues&&Array.isArray(bp.dialogues.triggers)?bp.dialogues.triggers:[])){
          if(t.id&&!saved.has(t.id))saved.set(t.id,modes.has(t.trainerPortraitMode)?t.trainerPortraitMode:"hidden");
        }
      }
    }
    render();
  }).catch(()=>{});

  function render(){
    if(disposed||!host||!host.isConnected)return;
    host.querySelectorAll(".bss-dialogue-card").forEach(card=>{
      if(card.querySelector('[data-dialogue-field="trainerPortraitMode"]'))return;
      const speaker=card.querySelector('[data-dialogue-field="speaker"]');
      const id=card.querySelector('[data-dialogue-field="id"]');
      if(!speaker||!id||speaker.value!=="trainer")return;
      const idx=id.dataset.dialogueIdx;
      if(idx==null)return;
      const field=document.createElement("label");
      field.className="bss-field";
      field.dataset.bssTrainerPortraitOption="1";
      const label=document.createElement("span");
      label.textContent="Mostrar entrenador en diálogo";
      const select=document.createElement("select");
      select.className="bss-select";
      select.dataset.dialogueIdx=idx;
      select.dataset.dialogueField="trainerPortraitMode";
      for(const [value,text] of [
        ["hidden","Oculto si ya hay Pokémon rival en el campo"],
        ["behind","Mostrar entrenador real detrás del Pokémon"]
      ]){
        const option=document.createElement("option");
        option.value=value;
        option.textContent=text;
        select.appendChild(option);
      }
      select.value=saved.get(id.value)||"hidden";
      const help=document.createElement("small");
      help.className="bss-note";
      help.textContent="Utiliza el sprite real del entrenador, con altura/offset definidos por el editor 042, sin dibujar un segundo retrato delante del Pokémon.";
      field.append(label,select,help);
      const parent=speaker.closest(".bss-field");
      if(parent)parent.insertAdjacentElement("afterend",field);
    });
  }

  const onChoice=e=>{
    const target=e.target;
    if(!target||!target.dataset||target.dataset.dialogueField!=="trainerPortraitMode")return;
    const card=target.closest(".bss-dialogue-card");
    const id=card&&card.querySelector('[data-dialogue-field="id"]');
    if(id&&modes.has(target.value))saved.set(id.value,target.value);
    // The native BSS onInput handler receives this same bubbling event,
    // updates the actual trigger and saves the Blueprint as usual.
  };
  host.addEventListener("change",onChoice,true);
  const observer=new MutationObserver(()=>render());
  observer.observe(host,{childList:true,subtree:true});
  render();
  return ()=>{
    disposed=true;
    observer.disconnect();
    host.removeEventListener("change",onChoice,true);
  };
}
