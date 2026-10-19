import {drawLights, evaluated} from './render.js';
// On-map visual overlay. Maker Studio pointer events expose tile coordinates only.
export const TILE=32;
export function point(ev){return {x:Math.floor(Number(ev.tileX))+.5,y:Math.floor(Number(ev.tileY))+.5};}
export function toScreen(x,y,info){const t=Number(info.tileSize)||32,z=Number(info.zoom)||1;return {x:(x*t-(Number(info.viewportX)||0))*z,y:(y*t-(Number(info.viewportY)||0))*z};}
export function screenRadius(radius,info){return radius*(Number(info.tileSize)||32)/32*(Number(info.zoom)||1);}
export function hitTest(lights,p,selectedId,shiftRadius=false){
  const list=Array.isArray(lights)?lights:[], distance=l=>Math.hypot((l.x-p.x)*32,(l.y-p.y)*32);
  const chosen=list.find(l=>l.id===selectedId);
  // Shift + drag anywhere within the selected halo changes its radius.
  if(chosen&&shiftRadius&&distance(chosen)<Math.max(28,chosen.radiusPx+24))return {light:chosen,part:'radius'};
  // Selected light remains the preferred target, even if its halo overlaps others.
  if(chosen&&distance(chosen)<=26)return {light:chosen,part:'move'};
  const centers=list.map((light,index)=>({light,index,d:distance(light)}))
    .filter(x=>x.d<=26).sort((a,b)=>a.d-b.d||b.index-a.index);
  if(centers.length)return {light:centers[0].light,part:'move'};
  if(chosen&&Math.abs(distance(chosen)-chosen.radiusPx)<=28)return {light:chosen,part:'radius'};
  // A click inside the illuminated area selects its source, not empty space.
  const halos=list.map((light,index)=>({light,index,d:distance(light)}))
    .filter(x=>x.d<=Math.max(16,x.light.radiusPx)&&x.light.enabled!==false)
    .sort((a,b)=>a.d/Math.max(a.light.radiusPx,1)-b.d/Math.max(b.light.radiusPx,1)||b.index-a.index);
  return halos.length?{light:halos[0].light,part:'move'}:null;
}
function rgb(hex){return /^#[0-9a-f]{6}$/i.test(String(hex))?[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)):[255,207,134];}
function disc(g,x,y,r,col){g.save();g.strokeStyle=col;g.lineWidth=2;g.setLineDash([7,5]);g.beginPath();g.arc(x,y,r,0,Math.PI*2);g.stroke();g.restore();}
function tag(g,x,y,text,bg){g.save();g.font='bold 12px sans-serif';const w=g.measureText(text).width+14;const yy=Math.max(23,y-17),xx=Math.max(4,x+12);g.fillStyle=bg||'#202836';g.fillRect(xx,yy-20,w,24);g.fillStyle='#fff7db';g.fillText(text,xx+7,yy-4);g.restore();}
function center(g,p,on,selected){g.save();g.beginPath();g.arc(p.x,p.y,selected?9:7,0,Math.PI*2);g.fillStyle='#222B39';g.fill();g.lineWidth=selected?3:2;g.strokeStyle=on?(selected?'#FFFFFF':'#FFCB75'):'#AAAAAA';g.stroke();g.beginPath();g.moveTo(p.x-4,p.y);g.lineTo(p.x+4,p.y);g.moveTo(p.x,p.y-4);g.lineTo(p.x,p.y+4);g.stroke();g.restore();}
function lightOutline(g,source,p,info,color){
  const sc=screenRadius(32,info)/32,rot=(source.rotation||0)*Math.PI/180;
  const rr=(source.radiusPx||96)*sc;
  const w=(source.widthPx||160)*sc,h=(source.heightPx||96)*sc;
  g.save();g.translate(p.x,p.y);g.rotate(rot);g.strokeStyle=color;g.lineWidth=2;
  g.setLineDash([7,5]);g.beginPath();
  if(source.type==='rectangle')g.rect(-w/2,-h/2,w,h);
  else if(source.type==='ellipse')g.ellipse(0,0,w/2,h/2,0,0,Math.PI*2);
  else if(source.type==='cone'){
    const half=(source.angle||70)*Math.PI/360;
    g.moveTo(0,0);g.arc(0,0,rr,-half,half);g.closePath();
  }else g.arc(0,0,rr,0,Math.PI*2);
  g.stroke();g.restore();
}
export function paint(g,info,v){
  if(!g || !info || !v)return;
  // Draw on the exact map canvas given by Maker Studio, just like Animated Props.
  // Data lookup is keyed by info.mapId at the call site (not by a potentially stale tab).
  const map=v.map||{enabled:true,ambient:{darkness:0,color:'#142439'},lights:[]};
  const allEnabled=map.enabled!==false,ls=map.lights||[];
  const w=Number(info.canvasWidth)||0,h=Number(info.canvasHeight)||0;
  if(w<=0||h<=0)return;
  const live=!!v.showPreview, editing=!!v.editing;
  const projection={x:x=>toScreen(x,0,info).x,y:y=>toScreen(0,y,info).y,scale:()=>screenRadius(32,info)/32,
    viewportKey:[info.mapId,info.tileSize,info.zoom,info.viewportX,info.viewportY].join(':'),mapId:info.mapId,revision:v.revision??0,viewWidth:w,viewHeight:h};
  const seconds=Number.isFinite(v.time)?v.time:performance.now()/1000;
  g.save();
  try{
    if(live&&allEnabled){
      const ambient=v.ambientOverride||map.ambient||{};
      const darkness=Math.max(v.previewNight?0.42:0,Math.max(0,Math.min(1,Number(ambient.darkness)||0)));
      if(darkness){
        const tint=rgb(ambient.color||'#142439');
        g.fillStyle='rgb('+tint.join(',')+')';
        g.globalAlpha=darkness*.8;
        g.fillRect(0,0,w,h);
        g.globalAlpha=1;
      }
      drawLights(g,ls,projection,w,h,seconds,v.fastPreview?'fast':(map.overlapMode||'union'));
    }
    // Preview a light at the cursor BEFORE insertion using the actual light renderer.
    // Animated Props follows the same overlay/pointer-state approach.
    if(editing && v.mode==='place' && v.hover && live && allEnabled && !v.drag){
      const draft=v.brush||{};
      const ghost={
        id:'lighting-studio-ghost',enabled:true,type:draft.type||'radial',blendMode:draft.blendMode||'add',
        x:v.hover.x,y:v.hover.y,
        color:draft.color||'#FFCF86',
        radiusPx:v.brushRadius||96,intensity:draft.intensity??0.8,
        softness:draft.softness??0.75,
        pixel:draft.pixel||{enabled:false},pulse:{enabled:false}
      };
      g.save();g.globalAlpha=.78;drawLights(g,[ghost],{x:projection.x,y:projection.y,scale:projection.scale,
        viewportKey:['ghost',projection.viewportKey,ghost.x,ghost.y,ghost.type,ghost.radiusPx].join(':'),revision:0,viewWidth:w,viewHeight:h},w,h,seconds,'union');g.restore();
    }
    if(!v.showGuides&&!editing)return;
    // Visual handles stay readable even with all lights disabled/preview off.
    for(const l of ls){
      const p=toScreen(l.x,l.y,info);
      const radius=evaluated(l,seconds).radius;
      const r=screenRadius(radius,info),selected=l.id===v.selectedId,hovered=l.id===v.hoverHit?.light?.id;
      if(p.x+r<0||p.y+r<0||p.x-r>w||p.y-r>h)continue;
      if(selected){
        lightOutline(g,l,p,info,'#FFE078');
        g.save();g.strokeStyle='#FFE078';g.beginPath();g.moveTo(p.x,p.y);g.lineTo(p.x+r,p.y);g.stroke();
        g.fillStyle='#1B2C39';g.fillRect(p.x+r-7,p.y-7,14,14);g.strokeRect(p.x+r-7,p.y-7,14,14);g.restore();
      }else if(hovered)lightOutline(g,l,p,info,'#98F2FF');
      center(g,p,l.enabled!==false,selected);
      if(selected)tag(g,p.x,p.y,l.name+' · '+Math.round(radius)+' px');
    }
    if(editing && v.hover && !v.drag){
      const p=toScreen(v.hover.x,v.hover.y,info);
      if(v.mode==='place'){
        const r=screenRadius(v.brushRadius||96,info);
        lightOutline(g,{type:v.brush?.type||'radial',radiusPx:v.brushRadius||96},p,info,'#A9FFB7');
        center(g,p,true,false);
        tag(g,p.x,p.y,allEnabled?'Nueva luz · '+Math.floor(v.hover.x)+','+Math.floor(v.hover.y):'Activa iluminación del mapa','#1D5540');
      }else if(v.mode==='erase'&&v.hoverHit){
        tag(g,p.x,p.y,'Borrar '+v.hoverHit.light.name,'#713237');
      }else if(v.mode==='select'&&v.hoverHit&&v.hoverHit.light.id!==v.selectedId){
        tag(g,p.x,p.y,v.hoverHit.light.name,'#28475C');
      }
    }
    if(editing && v.drag){
      const light=ls.find(l=>l.id===v.drag.id);
      if(light){
        const p=toScreen(light.x,light.y,info);
        tag(g,p.x,p.y,v.drag.part==='radius'
          ?'Radio: '+Math.round(light.radiusPx)+' px'
          :'Posición: '+light.x.toFixed(1)+','+light.y.toFixed(1),'#24513C');
      }
    }
  }finally{g.restore();}
}
