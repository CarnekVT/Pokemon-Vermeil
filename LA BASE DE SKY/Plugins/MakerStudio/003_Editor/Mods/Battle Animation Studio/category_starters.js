import { createProjectile, uid } from "./model.js";
import { normalizeBasCatalogType, basCatalogMetadata } from "./animation_catalogs.js";

// Author-created and resource-independent starters, NOT decoded Origin HG sprites.
// They remain normal BAS clips, events and keys, editable from the timeline.
const PALETTES={
    subanimation:"rgba(255,241,191,1)", status:"rgba(191,160,242,1)",weather:"rgba(155,214,255,1)",terrain:"rgba(129,216,167,1)",
    ability:"rgba(244,206,129,1)",item:"rgba(255,224,171,1)",entry:"rgba(141,233,210,1)",faint:"rgba(183,181,208,1)",
    field:"rgba(165,228,209,1)",transition:"rgba(200,213,255,1)"
};
function key(frame,value){return {id:uid("pkey"),frame,value,easing:"ease_both"};}
function position(frame,anchor){return {id:uid("key"),frame,easing:"ease_both",point:{anchor,x:0,y:0,offsetX:0,offsetY:0}};}
function proceduralClip(category,animation) {
    const palette=PALETTES[category]||"rgba(226,236,244,1)";
    const metadata=basCatalogMetadata(category);
    const anchor=metadata.subject==="field"?"screen":metadata.subject==="user"?"user_battler":"target_battler";
    const clip=createProjectile();
    clip.name=metadata.es+" · Pulso inicial";
    clip.startFrame=0;clip.endFrame=30;
    clip.positionKeys=[position(0,anchor),position(30,anchor)];
    clip.coordinateSpace=metadata.subject==="field"?"screen":"auto";
    clip.coordinateSpaceManual=metadata.subject==="field";
    clip.graphic={source:"procedural",projectPath:"",name:"Original BAS pulse",origin:"center",
        procedural:"circle",proceduralW:80,proceduralH:80,
        proceduralColor:palette,proceduralHollow:true,proceduralLineWidth:5};
    clip.visual.size=35;clip.visual.opacity=0;
    clip.valueKeys.size=[key(0,35),key(6,75),key(21,130),key(30,160)];
    clip.valueKeys.opacity=[key(0,0),key(5,90),key(20,65),key(30,0)];
    if(["weather","terrain","field"].includes(category)) {
        clip.name=metadata.es+" · Emisor ambiente";
        clip.startFrame=0;clip.endFrame=30;
        clip.graphic.procedural="circle";clip.graphic.proceduralHollow=false;
        clip.graphic.proceduralW=13;clip.graphic.proceduralH=13;
        clip.visual.size=100;clip.visual.opacity=75;
        clip.valueKeys.size=[];
        clip.valueKeys.opacity=[];
        clip.pbs={
            focus:"screen",emitter:"RiseScatter",emitterRate:10,emitterIntensity:1,
            emitting:true,emitterDestination:"manual",
            emitX:0,emitXRange:170,emitY:0,emitYRange:95,emitAngle:90,emitAngleRange:65,
            emitSpeed:12,emitSpeedRange:8,emitGravity:0,particleSize:85,particleSizeRange:30,
            riseFrames:11,riseHeight:36,scatterFrames:11,scatterSpeed:30,
            simpleParticleLife:{duration:16,birthScale:35,midScale:90,deathScale:45,
                birthOpacity:0,midOpacity:85,deathOpacity:0,
                birthRotation:0,midRotation:0,deathRotation:0,spinSpeed:0},
            emitterCommands:{emitting:[
                {id:uid("ecmd"),frame:0,duration:0,value:true},
                {id:uid("ecmd"),frame:22,duration:0,value:false}
            ]},
            commands:{}
        };
    }
    return clip;
}
export function applyBasCategoryStarter(animation) {
    if(!animation||!Array.isArray(animation.tracks)||!animation.tracks.length)return animation;
    const category=normalizeBasCatalogType(animation.source && animation.source.catalogType);
    if(["move","common","custom"].includes(category))return animation;
    const track=animation.tracks.find(x=>x&&x.type==="effects")||animation.tracks[0];
    if(!Array.isArray(track.clips))track.clips=[];
    if(track.clips.length)return animation;
    track.clips.push(proceduralClip(category,animation));
    animation.duration=Math.max(30,Number(animation.duration)||30);
    if(["weather","terrain","field","transition"].includes(category)){
        animation.source.targetMode="environment";
        animation.source.targetScope="environment";
        animation.source.customSpace="field";
    }
    if(["status","faint","item","subanimation"].includes(category)){
        animation.source.targetMode="environment";
        animation.source.targetScope="single_other";
    }
    if(["entry","ability"].includes(category)){
        animation.source.targetMode="environment";
        animation.source.targetScope="single_user";
    }
    return animation;
}
