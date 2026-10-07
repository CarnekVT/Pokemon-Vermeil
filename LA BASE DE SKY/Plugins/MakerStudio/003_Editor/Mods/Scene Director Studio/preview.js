import { loadProjectBlobUrl, mimeFor } from "./project.js";

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));

export class ScenePreview{
  constructor(ctx,host,getEngine){
    this.ctx=ctx;this.host=host;this.getEngine=getEngine;this.w=640;this.h=480;this.zoom=1;
    this.canvas=document.createElement("canvas");this.canvas.className="sd-canvas";this.host.appendChild(this.canvas);this.g=this.canvas.getContext("2d");
    this.cache=new Map();this.urls=[];this.playToken=0;this.onCommand=null;this.onWaiting=null;this.autoAdvance=false;this.audio={bgm:null,bgs:null,ses:new Set()};this.textBoxImg=null;this.gameFontFace=null;this.gameFontFamily='"Power Green", "Arial Narrow", Arial, sans-serif';this.whiteCache=new WeakMap();
    this.inputSerial=0;this.resetState();this.resize(640,480);this.last=performance.now();this.raf=requestAnimationFrame(()=>this.tick());this.refreshEngineAssets();
  }
  resize(w,h){this.w=w;this.h=h;this.canvas.width=w;this.canvas.height=h;this.fit();}
  settings(){return this.getEngine?.()?.settings||{};}
  num(v,fallback=0){
    if(v&&typeof v==="object"&&v.kind==="ruby"){
      let e=String(v.value||"");
      const repl={"Graphics.width":this.w,"Graphics.height":this.h,"SceneEngine::Settings::LAYER_IMG":200,"SceneEngine::Settings::LAYER_TEXTBOX":500,"SceneEngine::Settings::LAYER_TEXT":510,"SceneEngine::Settings::LAYER_OVERLAY":9000};
      for(const [k,x] of Object.entries(repl))e=e.split(k).join(String(x));
      if(/^[0-9+\-*/().\s]+$/.test(e)){try{const n=Number(Function(`"use strict";return (${e})`)());return Number.isFinite(n)?n:fallback}catch{}}
      return fallback;
    }
    const n=Number(v);return Number.isFinite(n)?n:fallback;
  }
  async refreshEngineAssets(){
    const e=this.settings(),base=e.scenesDir||"Graphics/Scenes",name=e.textBoxFile||"txt";this.textBoxImg=await this.image(`${base}/${name}`);
    this.gameFontFamily=`"${String(e.fontName||"Power Green").replace(/"/g,"")}", "Power Green", "Arial Narrow", Arial, sans-serif`;
    if(e.fontFile&&typeof FontFace!=="undefined"){
      try{const url=await loadProjectBlobUrl(this.ctx,e.fontFile,mimeFor(e.fontFile));if(url){this.urls.push(url);const fam=`SceneDirectorGameFont_${Date.now()}`;const face=new FontFace(fam,`url(${url})`);await face.load();document.fonts.add(face);this.gameFontFace=face;this.gameFontFamily=`"${fam}", ${this.gameFontFamily}`;}}catch{}
    }
  }
  fit(){const r=this.host.getBoundingClientRect(),z=Math.min((r.width-24)/this.w,(r.height-24)/this.h,2);this.setZoom(Math.max(.25,z||1),false);}
  setZoom(z,manual=true){this.zoom=clamp(z,.2,4);this.canvas.style.width=`${this.w*this.zoom}px`;this.canvas.style.height=`${this.h*this.zoom}px`;if(manual)this.host.dataset.manualZoom="1";}
  resetState(){
    this.state={frame:0,images:new Map(),floating:[],refs:new Map(),aliases:new Map(),scrolling:[],float:null,aura:[],black:255,white:0,textbox:0,text:null,centered:null,indicator:false,vars:new Map()};
  }
  async image(path){
    if(!path)return null;if(this.cache.has(path))return this.cache.get(path);let p=String(path);if(!/\.[a-z0-9]+$/i.test(p))p+=".png";
    const pr=(async()=>{const url=await loadProjectBlobUrl(this.ctx,p,mimeFor(p));if(!url)return null;this.urls.push(url);const im=new Image();await new Promise((ok,fail)=>{im.onload=ok;im.onerror=fail;im.src=url});return im})().catch(()=>null);
    this.cache.set(path,pr);return pr;
  }
  tick(){const now=performance.now(),dt=Math.min(.05,(now-this.last)/1000);this.last=now;this.state.frame+=dt*60;this.draw();this.raf=requestAnimationFrame(()=>this.tick());}
  gameFont(size=null){const px=Number(size||this.settings().fontSize||29);this.g.font=`${px}px ${this.gameFontFamily}`;this.g.textBaseline="top";}
  rgba(c,fallback){const a=Array.isArray(c)?c:fallback;return `rgb(${a?.[0]??255},${a?.[1]??255},${a?.[2]??255})`;}
  drawShadowText(text,x,y,color,shadow){const g=this.g;g.fillStyle=shadow;g.fillText(text,x+2,y+2);g.fillStyle=color;g.fillText(text,x,y);}
  partialLine(line,index,lines,revealed){let drawn=0;for(let i=0;i<index;i++)drawn+=lines[i].length+1;const remaining=revealed-drawn;if(remaining<=0)return"";return line.slice(0,Math.min(line.length,remaining));}
  floatMetrics(f){
    const elapsed=Math.max(0,this.state.frame-(f.startFrame||0)),fps=f.fps||6,frameInterval=Math.max(1,Math.round(60/fps));
    const frame=Math.floor(elapsed/frameInterval)%Math.max(1,f.frames||1),speed=Number(f.speed)||0,travel=speed>0?Math.max(0,(f.endY-f.y)/speed):0,landed=speed<=0||elapsed>=travel;
    const sy=!f.active?f.y:(!landed?Math.min(f.endY,f.y+elapsed*speed):f.endY+Math.sin(Math.max(0,elapsed-travel)*.04)*3);
    return {elapsed,frameInterval,frame,travel,landed,sy};
  }
  whiteFrame(img,sx,sy,sw,sh){
    let byImg=this.whiteCache.get(img);if(!byImg){byImg=new Map();this.whiteCache.set(img,byImg)}const key=`${sx},${sy},${sw},${sh}`;if(byImg.has(key))return byImg.get(key);
    const c=document.createElement("canvas");c.width=sw;c.height=sh;const x=c.getContext("2d");x.drawImage(img,sx,sy,sw,sh,0,0,sw,sh);x.globalCompositeOperation="source-in";x.fillStyle="#fff";x.fillRect(0,0,sw,sh);x.globalCompositeOperation="source-over";byImg.set(key,c);return c;
  }
  drawFrame(img,frame,fw,fh,x,y,{alpha=1,zoom=1,white=false,additive=false}={}){
    if(!img||alpha<=0)return;const g=this.g,sx=Math.max(0,frame|0)*fw,src=white?this.whiteFrame(img,sx,0,fw,fh):img;g.save();g.globalAlpha=clamp(alpha,0,1);if(additive)g.globalCompositeOperation="lighter";
    if(white)g.drawImage(src,0,0,fw,fh,x,y,fw*zoom,fh*zoom);else g.drawImage(src,sx,0,fw,fh,x,y,fw*zoom,fh*zoom);g.restore();
  }
  draw(){
    const g=this.g,s=this.state,e=this.settings(),queue=[];let seq=0;const push=(z,fn)=>queue.push({z:Number(z)||0,seq:seq++,fn});
    g.save();g.clearRect(0,0,this.w,this.h);g.fillStyle="#000";g.fillRect(0,0,this.w,this.h);
    const drawImg=(it,yoff=0)=>{if(!it?.img||it.visible===false)return;g.save();g.globalAlpha=clamp((it.opacity??255)/255,0,1);const zoom=it.zoom??1;let x=it.x||0,y=(it.baseY??it.y??0)+yoff;g.translate(x,y);g.scale(it.mirror?-1:1,1);if(it.mirror)g.translate(-it.img.width*zoom,0);g.drawImage(it.img,0,0,it.img.width*zoom,it.img.height*zoom);g.restore();};

    for(const it of s.images.values())push(it.z??200,()=>drawImg(it));
    for(const it of s.scrolling){
      push(it.z??250,()=>{if(!it.img||it.visible===false)return;const elapsed=Math.max(0,s.frame-(it.startFrame||0)),speed=it.speed||0;if(it.horizontal){const w=it.img.width||1,off=(elapsed*speed)%w;for(let x=-w+off;x<this.w+w;x+=w)drawImg({...it,x,y:it.y||0});}else{const h=it.img.height||1,period=h*2,delta=(elapsed*speed)%period;let y1=(it.y||0)-delta;while(y1+h<=0)y1+=period;while(y1>this.h)y1-=period;drawImg({...it,y:y1});drawImg({...it,y:y1-h});drawImg({...it,y:y1+h});}});
    }
    for(const it of s.floating)push(it.z??260,()=>{const elapsed=Math.max(0,s.frame-(it.startFrame||0)),yoff=Math.sin(elapsed*(it.speed||0))*this.num(it.amplitude,8);drawImg(it,yoff)});

    if(s.float?.img&&s.float.visible!==false){
      const f=s.float,m=this.floatMetrics(f),baseAlpha=clamp((f.opacity??255)/255,0,1);
      if(f.bg)push(350,()=>{g.save();g.globalAlpha=clamp((f.bgOpacity??f.opacity??255)/255,0,1);g.fillStyle="#000";g.fillRect(0,0,this.w,this.h);g.restore()});
      // Réplicas residuales exactamente al estilo update_float del Scene Engine:
      // nacen en los cambios de frame durante el ascenso, se blanquean/aditivan
      // cuando glow=true, suben 0.3 px/frame y pierden 4 de opacidad por frame.
      if(f.active){const maxK=Math.floor(m.elapsed/m.frameInterval),gi=Math.max(1,Math.round(f.ghostInterval||1)),ghosts=[];for(let k=gi;k<=maxK;k+=gi){const emit=k*m.frameInterval,age=m.elapsed-emit;if(age<0||age>40)continue;const ey=f.y+Math.max(0,emit-1)*(Number(f.speed)||0);if(ey<0||ey>=f.endY)continue;const op=160-4*age,zoom=1-.002*age;if(op<=0||zoom<=0)continue;ghosts.push({emit,age,ey,op,zoom,frame:k%Math.max(1,f.frames||1)})}ghosts.slice(-15).forEach((gh,i)=>push(399-i,()=>this.drawFrame(f.img,gh.frame,f.fw,f.fh,f.x,gh.ey+gh.age*.3,{alpha:(gh.op/255)*baseAlpha,zoom:gh.zoom,white:!!f.glow,additive:!!f.glow})))}
      push(400,()=>this.drawFrame(f.img,m.frame,f.fw,f.fh,f.x,m.sy,{alpha:baseAlpha}));
      if(f.glow&&f.glowVisible!==false){let ga=f.active?1:0;if(m.landed&&f.active)ga*=clamp(1-Math.max(0,m.elapsed-m.travel)/30,0,1);push(401,()=>this.drawFrame(f.img,m.frame,f.fw,f.fh,f.x,m.sy,{alpha:ga,white:true,additive:true}))}
    }

    for(const p of s.aura){push(450,()=>{if(!p.img)return;const elapsed=Math.max(0,s.frame-(p.startFrame||0)),phase=((p.phase0||0)+elapsed*(p.speed||1))%(p.duration||120),pr=phase/(p.duration||120),a=Math.sin(pr*Math.PI),f=s.float,m=f?this.floatMetrics(f):null,cx=f?f.x+f.fw/2:0,cy=f?(m.sy+f.fh/2):0;g.save();g.globalAlpha=clamp(a,0,1);g.drawImage(p.img,cx+p.xoff-p.fw/2,cy+p.rangeY-pr*(p.rangeY*2+p.fh),p.fw,p.fh);g.restore()})}

    if(s.textbox>0.001){
      const y=e.textBoxY??286,h=e.textBoxH??178,padX=e.textPadX??48,padTop=e.textPadYTop??42,lineH=e.textLineH??32;
      push(500,()=>{g.save();g.globalAlpha=clamp(s.textbox,0,1);if(this.textBoxImg)g.drawImage(this.textBoxImg,0,y);else{g.fillStyle="rgba(14,15,24,.92)";g.fillRect(0,y,this.w,h);g.strokeStyle="rgba(255,255,255,.22)";g.strokeRect(.5,y+.5,this.w-1,h-1)}g.restore()});
      if(s.text)push(510,()=>{g.save();g.globalAlpha=clamp(s.textbox,0,1);this.gameFont();const sp=s.text.speaker||"",map=e.speakerColorMap||{},pair=map[sp],spColor=this.rgba(pair?.[0],e.speakerColor||[248,208,48]),spShadow=this.rgba(pair?.[1],e.speakerShadow||[120,96,16]);if(sp)this.drawShadowText(sp,padX,y+12,spColor,spShadow);const tc=this.rgba(e.textColor,[248,248,248]),ts=this.rgba(e.textShadow,[72,72,72]),lines=s.text.pageLines||[],revealed=Math.floor(s.text.revealed??0);lines.forEach((ln,i)=>{const part=this.partialLine(ln,i,lines,revealed);if(part)this.drawShadowText(part,padX,y+padTop+i*lineH,tc,ts)});g.restore()});
      if(s.text&&s.indicator)push(511,()=>{if(Math.floor(s.frame)%40>=20)return;const c=e.textColor||[248,248,248],sc=e.textShadow||[72,72,72],x=this.w-padX-14,iy=y+h-24;g.save();const rect=(dx,dy,w,hh,col)=>{g.fillStyle=this.rgba(col,[255,255,255]);g.fillRect(x+dx,iy+dy,w,hh)};rect(1,1,14,2,sc);rect(3,3,10,2,sc);rect(5,5,6,2,sc);rect(7,7,2,2,sc);rect(0,0,14,2,c);rect(2,2,10,2,c);rect(4,4,6,2,c);rect(6,6,2,2,c);g.restore()});
    }

    if(s.black>0)push(9000,()=>{g.fillStyle=`rgba(0,0,0,${clamp(s.black/255,0,1)})`;g.fillRect(0,0,this.w,this.h)});
    if(s.white>0)push(9001,()=>{g.fillStyle=`rgba(255,255,255,${clamp(s.white/255,0,1)})`;g.fillRect(0,0,this.w,this.h)});
    if(s.centered)push(9010,()=>{this.gameFont();g.textAlign="center";g.textBaseline="middle";const text=String(s.centered.text||"").slice(0,Math.floor(s.centered.revealed??0));g.fillStyle=s.centered.color||"#000";g.fillText(text,this.w/2,this.h/2-16);g.textAlign="left";g.textBaseline="top"});

    queue.sort((a,b)=>a.z-b.z||a.seq-b.seq);for(const it of queue)it.fn();g.restore();
  }

