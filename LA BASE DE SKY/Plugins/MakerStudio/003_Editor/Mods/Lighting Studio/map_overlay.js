// On-map visual overlay. Maker Studio pointer events expose tile coordinates only.
export const TILE=32;
export function point(ev){return {x:Math.floor(Number(ev.tileX))+.5,y:Math.floor(Number(ev.tileY))+.5};}
export function toScreen(x,y,info){const t=Number(info.tileSize)||32,z=Number(info.zoom)||1;return {x:(x*t-(Number(info.viewportX)||0))*z,y:(y*t-(Number(info.viewportY)||0))*z};}
export function screenRadius(radius,info){return radius*(Number(info.tileSize)||32)/32*(Number(info.zoom)||1);}
export function hitTest(lights,p,selectedId){
  const list=Array.isArray(lights)?lights:[], d=l=>Math.hypot((l.x-p.x)*32,(l.y-p.y)*32);
  const centers=list.filter(l=>d(l)<29).sort((a,b)=>(a.id===selectedId?-100:0)-(b.id===selectedId?-100:0)||d(a)-d(b));
  if(centers.length)return {light:centers[0],part:'move'};
  const chosen=list.find(l=>l.id===selectedId);
  if(chosen&&Math.abs(d(chosen)-chosen.radiusPx)<22)return {light:chosen,part:'radius'};
  const inside=list.filter(l=>d(l)<l.radiusPx&&l.enabled!==false).sort((a,b)=>d(a)/a.radiusPx-d(b)/b.radiusPx);
  return inside.length?{light:inside[0],part:'move'}:null;
}
function rgb(hex){return /^#[0-9a-f]{6}$/i.test(String(hex))?[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)):[255,207,134];}
function disc(g,x,y,r,col){g.save();g.strokeStyle=col;g.lineWidth=2;g.setLineDash([7,5]);g.beginPath();g.arc(x,y,r,0,Math.PI*2);g.stroke();g.restore();}
function tag(g,x,y,text,bg){g.save();g.font='bold 12px sans-serif';const w=g.measureText(text).width+14;const yy=Math.max(23,y-17),xx=Math.max(4,x+12);g.fillStyle=bg||'#202836';g.fillRect(xx,yy-20,w,24);g.fillStyle='#fff7db';g.fillText(text,xx+7,yy-4);g.restore();}
function center(g,p,on,selected){g.save();g.beginPath();g.arc(p.x,p.y,selected?9:7,0,Math.PI*2);g.fillStyle='#222B39';g.fill();g.lineWidth=selected?3:2;g.strokeStyle=on?(selected?'#FFFFFF':'#FFCB75'):'#AAAAAA';g.stroke();g.beginPath();g.moveTo(p.x-4,p.y);g.lineTo(p.x+4,p.y);g.moveTo(p.x,p.y-4);g.lineTo(p.x,p.y+4);g.stroke();g.restore();}
export function paint(g,info,v){
  if(!g||!info||!v?.map)return;
  const ls=v.map.lights||[],w=info.canvasWidth,h=info.canvasHeight;
  g.save();
  try{
    if(v.showPreview){
      const darkness=Math.min(1,Math.max(0,Number(v.map.ambient?.darkness)||0));
      const tint=rgb(v.map.ambient?.color||'#142439');
      if(darkness){g.globalAlpha=darkness*.8;g.fillStyle='rgb('+tint.join(',')+')';g.fillRect(0,0,w,h);}
      g.globalAlpha=1;g.globalCompositeOperation='screen';
      for(const l of ls){
        if(l.enabled===false)continue;
        const p=toScreen(l.x,l.y,info),r=screenRadius(l.radiusPx,info);
        if(r<1||p.x+r<0||p.y+r<0||p.x-r>w||p.y-r>h)continue;
        const a=Math.max(0,Math.min(1,Number(l.intensity)||0)),c=rgb(l.color),s=Math.max(.05,Math.min(.95,Number(l.softness)||.7));
        const color=(alpha)=>'rgba('+c.join(',')+','+alpha+')';
        const grad=g.createRadialGradient(p.x,p.y,0,p.x,p.y,r);
        grad.addColorStop(0,color(.87*a));grad.addColorStop(s,color(.23*a));grad.addColorStop(1,color(0));
        g.fillStyle=grad;g.fillRect(p.x-r,p.y-r,r*2,r*2);
      }
      g.globalCompositeOperation='source-over';
    }
    if(!v.showGuides&&!v.editing)return;
    for(const l of ls){
      const p=toScreen(l.x,l.y,info),r=screenRadius(l.radiusPx,info),selected=l.id===v.selectedId,hovered=l.id===v.hoverHit?.light?.id;
      if(p.x+r<0||p.y+r<0||p.x-r>w||p.y-r>h)continue;
      if(selected){disc(g,p.x,p.y,r,'#FFE078');g.save();g.strokeStyle='#FFE078';g.beginPath();g.moveTo(p.x,p.y);g.lineTo(p.x+r,p.y);g.stroke();g.fillStyle='#1B2C39';g.fillRect(p.x+r-7,p.y-7,14,14);g.strokeRect(p.x+r-7,p.y-7,14,14);g.restore();}
      else if(hovered)disc(g,p.x,p.y,r,'#98F2FF');
      center(g,p,l.enabled!==false,selected);if(selected)tag(g,p.x,p.y,l.name+' · '+Math.round(l.radiusPx)+'px');
    }
    if(v.editing&&v.hover&&!v.drag){
      const p=toScreen(v.hover.x,v.hover.y,info);
      if(v.mode==='place'){
        const r=screenRadius(v.brushRadius||96,info);
        disc(g,p.x,p.y,r,'#A9FFB7');center(g,p,true,false);
        tag(g,p.x,p.y,'Nueva luz · '+Math.floor(v.hover.x)+','+Math.floor(v.hover.y),'#1D5540');
      } else if(v.mode==='erase'&&v.hoverHit){tag(g,p.x,p.y,'Borrar '+v.hoverHit.light.name,'#713237');}
      else if(v.mode==='select'&&v.hoverHit&&v.hoverHit.light.id!==v.selectedId){tag(g,p.x,p.y,v.hoverHit.light.name,'#28475C');}
    }
    if(v.editing&&v.drag){const l=ls.find(x=>x.id===v.drag.id);if(l){const p=toScreen(l.x,l.y,info);tag(g,p.x,p.y,v.drag.part==='radius'?'Radio: '+Math.round(l.radiusPx)+' px':'Posición: '+l.x.toFixed(1)+','+l.y.toFixed(1),'#24513C');}}
  } finally{g.restore();}
}
