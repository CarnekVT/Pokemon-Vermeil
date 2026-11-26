const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const n=(v,d=0)=>v!==null&&v!==""&&Number.isFinite(Number(v))?Number(v):d;
export const PRESETS={enter:[["none","Sin animación"],["fade","Fundido"],["left","Desde izquierda"],["right","Desde derecha"],["up","Desde arriba"],["down","Desde abajo"],["zoom","Zoom"],["pop","Elástico"],["rotate","Giro"]],exit:[["none","Sin animación"],["fade","Fundido"],["left","Hacia izquierda"],["right","Hacia derecha"],["up","Hacia arriba"],["down","Hacia abajo"],["zoom","Reducir"],["rotate","Giro"]],motion:[["none","Estático"],["float","Flotar"],["shake","Temblar"],["pulse","Pulso"],["zoom_out","Alejar"],["zoom_in","Acercar"],["custom","Transformación A → B"]]};
export function clipLength(c){return clamp(Math.round(n(c.duration,120)),1,360000)}
export function spans(c){const duration=clipLength(c),enter=c.enter==="none"?0:clamp(Math.round(n(c.inFrames,24)),0,duration),exit=c.keep||c.exit==="none"?0:clamp(Math.round(n(c.outFrames,24)),0,duration-enter);return {duration,enter,exit}}
const ease=(p,k)=>k==="linear"?p:k==="in"?p*p:k==="out"?1-(1-p)*(1-p):p*p*(3-2*p);
export function sample(c,frame){
 const {duration,enter,exit}=spans(c),f=clamp(n(frame),0,duration),p=ease(f/duration,c.easing),d=Math.max(0,n(c.distance,64));
 const a={x:n(c.x),y:n(c.y),zoom:clamp(n(c.zoom,1),.01,30),angle:n(c.angle),opacity:clamp(n(c.opacity,255),0,255)};
 const mix=(a,b)=>a+(b-a)*p;
 switch(c.motion){case"float":a.y+=Math.sin(f*.08)*d*.25;break;case"shake":a.x+=Math.sin(f*1.8)*d*.12;break;case"pulse":a.zoom*=1+Math.sin(f*.11)*.12;break;case"zoom_out":a.zoom*=mix(1,.5);break;case"zoom_in":a.zoom*=mix(1,1.5);break;case"custom":a.x=mix(a.x,n(c.endX,a.x));a.y=mix(a.y,n(c.endY,a.y));a.zoom=mix(a.zoom,clamp(n(c.endZoom,a.zoom),.01,30));a.angle=mix(a.angle,n(c.endAngle,a.angle));a.opacity=mix(a.opacity,clamp(n(c.endOpacity,a.opacity),0,255));break}
 for(const prop of KEY_PROPS)if(keysFor(c,prop).length)a[prop]=baseValue(c,prop,f);
 const effect=(k,t)=>{if(k==="none")return;if(k==="left")a.x-=d*t;if(k==="right")a.x+=d*t;if(k==="up")a.y-=d*t;if(k==="down")a.y+=d*t;if(k==="zoom")a.zoom*=1-.8*t;if(k==="pop")a.zoom*=Math.max(.08,1-.92*t+Math.sin(Math.PI*t)*.38);if(k==="rotate"){a.angle-=90*t;a.zoom*=1-.4*t}a.opacity*=1-t};
 if(enter&&f<enter)effect(c.enter,1-ease(f/enter,c.easing));if(exit&&f>duration-exit)effect(c.exit,ease((f-duration+exit)/exit,c.easing));return a;
}

export const KEY_PROPS=["x","y","zoom","angle","opacity"];
export const KEY_LABELS={x:"Posición X",y:"Posición Y",zoom:"Escala",angle:"Rotación",opacity:"Opacidad"};
export const KEY_EASING=[["linear","Lineal"],["ease_in","Acelerar"],["ease_out","Desacelerar"],["ease_both","Suave"],["hold","Mantener"]];
export function easeKey(t,mode){t=clamp(t,0,1);if(mode==="hold")return t>=1?1:0;if(mode==="linear")return t;if(mode==="ease_in")return t*t;if(mode==="ease_out")return 1-(1-t)*(1-t);return t<.5?2*t*t:1-(-2*t+2)**2/2}
export function keysFor(c,prop){return (Array.isArray(c.keys)?c.keys:[]).filter(k=>Array.isArray(k)&&k[0]===prop&&Number.isFinite(Number(k[1]))&&Number.isFinite(Number(k[2]))).sort((a,b)=>a[1]-b[1])}
export function baseValue(c,prop,frame){
 const fallback=prop==="zoom"?1:prop==="opacity"?255:0,v=n(c[prop],fallback),ks=keysFor(c,prop);
 if(!ks.length)return v;
 if(frame<ks[0][1]){if(ks[0][1]===0)return ks[0][2];return v+(ks[0][2]-v)*easeKey(frame/ks[0][1],"ease_both")}
 if(frame>=ks[ks.length-1][1])return ks[ks.length-1][2];
 for(let i=0;i<ks.length-1;i++){const a=ks[i],b=ks[i+1];if(frame>=a[1]&&frame<=b[1])return a[2]+(b[2]-a[2])*easeKey((frame-a[1])/Math.max(.0001,b[1]-a[1]),a[3])}
 return v;
}
export function setKey(c,prop,frame,value,easing){
 if(!KEY_PROPS.includes(prop))return;
 frame=clamp(Math.round(n(frame)),0,clipLength(c));value=n(value,baseValue(c,prop,frame));
 if(prop==="zoom")value=clamp(value,.01,30);if(prop==="opacity")value=clamp(value,0,255);
 c.keys=Array.isArray(c.keys)?c.keys:[];
 if(frame>0&&!c.keys.some(k=>k[0]===prop&&k[1]===0)){const initial=baseValue(c,prop,0);c.keys.push([prop,0,initial,easing||"ease_both"])}
 const k=c.keys.find(k=>k[0]===prop&&k[1]===frame);if(k){k[2]=value;if(easing)k[3]=easing}else c.keys.push([prop,frame,value,easing||"ease_both"]);
 c.keys.sort((a,b)=>a[1]-b[1]||KEY_PROPS.indexOf(a[0])-KEY_PROPS.indexOf(b[0]));
}
export function removeKey(c,prop,frame){const initial=baseValue(c,prop,0);c.keys=(c.keys||[]).filter(k=>k[0]!==prop||k[1]!==frame);if(frame===0)c[prop]=initial}
export function moveKey(c,prop,from,to){const k=keysFor(c,prop).find(k=>k[1]===from);if(!k||from===to)return;const v=k[2],e=k[3];removeKey(c,prop,from);setKey(c,prop,to,v,e)}
export function resizeKeys(c){const max=clipLength(c),old=Array.isArray(c.keys)?c.keys.slice():[];c.keys=[];for(const k of old)if(KEY_PROPS.includes(k[0]))setKey(c,k[0],Math.min(k[1],max),k[2],k[3])}