  wordWrapAll(text,maxWidth){
    const g=this.g;this.gameFont();const safe=maxWidth-12,out=[];
    for(const para of String(text||"").split("\n")){
      const words=para.split(" ");let current="";
      for(const word of words){const test=current?current+" "+word:word;if(g.measureText(test).width>safe&&current){out.push(current);current=word}else current=test;}
      if(current)out.push(current);
    }
    return out;
  }
  formatText(text,args){let out=String(text||"");(args||[]).forEach((arg,i)=>{let v=arg;if(v&&typeof v==="object"&&v.kind==="var")v=this.state.vars.get(v.value)??`{${v.value}}`;else if(v&&typeof v==="object"&&v.kind==="ruby")v=this.state.vars.get(v.value)??v.value;out=out.split(`{${i+1}}`).join(String(v??""));});return out;}

  stop(){this.playToken++;this.stopAudio();this.state.indicator=false;this.onWaiting?.(false);}
  async reset(){this.stop();this.resetState();this.draw();}
  async play(scene,{from=0}={}){this.stop();const token=++this.playToken;this.resetState();for(let i=0;i<(scene.commands||[]).length;i++){if(token!==this.playToken)return;if(i<from){await this.apply(scene.commands[i],true,token);continue}this.onCommand?.(i,scene.commands[i]);await this.apply(scene.commands[i],false,token);}}
  async runTo(scene,index){this.stop();const token=++this.playToken;this.resetState();for(let i=0;i<=index&&i<(scene.commands||[]).length;i++){if(token!==this.playToken)return;await this.apply(scene.commands[i],true,token);}this.draw();}
  async frames(n,fn,skip,token){n=Math.max(1,Math.round(Number(n)||1));if(skip){this.state.frame+=n;fn?.(1);return}for(let i=0;i<n;i++){if(token!==this.playToken)return;fn?.((i+1)/n);await sleep(1000/60);}}

