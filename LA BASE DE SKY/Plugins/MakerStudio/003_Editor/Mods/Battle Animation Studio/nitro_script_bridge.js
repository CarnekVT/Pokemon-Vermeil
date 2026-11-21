import { createAnimation, createProjectile, uid } from "./model.js";

// A limited, intentionally non-executing bridge for text dumps of HGSS a010/a061.
// Extracted ROM bytecode is NOT the same as assembly text; no SPA texture decoder is
// bundled. All particle artwork and missing Nintendo sound sequences remain external.
const SUPPORTED=new Set(["loadparticlefromspa","waitparticle","unloadparticle","addparticle","playsepan","playsepanmod","playse","wait","waitstate","callfunction","shadeattackingmon","shadetargetmon","flashscreencolor","shaketargetmon","slideattackingmon","shakescreen","rotateattackerincircle","end","endanimation"]);
function number(text) {
    const value=String(text||"").trim();
    if(/^[-+]?0x[0-9a-f]+$/i.test(value))return Number(value);
    if(/^[-+]?\d+$/i.test(value))return Number(value);
    return null;
}
// Explicit user-provided path bindings after converting their own Nitro resources.
// Nothing is fetched from a ROM automatically and no original assets are bundled.
// Graphics: 499:2=Graphics/Animations/converted.png (or 499=... as fallback)
// Audio:    1911=Anim/ConvertedSound
export function parseNitroResourceMap(text, kind) {
    const map={};
    if(text && typeof text==="object" && !Array.isArray(text)) {
        return parseNitroResourceMap(Object.entries(text).map(([k,v])=>k+"="+v).join("\n"),kind);
    }
    const mode=kind==="audio"?"audio":"graphics";
    String(text||"").split(/\r?\n/).forEach((line,index)=>{
        const trimmed=line.trim();
        if(!trimmed || trimmed.startsWith("#") || trimmed.startsWith("//"))return;
        const ix=trimmed.indexOf("=");
        if(ix<=0)throw Error("Map line "+(index+1)+": expected ID=path");
        const key=trimmed.slice(0,ix).trim(), value=trimmed.slice(ix+1).trim().replace(/\\/g,"/");
        const numberPattern=mode==="audio"?/^\d+$/:/^\d+(?::\d+)?$/;
        if(!numberPattern.test(key))throw Error("Map line "+(index+1)+": invalid Nitro resource ID");
        if(!value || value.startsWith("/") || /(?:^|\/)\.\.?\//.test(value) || /^\w+:/.test(value) ||
           value.includes("\0") || value.includes("?") || value.includes("#"))
            throw Error("Map line "+(index+1)+": unsafe or empty project path");
        if(mode==="graphics" && !/^Graphics\/.+\.(?:png|webp|gif)$/i.test(value))
            throw Error("Map line "+(index+1)+": graphic must be an existing Graphics/*.png/webp/gif project file");
        if(mode==="audio" && !/^(?:Audio\/SE\/)?[\w .()\/-]+(?:\.(?:ogg|wav|mp3))?$/i.test(value))
            throw Error("Map line "+(index+1)+": use an Audio/SE relative filename");
        if(Object.prototype.hasOwnProperty.call(map,key))
            throw Error("Map line "+(index+1)+": duplicate resource ID "+key);
        map[key]=value;
    });
    return map;
}

