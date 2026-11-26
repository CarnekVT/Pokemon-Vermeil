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
 const effect=(k,t)=>{if(k==="none")return;if(k==="left")a.x-=d*t;if(k==="right")a.x+=d*t;if(k==="up")a.y-=d*t;if(k==="down")a.y+=d*t;if(k==="zoom")a.zoom*=1-.8*t;if(k==="pop")a.zoom*=Math.max(.08,1-.92*t+Math.sin(Math.PI*t)*.38);if(k==="rotate"){a.angle-=90*t;a.zoom*=1-.4*t}a.opacity*=1-t};
 if(enter&&f<enter)effect(c.enter,1-ease(f/enter,c.easing));if(exit&&f>duration-exit)effect(c.exit,ease((f-duration+exit)/exit,c.easing));return a;
}