  async playAudio(kind,name){
    if(!name)return;let p=`Audio/${kind}/${name}`;if(!/\.[a-z0-9]+$/i.test(p))p+=".ogg";let url=await loadProjectBlobUrl(this.ctx,p,mimeFor(p));
    if(!url){for(const ex of [".ogg",".mp3",".wav"]){url=await loadProjectBlobUrl(this.ctx,p.replace(/\.[^.]+$/,ex),mimeFor(ex));if(url)break}}
    if(!url)return;const a=new Audio(url);if(kind!=="SE")a.loop=true;try{await a.play()}catch{}
    if(kind==="BGM"){this.audio.bgm?.pause();this.audio.bgm=a}else if(kind==="BGS"){this.audio.bgs?.pause();this.audio.bgs=a}else{this.audio.ses.add(a);a.onended=()=>this.audio.ses.delete(a)}
  }
  stopAudio(){for(const a of [this.audio.bgm,this.audio.bgs])try{a?.pause()}catch{};this.audio.bgm=this.audio.bgs=null;for(const a of this.audio.ses)try{a.pause()}catch{};this.audio.ses.clear();}

  continue(){this.inputSerial++;}
  async waitInput(token,serial){while(token===this.playToken&&this.inputSerial===serial)await sleep(1000/60);return this.inputSerial;}
  async showTextboxFade(skip,token,frames=10){if(this.state.textbox>=1)return;if(skip){this.state.textbox=1;return}const from=this.state.textbox;await this.frames(frames,p=>this.state.textbox=from+(1-from)*p,false,token);this.state.textbox=1;}
  async hideTextboxFade(skip,token,frames=10){if(this.state.textbox<=0)return;if(skip){this.state.textbox=0;this.state.indicator=false;return}const from=this.state.textbox;this.state.indicator=false;await this.frames(frames,p=>this.state.textbox=from*(1-p),false,token);this.state.textbox=0;}

