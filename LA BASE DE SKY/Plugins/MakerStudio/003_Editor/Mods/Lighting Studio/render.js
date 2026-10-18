// Preview shared by map overlay and inspector. Canvas 2D approximation to mkxp.
export function evaluated(light,t){
 const p=light.pulse||{},a=p.enabled?Math.sin(t*Math.PI*2*(p.speedHz||1)+(p.phase||0)*Math.PI/180):0;
 return {radius:Math.max(8,light.radiusPx*(1+a*(p.radius||0))),
 intensity:Math.max(0,Math.min(1,light.intensity*(1+a*(p.intensity||0))))};
}
const rgb=hex=>/^#[0-9A-F]{6}$/i.test(hex||'')?[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)):[255,206,138];
export function drawLights(g,list,project,width,height,t=0){
 for(const light of list||[]){
  if(!light.enabled)continue;
  const {radius,intensity}=evaluated(light,t),x=project.x(light.x),y=project.y(light.y),r=radius*project.scale();
  if(r<1||x+r<0||y+r<0||x-r>width||y-r>height)continue;
  const [red,green,blue]=rgb(light.color),s=Math.max(.05,Math.min(.99,light.softness||.75));
  const mode=light.blendMode||'add';
  g.save();
  g.globalCompositeOperation=mode==='normal'?'source-over':mode==='subtract'?'multiply':'lighter';
  const pixel=light.pixel||{},size=pixel.enabled?Math.max(2,Math.round(pixel.size*project.scale())):0;
  const steps=pixel.enabled?Math.max(2,pixel.steps||6):0;
  if(size){
    const left=Math.max(0,Math.floor((x-r)/size)*size),top=Math.max(0,Math.floor((y-r)/size)*size);
    const right=Math.min(width,x+r),bottom=Math.min(height,y+r);
    for(let yy=top;yy<bottom;yy+=size)for(let xx=left;xx<right;xx+=size){
      const d=Math.hypot(xx+size/2-x,yy+size/2-y)/r;if(d>=1)continue;
      const fall=Math.pow(1-d,1/s),alpha=Math.round(fall*steps)/steps*intensity;
      if(alpha<=0)continue;
      g.fillStyle=mode==='subtract'?'rgba(0,0,0,'+(alpha*.86)+')':'rgba('+red+','+green+','+blue+','+alpha+')';
      g.fillRect(xx,yy,size,size);
    }
  }else{
    const grad=g.createRadialGradient(x,y,0,x,y,r);
    if(mode==='subtract'){
      grad.addColorStop(0,'rgba(0,0,0,'+intensity+')');grad.addColorStop(1,'rgba(255,255,255,1)');
    }else{
      grad.addColorStop(0,'rgba('+red+','+green+','+blue+','+intensity+')');
      grad.addColorStop(s,'rgba('+red+','+green+','+blue+','+(intensity*.28)+')');
      grad.addColorStop(1,'rgba('+red+','+green+','+blue+',0)');
    }
    g.fillStyle=grad;g.fillRect(x-r,y-r,r*2,r*2);
  }
  g.restore();
 }
}