export function parseNitroAnimationText(source, options={}) {
    const text=String(source||"").replace(/\r\n?/g,"\n");
    const lines=text.split("\n");
    const labels=new Map(), slots=new Map(), commands=[],issues=[],references=new Set();
    const requestedSide=String(options.side||"player").toLowerCase();
    const side=requestedSide==="foe"?"foe":"player";
    let frame=0, hasEnd=false, hasSideBranch=false, steps=0, pc=0;
    // Multiple labels (e.g. playerPart:, enemyPart:) point to instruction
    // addresses. We interpret a selected path; never concatenate both sides.
    for(let i=0;i<lines.length;i++) {
        const clean=lines[i].split(/\/\/|;/)[0].trim();
        const label=clean.match(/^([A-Za-z_][A-Za-z0-9_]*):$/);
        if(label)labels.set(label[1].toLowerCase(),i+1);
    }
    const MAX_STEPS=12000;
    while(pc<lines.length && steps++<MAX_STEPS){
        const lineNo=pc+1, line=lines[pc++];
        const code=line.split(/\/\/|;/)[0].trim();
        if(!code || /^[A-Za-z_][A-Za-z0-9_]*:\s*$/.test(code) ||
            /^[A-Za-z_][A-Za-z0-9_]*\s+equ\s+/i.test(code) ||
            code.startsWith("."))continue;
        const head=code.match(/^([A-Za-z_][\w]*)\s*(.*)$/);
        if(!head)continue;
        const op=head[1].toLowerCase(),args=head[2].split(",").map(x=>x.trim());
        const row={frame,op,args,line:lineNo};
        if(op==="jumpifside"){
            hasSideBranch=true;
            const conditional=number(args[0]);
            const label=(conditional===(side==="player"?0:1)?args[1]:args[2]||"").toLowerCase();
            const target=labels.get(label);
            row.branchSide=side;row.branchLabel=label;
            commands.push(row);
            if(target===undefined){
                issues.push({line:lineNo,code:"branch-label-missing",
                    message:"No se pudo resolver la etiqueta "+(label||"?")+" de jumpifside"});
                break;
            }
            pc=target;
            continue;
        }
        if(!SUPPORTED.has(op)){
            issues.push({line:lineNo,code:"unsupported-op",message:"Instrucción no representable: "+op});
            commands.push({...row,op:"unhandled",sourceOp:op});
            continue;
        }
        if(op==="wait"){
            const count=number(args[0]);
            if(count===null||count<0||count>10000)
                issues.push({line:lineNo,code:"invalid-wait",message:"wait requiere frames entre 0 y 10000"});
            else{row.frames=count;frame+=count;}
        }
        if(op==="loadparticlefromspa"){
            const slot=number(args[0]),spa=number(args[1]);
            if(slot===null||spa===null||slot<0||spa<0)
                issues.push({line:lineNo,code:"invalid-load",message:"Slot o índice SPA inválido"});
            else{
                if(slots.has(slot))
                    issues.push({line:lineNo,code:"slot-reload",message:"Slot "+slot+" ya estaba cargado"});
                slots.set(slot,spa);references.add(spa);
                row.slot=slot;row.spa=spa;
            }
        }
        if(op==="addparticle"){
            row.slot=number(args[0]);row.emitter=number(args[1]);row.target=number(args[2]);
            row.spa=slots.has(row.slot)?slots.get(row.slot):null;
            row.battlerRole=row.target===3?"user":row.target===4?"target":"unknown";
            if(row.spa===null)
                issues.push({line:lineNo,code:"unloaded-particle",message:"addparticle usa un slot sin SPA cargado"});
            if(row.battlerRole==="unknown")
                issues.push({line:lineNo,code:"unmapped-particle-origin",
                    message:"Origen "+String(args[2]||"?")+" distinto de 3 (usuario) o 4 (objetivo); verificar"});
        }
        if(op==="unloadparticle"){
            const slot=number(args[0]);row.slot=slot;
            if(!slots.has(slot))
                issues.push({line:lineNo,code:"unload-missing",message:"Se descarga un slot no cargado"});
            else slots.delete(slot);
        }
        if(op==="playse"||op==="playsepan"||op==="playsepanmod"){
            row.sequence=number(args[0]);
            row.pan=op==="playse"?0:number(args[1]);
            if(op==="playsepanmod"){
                row.panEnd=number(args[2]);row.panStep=number(args[3]);row.panFrames=number(args[4]);
                issues.push({line:lineNo,code:"pan-sweep-not-emulated",
                    message:"playsepanmod: la automatización de pan DS se conserva como referencia, no es un paneo Ruby"});
            }
            if(row.sequence===null)
                issues.push({line:lineNo,code:"unknown-sfx",message:"Secuencia de audio no numérica"});
        }
        if(op==="waitparticle"||op==="waitstate")
            issues.push({line:lineNo,code:"asynchronous-wait",
                message:op+" depende del estado real DS; duración en frames desconocida"});
        const knownCalls={33:"flashscreencolor",34:"shadebattler",36:"shakebattler",
                          57:"slideattackingmon",68:"shakescreen"};
        if(op==="callfunction"){
            row.callbackId=number(args[0]);row.semantic=knownCalls[row.callbackId]||"unknown";
            issues.push({line:lineNo,code:"native-callback",
                message:"callfunction "+String(row.callbackId)+
                " ("+row.semantic+"): efectos/timing DS no convertibles automáticamente"});
        }
        if(["shadeattackingmon","shadetargetmon","flashscreencolor",
            "shaketargetmon","slideattackingmon","shakescreen",
            "rotateattackerincircle"].includes(op)){
            row.semantic=op;
            issues.push({line:lineNo,code:"native-macro",
                message:op+" requiere adaptación a claves o eventos BAS; no se simula como efecto exacto"});
        }
        if(op==="end"||op==="endanimation")hasEnd=true;
        commands.push(row);
        if(hasEnd)break;
    }
    if(steps>=MAX_STEPS)issues.push({line:null,code:"script-loop-limit",
        message:"Se detuvo tras 12000 instrucciones para evitar bucles de etiquetas"});
    for(const [slot,spa] of slots)
        issues.push({line:null,code:"slot-not-unloaded",
            message:"Slot "+slot+" (SPA "+spa+") sin descarga antes de terminar esta rama"});
    if(!hasEnd)issues.push({line:null,code:"missing-end",message:"No se encontró fin de secuencia"});
    if(hasSideBranch && !options.side)
        issues.push({line:null,code:"assumed-player",
            message:"jumpifside detectado: se interpretó Player por defecto, importa Foe por separado"});
    const seOps=["playse","playsepan","playsepanmod"];
    return {
        frameCount:Math.max(1,Math.round(frame)),commands,issues,
        side,hasSideBranch,spaIds:Array.from(references).sort((a,b)=>a-b),
        particleSpawns:commands.filter(x=>x.op==="addparticle").length,
        seReferences:commands.filter(x=>seOps.includes(x.op)).map(x=>({
            frame:x.frame,seq:x.sequence,pan:x.pan,
            panEnd:x.panEnd??null,panStep:x.panStep??null,panFrames:x.panFrames??null
        }))
    };
}
// Optional approximations for documented HGSS macros/callback IDs. All new
// keys remain editable. Waitstate/SPA timing is unknown and never synthesized.
function adaptNitroNativeCues(animation,commands) {
    const max=(v,a,b,fallback)=>{const n=Number(v);return Number.isFinite(n)?Math.min(b,Math.max(a,n)):fallback;};
    const makeKey=(frame,value)=>({id:uid("pkey"),frame,value,easing:"ease_both"});
    const makePos=(frame,role,dx,dy)=>({id:uid("key"),frame,easing:"ease_both",
        point:{anchor:role+"_battler",x:0,y:0,offsetX:dx,offsetY:dy}});
    let adapted=0,latestFrame=animation.duration;
    const position={
        user:{x:0,y:0},target:{x:0,y:0}
    };
    const appendPos=(track,frame,role,x,y)=>{
        const list=track.positionKeys||(track.positionKeys=[]);
        list.push(makePos(frame,role,x,y));
        list.sort((a,b)=>Number(a.frame)-Number(b.frame));
        latestFrame=Math.max(latestFrame,frame);
    };
    const appendTone=(track,frame,r,g,b)=>{
        const keys=track.valueKeys||(track.valueKeys={});
        [["toneRed",r],["toneGreen",g],["toneBlue",b]].forEach(([property,value])=>{
            const list=keys[property]||(keys[property]=[]);
            list.push(makeKey(frame,value),makeKey(frame+8,0));
            list.sort((a,b)=>a.frame-b.frame);
        });
        latestFrame=Math.max(latestFrame,frame+8);
    };
    const shake=(track,role,frame,times,magnitude)=>{
        const count=max(times,1,10,2),strength=max(magnitude,1,24,6);
        const original=position[role],x=original.x,y=original.y;
        for(let i=0;i<count*2;i++)
            appendPos(track,frame+i,role,x+(i%2===0?strength:-strength),y);
        appendPos(track,frame+count*2,role,x,y);
        latestFrame=Math.max(latestFrame,frame+count*2);
    };
    for(const cue of commands||[]){
        const op=cue.op,id=cue.callbackId,frame=Number(cue.frame)||0;
        const args=cue.args||[];
        if(op==="shakescreen" || (op==="callfunction"&&id===68)){
            animation.events.push({id:uid("event"),type:"screen_shake",frame,
                duration:8,strength:6,axis:0,nitroApproximate:true});
            latestFrame=Math.max(latestFrame,frame+8);adapted++;continue;
        }
        if(op==="slideattackingmon" || (op==="callfunction"&&id===57)){
            const dx=op==="callfunction"?args[3]:args[0];
            const dy=op==="callfunction"?args[4]:args[1];
            if(!Number.isFinite(Number(dx))||!Number.isFinite(Number(dy)))continue;
            const current=position.user,track=animation.battlers.user;
            appendPos(track,frame,"user",current.x,current.y);
            current.x+=max(dx,-300,300,0);
            current.y+=max(dy,-300,300,0);
            appendPos(track,frame+8,"user",current.x,current.y);
            adapted++;continue;
        }
        if(op==="shaketargetmon" || (op==="callfunction"&&id===36)){
            const count=op==="callfunction"?args[2]:args[0];
            const magnitude=op==="callfunction"?args[5]:args[1];
            shake(animation.battlers.target,"target",frame,count,magnitude);
            adapted++;continue;
        }
        if(op==="flashscreencolor" || (op==="callfunction"&&id===33)){
            if(op==="callfunction")continue; // expression-based args: no safe RGB inference
            const values=args.slice(0,3).map(v=>Number(v));
            if(values.length<3||!values.every(Number.isFinite))continue;
            const rgba=values.map(v=>Math.round(max(v,0,31,0)*255/31)).concat([180]);
            animation.events.push({id:uid("event"),type:"screen_flash",
                frame,duration:8,color:rgba,nitroApproximate:true});
            latestFrame=Math.max(latestFrame,frame+8);adapted++;continue;
        }
        if(["shadeattackingmon","shadetargetmon"].includes(op)){
            const values=args.slice(0,3).map(v=>Number(v));
            if(values.length<3||!values.every(Number.isFinite))continue;
            const target=op==="shadeattackingmon"?animation.battlers.user:animation.battlers.target;
            appendTone(target,frame,...values.map(v=>Math.round(max(v,0,31,0)*255/31)));
            adapted++;
        }
    }
    animation.duration=Math.max(animation.duration,Math.ceil(latestFrame));
    return adapted;
}