  async pageText(obj,skip,token){
    const e=this.settings(),text=this.formatText(obj.text,obj.formatArgs),lines=this.wordWrapAll(text,this.w-(e.textPadX??48)*2),max=Math.max(1,e.textMaxLines||4),pages=[];
    for(let i=0;i<Math.max(1,Math.ceil(lines.length/max));i++)pages.push(lines.slice(i*max,i*max+max));if(!pages.length)pages.push([""]);
    const target={speaker:obj.speaker||"",pageLines:pages[0],revealed:0,page:0};this.state.text=target;
    await this.showTextboxFade(skip,token,10);
    if(skip){target.page=pages.length-1;target.pageLines=pages[target.page];target.revealed=target.pageLines.join("\n").length;return;}
    const cpf=e.speeds?.[obj.speed||"normal"]??1.5;
    for(let page=0;page<pages.length;page++){
      target.page=page;target.pageLines=pages[page];target.revealed=0;const pageText=target.pageLines.join("\n"),len=pageText.length,ellipsis=[];
      for(let i=0;i<len;){if(pageText.slice(i,i+3)==="..."){ellipsis.push(i,i+1,i+2);i+=3}else i++;}
      let serial=this.inputSerial;
      while(target.revealed<len&&token===this.playToken){
        let eff=cpf;if(ellipsis.includes(Math.floor(target.revealed)))eff*=.1;target.revealed=Math.min(len,target.revealed+eff);await sleep(1000/60);
        if(this.inputSerial!==serial){target.revealed=len;serial=this.inputSerial;}
      }
      if(token!==this.playToken)return;target.revealed=len;this.state.indicator=true;this.onWaiting?.(true);
      if(this.autoAdvance){await this.frames(35,null,false,token);}else await this.waitInput(token,serial);
      this.state.indicator=false;this.onWaiting?.(false);
    }
  }

