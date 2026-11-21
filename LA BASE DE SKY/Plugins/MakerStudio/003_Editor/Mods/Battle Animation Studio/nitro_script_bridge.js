import { createAnimation, createProjectile, uid } from "./model.js";

// A limited, intentionally non-executing bridge for text dumps of HGSS a010/a061.
// Extracted ROM bytecode is NOT the same as assembly text; no SPA texture decoder is
// bundled. All particle artwork and missing Nintendo sound sequences remain external.
const SUPPORTED=new Set(["loadparticlefromspa","waitparticle","unloadparticle","addparticle","playsepan","playse","wait","waitstate","callfunction","end","endanimation"]);
function number(text) {
    const value=String(text||"").trim();
    if(/^[-+]?0x[0-9a-f]+$/i.test(value))return Number(value);
    if(/^[-+]?\d+$/i.test(value))return Number(value);
    return null;
}
export function parseNitroAnimationText(source) {
    const text=String(source||"").replace(/\r\n?/g,"\n");
    const slots=new Map(), commands=[],issues=[],references=new Set();
    let frame=0, hasEnd=false;
    text.split("\n").forEach((line,i)=>{
        const code=line.split(/\/\/|;/)[0].trim();
        if(!code||/^(?:[A-Za-z0-9_]+:|[A-Za-z_][\w]*\s+equ\s+.+)$/.test(code))return;
        const head=code.match(/^([A-Za-z_][\w]*)\s*(.*)$/);
        if(!head)return;
        const op=head[1].toLowerCase(),args=head[2].split(",").map(x=>x.trim());
        if(!SUPPORTED.has(op)){
            issues.push({line:i+1,code:"unsupported-op",message:"Instrucción no representable: "+op});
            commands.push({frame,op:"unhandled",sourceOp:op,args,line:i+1});return;
        }
        const row={frame,op,args,line:i+1};
        if(op==="wait"){
            const count=number(args[0]);
            if(count===null||count<0||count>10000)issues.push({line:i+1,code:"invalid-wait",message:"wait requiere frames positivos"});
            else{row.frames=count;frame+=count;}
        }
        if(op==="loadparticlefromspa"){
            const slot=number(args[0]),asset=number(args[1]);
            if(slot===null||asset===null){
                issues.push({line:i+1,code:"invalid-load",message:"Slot o índice SPA inválido"});
            }else{
                if(slots.has(slot))issues.push({line:i+1,code:"slot-reload",message:"Slot "+slot+" ya estaba cargado"});
                slots.set(slot,asset);references.add(asset);
                row.slot=slot;row.spa=asset;
            }
        }
        if(op==="addparticle"){
            row.slot=number(args[0]);row.emitter=number(args[1]);row.target=number(args[2]);
            row.spa=slots.has(row.slot)?slots.get(row.slot):null;
            if(row.spa===null)issues.push({line:i+1,code:"unloaded-particle",message:"addparticle usa un slot sin SPA cargado"});
        }
        if(op==="unloadparticle"){
            const slot=number(args[0]);row.slot=slot;
            if(!slots.has(slot))issues.push({line:i+1,code:"unload-missing",message:"Se descarga un slot que no consta cargado"});
            else slots.delete(slot);
        }
        if(op==="playse"||op==="playsepan"){
            row.sequence=number(args[0]);row.pan=op==="playsepan"?number(args[1]):0;
            if(row.sequence===null)issues.push({line:i+1,code:"unknown-sfx",message:"Secuencia de audio no numérica"});
        }
        if(op==="waitparticle"||op==="waitstate"){
            // DS waits for an asynchronous engine/SPA state. We cannot infer a
            // fixed duration without running the script with its real resources.
            issues.push({line:i+1,code:"asynchronous-wait",message:op+" depende de la ROM; duración no inferible"});
        }
        if(op==="callfunction"){
            issues.push({line:i+1,code:"native-callback",message:"callfunction llama a código nativo; revisar manualmente"});
        }
        if(op==="end"||op==="endanimation")hasEnd=true;
        commands.push(row);
    });
    for(const [slot,spa] of slots)issues.push({line:null,code:"slot-not-unloaded",message:"Slot "+slot+" (SPA "+spa+") sin descarga al finalizar"});
    if(!hasEnd)issues.push({line:null,code:"missing-end",message:"No se encontró fin de secuencia"});
    return {frameCount:Math.max(1,Math.round(frame)),commands,issues,spaIds:Array.from(references).sort((a,b)=>a-b),
        particleSpawns:commands.filter(x=>x.op==="addparticle").length,
        seReferences:commands.filter(x=>x.op==="playse"||x.op==="playsepan").map(x=>({frame:x.frame,seq:x.sequence,pan:x.pan}))
    };
}
export function createBasFromNitroText(text,config={}) {
    const analysis=parseNitroAnimationText(text);
    const catalog=String(config.category||"subanimation").toLowerCase();
    if(!["subanimation","move"].includes(catalog))throw Error("Unsupported Nitro bridge category");
    const id=String(config.id||"NITRO_REFERENCE").trim().toUpperCase().replace(/[^A-Z0-9_]/g,"_").slice(0,80);
    if(!id)throw Error("Empty animation ID");
    const animation=createAnimation(String(config.name||id),{catalogType:catalog,move:id,targetMode:"environment"});
    animation.source.importSystem="nitro_hgss_text";
    animation.source.approximate=true;
    animation.source.runtimeEnabled=false; // User must explicitly activate an approximate reference.
    animation.source.nitroSpaIds=analysis.spaIds;
    animation.source.nitroAudioCues=analysis.seReferences;
    animation.source.nitroCommands=analysis.commands;
    animation.source.nitroSourceText=String(text||"");
    animation.source.unsupported=analysis.issues.map(x=>({id:x.code,detail:(x.line?"L"+x.line+": ":"")+x.message}));
    animation.duration=Math.max(30,analysis.frameCount+12);
    animation.notes="BAS provisional: wait exacto, SPA y SFX numéricos como referencias. Ninguna textura/cry DS se incluye. Editar y activar manualmente.";
    if(config.placeholders!==false){
        const track=animation.tracks[0],spawns=analysis.commands.filter(x=>x.op==="addparticle");
        for(const spawn of spawns.slice(0,100)){
            const f=Math.max(0,Math.min(animation.duration-1,spawn.frame));
            const clip=createProjectile({
                name:"Nitro · SPA "+(spawn.spa??"?")+" · emitter "+(spawn.emitter??"?")+" (placeholder)",
                startFrame:f,endFrame:Math.min(animation.duration,f+8),
                graphic:{
                    source:"procedural",projectPath:"",name:"Placeholder, no DS artwork",
                    origin:"center",procedural:"circle",proceduralW:40,proceduralH:40,
                    proceduralHollow:true,proceduralLineWidth:4,proceduralColor:"rgba(208,189,255,0.9)"
                },
                positionKeys:[
                    {id:uid("key"),frame:f,point:{anchor:"target_battler",x:0,y:0,offsetX:0,offsetY:0},easing:"linear"}
                ],
                valueKeys:{
                    size:[{id:uid("pkey"),frame:f,value:35,easing:"linear"},{id:uid("pkey"),frame:f+8,value:115,easing:"linear"}],
                    opacity:[{id:uid("pkey"),frame:f,value:100,easing:"linear"},{id:uid("pkey"),frame:f+8,value:0,easing:"linear"}]
                },
                pbs:{nitroSpaIndex:spawn.spa,nitroEmitterIndex:spawn.emitter,nitroSlot:spawn.slot}
            });
            track.clips.push(clip);
        }
        if(spawns.length>100)animation.source.unsupported.push({id:"too-many-spawns",detail:"Se limitaron placeholders a 100 por seguridad"});
    }
    return {animation,analysis};
}
