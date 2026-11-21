import { createProjectile, uid } from "./model.js";
import { normalizeBasCatalogType, basCatalogMetadata } from "./animation_catalogs.js";

// Purpose-built editable BAS starter timelines. All graphics are procedural and
// original: these are NOT Origin HeartGold frames or sprites.
const PALETTES = {
    subanimation:"rgba(255,224,143,0.95)",status:"rgba(189,142,240,0.95)",
    weather:"rgba(130,204,249,0.8)",terrain:"rgba(104,212,145,0.8)",
    ability:"rgba(242,205,120,0.95)",item:"rgba(250,215,141,0.95)",
    entry:"rgba(141,238,224,0.95)",faint:"rgba(148,156,180,0.9)",
    field:"rgba(146,214,205,0.65)",transition:"rgba(128,145,201,0.85)"
};
const valueKey=(frame,value)=>({id:uid("pkey"),frame,value,easing:"ease_both"});
const pos=(frame,anchor,dx=0,dy=0)=>({
    id:uid("key"),frame,easing:"ease_both",
    point:{anchor,x:anchor==="screen"?256:0,y:anchor==="screen"?192:0,offsetX:dx,offsetY:dy}
});
function makeClip({name,color,anchor="target_battler",start=0,end=30,
                   size=[35,90,160],opacity=[0,85,0],hollow=true,
                   w=92,h=92,scaleX=100,scaleY=100}) {
    const clip=createProjectile();
    clip.name=name;
    clip.startFrame=start;clip.endFrame=end;
    clip.graphic={
        source:"procedural",projectPath:"",folder:"Animations",name:"BAS original procedural shape",
        origin:"center",procedural:"circle",proceduralW:w,proceduralH:h,
        proceduralColor:color,proceduralHollow:hollow,proceduralLineWidth:4
    };
    clip.positionKeys=[pos(start,anchor),pos(end,anchor)];
    clip.coordinateSpace=anchor==="screen"?"screen":"auto";
    clip.coordinateSpaceManual=anchor==="screen";
    clip.visual.size=size[0];clip.visual.opacity=opacity[0];
    clip.visual.scaleX=scaleX;clip.visual.scaleY=scaleY;
    clip.valueKeys.size=[valueKey(start,size[0]),valueKey(start+(end-start)*.4,size[1]),valueKey(end,size[2])];
    clip.valueKeys.opacity=[valueKey(start,opacity[0]),valueKey(start+(end-start)*.23,opacity[1]),valueKey(end,opacity[2])];
    return clip;
}
function driftingEmitter(kind,anchor="screen",start=0,end=30) {
    const color=PALETTES[kind],clip=makeClip({
        name:basCatalogMetadata(kind).es+" · Partículas",color,
        anchor,start,end,size:[100,100,100],opacity:[75,75,75],
        hollow:false,w:12,h:12
    });
    // Mirrors the commands BAS preview and Ruby runtime already understand.
    // No hypothetical Nintendo DS emitter format is invented here.
    clip.valueKeys.size=[];clip.valueKeys.opacity=[];
    clip.pbs={
        focus:anchor==="screen"?"screen":anchor==="user_battler"?"user":"target",
        emitter:"RiseScatter",emitterRate:10,emitterIntensity:1,
        emitterDestination:"manual",
        emitX:0,emitXRange:anchor==="screen"?160:45,
        emitY:0,emitYRange:anchor==="screen"?90:22,
        emitAngle:90,emitAngleRange:90,
        emitSpeed:15,emitSpeedRange:8,emitGravity:0,
        particleSize:80,particleSizeRange:35,
        riseFrames:10,riseHeight:55,scatterFrames:12,scatterSpeed:25,
        simpleParticleLife:{duration:16,birthScale:35,midScale:95,deathScale:35,
            birthOpacity:0,midOpacity:85,deathOpacity:0,
            birthRotation:0,midRotation:0,deathRotation:0,spinSpeed:0},
        emitterCommands:{emitting:[
            {id:uid("ecmd"),frame:start,duration:0,value:true},
            {id:uid("ecmd"),frame:end-8,duration:0,value:false}
        ]},commands:{}
    };
    return clip;
}
function soundlessTimeline(kind) {
    const color=PALETTES[kind],prefix=basCatalogMetadata(kind).es;
    switch(kind) {
    case "subanimation":
        return [
            makeClip({name:prefix+" · Impacto auxiliar",color,start:0,end:18,
                size:[22,95,145],opacity:[0,95,0]}),
            makeClip({name:prefix+" · Eco",color,start:8,end:30,
                size:[35,100,175],opacity:[0,60,0]})
        ];
    case "status":
        return [
            makeClip({name:prefix+" · Marca",color,start:0,end:30,
                size:[25,80,100],opacity:[0,88,0]}),
            driftingEmitter(kind,"target_battler",4,30)
        ];
    case "weather":
        return [
            driftingEmitter(kind,"screen",0,30),
            makeClip({name:prefix+" · Apertura",color,anchor:"screen",start:0,end:30,
                w:440,h:280,hollow:true,size:[65,90,110],opacity:[0,35,0]})
        ];
    case "terrain":
        return [
            makeClip({name:prefix+" · Onda de suelo",color,anchor:"screen",start:0,end:28,
                w:280,h:80,scaleY:55,size:[45,100,160],opacity:[0,80,0]}),
            makeClip({name:prefix+" · Eco de campo",color,anchor:"screen",start:9,end:30,
                w:280,h:80,scaleY:55,size:[45,95,150],opacity:[0,50,0]})
        ];
    case "ability":
        return [
            makeClip({name:prefix+" · Aura",color,anchor:"user_battler",start:0,end:30,
                size:[40,100,130],opacity:[0,90,0]}),
            makeClip({name:prefix+" · Resonancia",color,anchor:"user_battler",start:6,end:25,
                size:[25,80,125],opacity:[0,75,0]})
        ];
    case "item": {
        const orb=makeClip({name:prefix+" · Efecto aplicado",color,anchor:"user_battler",
            start:0,end:24,w:36,h:36,hollow:false,size:[30,100,60],opacity:[0,100,0]});
        orb.positionKeys=[pos(0,"user_battler",0,-35),pos(12,"target_battler",0,-45),
                          pos(24,"target_battler",0,-45)];
        return [orb,makeClip({name:prefix+" · Destello",color,start:12,end:30,
            size:[30,80,150],opacity:[0,90,0]})];
    }
    case "entry":
        return [
            makeClip({name:prefix+" · Materialización",color,anchor:"user_battler",start:0,end:22,
                size:[130,65,20],opacity:[0,100,0]}),
            makeClip({name:prefix+" · Pulso",color,anchor:"user_battler",start:11,end:30,
                size:[25,95,145],opacity:[0,80,0]})
        ];
    case "faint":
        return [
            makeClip({name:prefix+" · Atenuación visual",color,start:0,end:30,
                size:[105,75,15],opacity:[0,75,0]}),
            makeClip({name:prefix+" · Eco final",color,start:9,end:30,
                size:[35,95,140],opacity:[0,55,0]})
        ];
    case "field":
        return [
            driftingEmitter(kind,"screen",0,30),
            makeClip({name:prefix+" · Resplandor",color,anchor:"screen",start:0,end:30,
                w:430,h:280,size:[85,100,100],opacity:[0,32,0]})
        ];
    case "transition": {
        const overlay=makeClip({name:prefix+" · Velo",color,anchor:"screen",start:0,end:30,
            w:512,h:384,hollow:false,size:[100,100,100],opacity:[0,65,0]});
        overlay.graphic.procedural="rect"; // supported by BAS rectangle fallback
        return [overlay];
    }
    default:return [];
    }
}
export function applyBasCategoryStarter(animation) {
    if(!animation || !Array.isArray(animation.tracks) || !animation.tracks.length)return animation;
    const category=normalizeBasCatalogType(animation.source && animation.source.catalogType);
    if(["move","common","custom"].includes(category))return animation;
    const track=animation.tracks.find(t=>t && t.type==="effects") || animation.tracks[0];
    if(!Array.isArray(track.clips))track.clips=[];
    if(track.clips.length)return animation;
    track.clips.push(...soundlessTimeline(category));
    animation.duration=Math.max(30,Number(animation.duration)||30);
    if(["weather","terrain","field","transition"].includes(category)){
        animation.source.targetMode="environment";
        animation.source.targetScope="environment";
        animation.source.customSpace="field";
    } else if(["status","faint","item","subanimation"].includes(category)){
        animation.source.targetScope="single_other";
    } else if(["entry","ability"].includes(category)){
        animation.source.targetScope="single_user";
    }
    return animation;
}