  async centeredText(obj,skip,token){
    const e=this.settings(),text=this.formatText(obj.text,obj.formatArgs),cpf=e.speeds?.[obj.speed||"normal"]??1.5,color=`rgb(${(obj.color||[0,0,0]).slice(0,3).join(",")})`;this.state.centered={text,revealed:skip?text.length:0,color};if(skip)return;
    let serial=this.inputSerial;while(this.state.centered.revealed<text.length&&token===this.playToken){this.state.centered.revealed=Math.min(text.length,this.state.centered.revealed+cpf);await sleep(1000/60);if(this.inputSerial!==serial){this.state.centered.revealed=text.length;serial=this.inputSerial;}}
  }

  resolveSpriteTargets(expr){
    const s=this.state,targets=[];const add=x=>{if(x&&!targets.includes(x))targets.push(x)};expr=String(expr||"");
    for(const m of expr.matchAll(/\b([a-z_]\w*)\[:sprite\]/gi))add(s.refs.get(m[1]));
    for(const m of expr.matchAll(/\b([a-z_]\w*)&?\.\[\]\(:sprite\)/gi))add(s.refs.get(m[1]));
    for(const m of expr.matchAll(/@image_sprites\["([^"]+)"\]/g))add(s.images.get(m[1]));
    if(/@scrolling_sprites|\*clouds\b/.test(expr))s.scrolling.forEach(add);
    if(/@float_anim\[:sprite\]/.test(expr))add(s.float);
    return targets;
  }
  async fadeTargets(expr,duration,skip,token){const targets=this.resolveSpriteTargets(expr);if(!targets.length)return;if(skip){targets.forEach(x=>x.opacity=0);return}const starts=targets.map(x=>x.opacity??255);await this.frames(duration,p=>targets.forEach((x,i)=>x.opacity=starts[i]*(1-p)),false,token);}

  async applyScriptPreview(code,skip,token){
    const s=this.state,src=String(code||"");
    // Alias de referencias usadas por escenas Ruby existentes.
    for(const m of src.matchAll(/^\s*([a-z_]\w*)\s*=\s*@floating_sprites\.first\s*$/gmi))s.refs.set(m[1],s.floating[0]||null);
    for(const m of src.matchAll(/^\s*([a-z_]\w*)\s*=\s*@scrolling_sprites\.flat_map/gmi))s.aliases.set(m[1],"scrolling");
    for(const m of src.matchAll(/@image_sprites\["([^"]+)"\]&?\.visible\s*=\s*(true|false)/gi)){const it=s.images.get(m[1]);if(it)it.visible=m[2]==="true";}
    const fv=[...src.matchAll(/@float_anim\[:sprite\]\.visible\s*=\s*(true|false)/gi)].pop();if(fv&&s.float)s.float.visible=fv[1]==="true";
    const gv=[...src.matchAll(/@float_anim\[:glow\]\.visible\s*=\s*(true|false)/gi)].pop();if(gv&&s.float)s.float.glowVisible=gv[1]==="true";
    const bo=src.match(/@sprites\[:black\]\.opacity\s*=\s*(\d+)/);if(bo)s.black=Number(bo[1]);

    // Loops de fade-in manual (elder/elder6 en la intro real).
    const fade=src.match(/(\d+)\.times\s+do[\s\S]*?\b([a-z_]\w*)\[:sprite\]\.opacity\s*=\s*\(255\s*\*\s*progress\)\.round/i);
    if(fade){const frames=Number(fade[1]),it=s.refs.get(fade[2]);if(it){const start=it.opacity??0;if(skip)it.opacity=255;else await this.frames(frames,p=>it.opacity=start+(255-start)*p,false,token);}}

    // Tween manual de zoom/posición de un floating ref. Mantiene la lógica visual de scripts importados comunes.
    const tween=src.match(/(\d+)\.times\s+do[\s\S]*?\b([a-z_]\w*)\[:sprite\]\.zoom_x\s*=\s*z[\s\S]*?\2\[:base_y\]\s*=\s*cy/i);
    if(tween){
      const frames=Number(tween[1]),it=s.refs.get(tween[2]);if(it){const zline=(src.match(/^\s*z\s*=\s*(.+)$/mi)||[])[1],cyline=(src.match(/^\s*cy\s*=\s*(.+)$/mi)||[])[1];
        const evalP=(expr,p,fallback)=>{if(!expr)return fallback;let e=expr.replace(/progress/g,String(p)).replace(/Graphics\.width/g,String(this.w)).replace(/Graphics\.height/g,String(this.h));if(/^[0-9+\-*/().\s]+$/.test(e)){try{return Number(Function(`return (${e})`)())}catch{}}return fallback};
        const apply=p=>{const z=evalP(zline,p,it.zoom??1),cy=evalP(cyline,p,(it.baseY??it.y??0)+(it.img?.height||0)*z/2);it.zoom=z;if(/Graphics\.width\s*\/\s*2/.test(src)&&it.img)it.x=this.w/2-it.img.width*z/2;if(it.img)it.baseY=cy-it.img.height*z/2;};
        if(skip)apply(1);else await this.frames(frames,apply,false,token);
      }
    }
  }

  async apply(c,skip,token){
    const s=this.state;
    switch(c.type){
      case"section":break;
      case"script":await this.applyScriptPreview(c.code,skip,token);break;
      case"wait":await this.frames(c.frames,null,skip,token);break;
      case"bgm":if(!skip)await this.playAudio("BGM",c.name);break;
      case"bgs":if(!skip)await this.playAudio("BGS",c.name);break;
      case"se":if(!skip)await this.playAudio("SE",c.name);break;
      case"stop_bgm":this.audio.bgm?.pause();this.audio.bgm=null;break;
      case"stop_bgs":this.audio.bgs?.pause();this.audio.bgs=null;break;
      case"fade_from_black":s.black=255;await this.frames(c.duration,p=>s.black=255*(1-p),skip,token);break;
      case"fade_to_black":s.black=0;await this.frames(c.duration,p=>s.black=255*p,skip,token);break;
      case"to_white":s.white=0;await this.frames(c.duration,p=>s.white=255*p,skip,token);break;
      case"from_white":s.white=255;if(c.se&&!skip)await this.playAudio("SE",c.se);await this.frames(c.duration,p=>s.white=255*(1-p),skip,token);break;
      case"show":{
        const im=await this.image(c.filename);if(im){let x=this.num(c.x,0),y=this.num(c.y,0),zoom=this.num(c.zoom,1);if(c.origin==="center"){x-=im.width*zoom/2;y-=im.height*zoom/2}else if(c.origin==="bottom"){x-=im.width*zoom/2;y-=im.height*zoom}const fade=this.num(c.fade,20),it={img:im,x,y,z:this.num(c.z,200+s.images.size),zoom,opacity:fade>0?0:255,visible:true};s.images.set(c.filename,it);if(fade>0)await this.frames(fade,p=>it.opacity=255*p,skip,token);it.opacity=255;}break;}
      case"hide":{const a=c.filename?[s.images.get(c.filename)]:[...s.images.values()];const targets=a.filter(Boolean);if(c.fade>0)await this.frames(c.fade,p=>targets.forEach(x=>x.opacity=255*(1-p)),skip,token);targets.forEach(x=>x.visible=false);break;}
      case"hide_all":{const targets=[...s.images.values()];if(c.fade>0)await this.frames(c.fade,p=>targets.forEach(x=>x.opacity=255*(1-p)),skip,token);targets.forEach(x=>x.visible=false);break;}
      case"text_inline":await this.pageText(c,skip,token);break;
      case"show_centered_text":await this.centeredText(c,skip,token);break;
      case"hide_centered_text":s.centered=null;break;
      case"show_textbox":await this.showTextboxFade(skip,token,c.duration);break;
      case"hide_textbox":await this.hideTextboxFade(skip,token,c.duration);break;
      case"name_input":if(c.store)s.vars.set(c.store,c.default||"Solen");break;
      case"show_floating":{
        const im=await this.image(c.filename);if(im){const it={img:im,x:this.num(c.x,0),y:this.num(c.y,0),baseY:this.num(c.y,0),amplitude:this.num(c.amplitude,8),speed:this.num(c.speed,.05),zoom:this.num(c.zoom,1),opacity:c.fade>0?0:this.num(c.opacity,255),z:this.num(c.z,260),startFrame:s.frame,visible:true,varName:c.store||""};s.floating.push(it);if(c.store)s.refs.set(c.store,it);if(c.fade>0)await this.frames(c.fade,p=>it.opacity=this.num(c.opacity,255)*p,skip,token);it.opacity=this.num(c.opacity,255);}break;}
      case"hide_floating":s.floating=[];s.refs=new Map([...s.refs].filter(([,v])=>!v||!v.img));break;
      case"float_sprite":{
        const im=await this.image(c.filename);if(im){const f={img:im,fw:this.num(c.frameWidth,96),fh:this.num(c.frameHeight,96),frames:this.num(c.frames,6),x:this.num(c.x,0),y:this.num(c.y,0),endY:this.num(c.endY,0),speed:Number(c.speed)||0,fps:this.num(c.fps,6),ghostInterval:this.num(c.ghostInterval,1),bg:!!c.bg,glow:!!c.glow,glowVisible:true,visible:true,opacity:c.fade>0?0:255,bgOpacity:c.fade>0?0:255,startFrame:s.frame,active:false};s.float=f;if(c.fade>0)await this.frames(c.fade,p=>{f.opacity=255*p;f.bgOpacity=255*p},skip,token);f.opacity=f.bgOpacity=255;f.active=true;f.startFrame=s.frame;}break;}
      case"stop_float":{if(c.fade>0&&s.float){const f=s.float,start=f.opacity??255;await this.frames(c.fade,p=>f.opacity=start*(1-p),skip,token);}s.float=null;break;}
      case"change_float_bitmap":if(s.float){const im=await this.image(c.filename);if(im)s.float.img=im;}break;
      case"start_aura":{
        const im=await this.image(c.filename);if(im)s.aura=Array.from({length:this.num(c.count,8)},(_,i)=>({img:im,fw:Number(c.frameWidth)||12,fh:Number(c.frameHeight)||12,rangeY:this.num(c.rangeY,60),duration:this.num(c.duration,120),xoff:((((i*37)%100)/100)-.5)*this.num(c.rangeX,30)*2,phase0:(i*29)%this.num(c.duration,120),speed:.6+((i*17)%10)/10*.8,startFrame:s.frame}));break;}
      case"stop_aura":s.aura=[];break;
      case"start_scrolling":{const im=await this.image(c.filename);if(im)s.scrolling.push({img:im,x:this.num(c.x,0),y:this.num(c.y,0),speed:this.num(c.speed,1),horizontal:!!c.horizontal,mirror:!!c.mirror,opacity:255,z:this.num(c.z,250),startFrame:s.frame,visible:true});break;}
      case"stop_scrolling":s.scrolling=[];break;
      case"fade_out_images":{const targets=(c.filenames?.length?c.filenames.map(k=>s.images.get(typeof k==="string"?k:k?.value)).filter(Boolean):[...s.images.values()]);await this.frames(c.duration,p=>targets.forEach(x=>x.opacity=255*(1-p)),skip,token);break;}
      case"fade_out_floating":await this.frames(c.duration,p=>s.floating.forEach(x=>x.opacity=255*(1-p)),skip,token);break;
      case"fade_out_scrolling":await this.frames(c.duration,p=>s.scrolling.forEach(x=>x.opacity=255*(1-p)),skip,token);break;
      case"fade_in_scrolling":await this.frames(c.duration,p=>s.scrolling.forEach(x=>x.opacity=255*p),skip,token);break;
      case"fade_out_sprites":await this.fadeTargets(c.targetsRuby,c.duration,skip,token);break;
    }
  }
  destroy(){this.stop();cancelAnimationFrame(this.raf);for(const u of this.urls)URL.revokeObjectURL(u);this.host.innerHTML="";}
}