export function createBasFromNitroText(text,config={}) {
    const analysis=parseNitroAnimationText(text,{side:config.side||"player"});
    const graphics=parseNitroResourceMap(config.graphicsMap||"", "graphics");
    const audio=parseNitroResourceMap(config.audioMap||"", "audio");
    const catalog=String(config.category||"subanimation").toLowerCase();
    if(!["subanimation","move"].includes(catalog))throw Error("Unsupported Nitro bridge category");
    const id=String(config.id||"NITRO_REFERENCE").trim().toUpperCase().replace(/[^A-Z0-9_]/g,"_").slice(0,80);
    if(!id)throw Error("Empty animation ID");
    const animation=createAnimation(String(config.name||id),{catalogType:catalog,move:id,targetMode:analysis.side==="foe"?"player":"foe"});
    animation.source.nitroImportSide=analysis.side;
    animation.source.nitroHasSideBranch=analysis.hasSideBranch;
    animation.source.importSystem="nitro_hgss_text";
    animation.source.approximate=true;
    animation.source.runtimeEnabled=false; // User must explicitly activate an approximate reference.
    animation.source.nitroSpaIds=analysis.spaIds;
    animation.source.nitroAudioCues=analysis.seReferences;
    animation.source.nitroMappedGraphics=graphics;
    animation.source.nitroMappedAudio=audio;
    animation.source.nitroUnresolvedGraphics=[];
    animation.source.nitroUnresolvedAudio=[];
    for(const cue of analysis.seReferences){
        const filename=cue.seq===null?"":audio[String(cue.seq)];
        if(!filename){
            animation.source.nitroUnresolvedAudio.push({seq:cue.seq,frame:cue.frame});
            continue;
        }
        const name=filename.replace(/^Audio\/SE\//i,"").replace(/\.(?:ogg|wav|mp3)$/i,"");
        animation.events.push({id:uid("event"),type:"se",frame:cue.frame,name,
            volume:100,pitch:100,nitroSeq:cue.seq,nitroPan:cue.pan,nitroPanEnd:cue.panEnd,nitroPanStep:cue.panStep,nitroPanFrames:cue.panFrames});
    }
    animation.source.nitroCommands=analysis.commands;
    animation.source.nitroSourceText=String(text||"");
    animation.source.unsupported=analysis.issues.map(x=>({id:x.code,detail:(x.line?"L"+x.line+": ":"")+x.message}));
    animation.duration=Math.max(30,analysis.frameCount+12);
    animation.notes="BAS provisional: wait exacto, SPA y SFX numéricos como referencias. Ninguna textura/cry DS se incluye. Editar y activar manualmente.";
    if(config.placeholders!==false){
        const track=animation.tracks[0],spawns=analysis.commands.filter(x=>x.op==="addparticle");
        for(const spawn of spawns.slice(0,100)){
            const key=String(spawn.spa)+":"+String(spawn.emitter);
            const mappedGraphic=graphics[key] || graphics[String(spawn.spa)] || "";
            if(!mappedGraphic) animation.source.nitroUnresolvedGraphics.push({
                spa:spawn.spa,emitter:spawn.emitter,frame:spawn.frame
            });
            const f=Math.max(0,Math.min(animation.duration-1,spawn.frame));
            const anchor=spawn.battlerRole==="user"?"user_battler":spawn.battlerRole==="target"?"target_battler":"screen";
            const pos=anchor==="screen"?{x:256,y:192}:{x:0,y:0};
            const clip=createProjectile({
                name:"Nitro · SPA "+(spawn.spa??"?")+" · emitter "+(spawn.emitter??"?")+" (placeholder)",
                startFrame:f,endFrame:Math.min(animation.duration,f+8),
                graphic:{
                    source:mappedGraphic?"new":"procedural",projectPath:mappedGraphic,
                    folder:"Animations",name:mappedGraphic?mappedGraphic.split("/").pop().replace(/\.[^.]+$/,""):"Placeholder, no DS artwork",
                    origin:"center",procedural:mappedGraphic?null:"circle",proceduralW:40,proceduralH:40,
                    proceduralHollow:true,proceduralLineWidth:4,proceduralColor:"rgba(208,189,255,0.9)"
                },
                positionKeys:[
                    {id:uid("key"),frame:f,point:{anchor,x:pos.x,y:pos.y,offsetX:0,offsetY:0},easing:"linear"}
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
    if(config.adaptNativeCues===true){
        animation.source.nitroAdaptedNativeCues=adaptNitroNativeCues(animation,analysis.commands);
        animation.notes+=" Callbacks compatibles convertidos a keyframes/eventos APROXIMADOS (duraciones de 8 frames por defecto); revisarlos antes de usar.";
    }
    if(analysis.spaIds.length && !config.placeholders) {
        animation.source.nitroUnresolvedGraphics=analysis.spaIds.filter(id=>
            !graphics[String(id)] && !Object.keys(graphics).some(k=>k.startsWith(String(id)+":"))
        ).map(id=>({spa:id,emitter:null,frame:0}));
    }
    return {animation,analysis};
}
