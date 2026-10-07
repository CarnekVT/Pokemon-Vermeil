import { createScene, cmd, slug, commandStateSignature } from "./model.js";

const KNOWN=new Set([
  "bgm","bgs","se","stop_bgm","stop_bgs",
  "fade_from_black","fade_to_black","to_white","from_white",
  "show_textbox","hide_textbox","show","hide","hide_all","wait",
  "text_inline","show_centered_text","hide_centered_text","transfer_player","name_input",
  "float_sprite","stop_float","start_aura","stop_aura","change_float_bitmap",
  "start_scrolling","stop_scrolling","show_floating","hide_floating",
  "fade_out_images","fade_out_floating","fade_out_scrolling","fade_in_scrolling","fade_out_sprites"
]);

function rubyString(s){
  s=String(s||"").trim();
  if((s.startsWith('"')&&s.endsWith('"'))||(s.startsWith("'")&&s.endsWith("'"))){
    try{
      if(s[0]==='"')return JSON.parse(s);
      return s.slice(1,-1).replace(/\\'/g,"'").replace(/\\n/g,"\n").replace(/\\\\/g,"\\");
    }catch{}
  }
  return s;
}

function splitArgs(s){
  const out=[];let cur="",q=null,esc=false,depth=0;
  for(let i=0;i<s.length;i++){
    const ch=s[i];
    if(q){cur+=ch;if(esc){esc=false;continue}if(ch==='\\'){esc=true;continue}if(ch===q)q=null;continue}
    if(ch==='"'||ch==="'"){q=ch;cur+=ch;continue}
    if("([{ ".includes(ch)&&ch!==" ")depth++;
    if(")] }".includes(ch)&&ch!==" ")depth=Math.max(0,depth-1);
    if(ch===","&&depth===0){out.push(cur.trim());cur=""}else cur+=ch;
  }
  if(cur.trim())out.push(cur.trim());
  return out;
}

function val(s){
  s=String(s||"").trim();
  if(/^[-+]?\d+(\.\d+)?$/.test(s))return Number(s);
  if(s==="true")return true;if(s==="false")return false;if(s==="nil")return null;
  if(/^:/.test(s))return s.slice(1);
  if(/^Color\.new\(/.test(s))return splitArgs(s.replace(/^Color\.new\(/,"").replace(/\)$/,"")).map(Number);
  if(/^\[.*\]$/s.test(s))return splitArgs(s.slice(1,-1)).map(x=>/^[a-z_]\w*$/i.test(x)?{kind:"var",value:x}:val(x));
  if((s.startsWith('"')&&s.endsWith('"'))||(s.startsWith("'")&&s.endsWith("'")))return rubyString(s);
  return {kind:"ruby",value:s};
}

function parseCall(src){
  const normalized=src.trim().replace(/\n\s*/g," ");
  const m=normalized.match(/^(?:([a-z_]\w*)\s*=\s*)?([a-z_]\w*)\s*(.*)$/is);
  if(!m||!KNOWN.has(m[2]))return null;
  const store=m[1]||"",type=m[2];
  let raw=m[3].trim();
  if(raw.startsWith("(")&&raw.endsWith(")"))raw=raw.slice(1,-1).trim();
  const parts=splitArgs(raw),pos=[],kw={},rawPos=[];
  for(const p of parts){
    const k=p.match(/^([a-z_]\w*):\s*(.*)$/is);
    if(k)kw[k[1]]=val(k[2]);else{rawPos.push(p);pos.push(val(p));}
  }
  const c=cmd(type);if(store)c.store=store;
  switch(type){
    case"wait":c.frames=pos[0]??20;break;
    case"bgm":case"bgs":case"se":c.name=pos[0]??"";break;
    case"stop_bgm":c.fadeSeconds=pos[0]??0;break;
    case"fade_from_black":case"fade_to_black":case"to_white":c.duration=pos[0]??20;break;
    case"from_white":c.duration=pos[0]??20;c.se=kw.se??"";break;
    case"show_textbox":case"hide_textbox":c.duration=pos[0]??10;break;
    case"show":c.filename=pos[0]??"";c.x=pos[1]??0;c.y=pos[2]??0;c.fade=kw.fade??20;c.origin=kw.origin??"top_left";c.zoom=kw.zoom??1;c.z=kw.z??null;break;
    case"hide":c.filename=pos[0]??"";c.fade=kw.fade??0;break;
    case"hide_all":c.fade=kw.fade??0;break;
    case"text_inline":c.text=pos[0]??"";c.speaker=kw.speaker??"";c.speed=kw.speed??"normal";c.formatArgs=kw.format_args??[];break;
    case"show_centered_text":c.text=pos[0]??"";c.speed=kw.speed??"normal";c.color=kw.color??[0,0,0];break;
    case"transfer_player":c.mapId=pos[0]??1;c.x=pos[1]??0;c.y=pos[2]??0;c.direction=pos[3]??2;break;
    case"name_input":c.default=kw.default??"Solen";c.min=kw.min??1;c.max=kw.max??12;break;
    case"show_floating":c.filename=pos[0]??"";c.x=pos[1]??0;c.y=pos[2]??0;c.amplitude=kw.amplitude??8;c.speed=kw.speed??.05;c.z=kw.z??null;c.zoom=kw.zoom??1;c.opacity=kw.opacity??255;c.fade=kw.fade??0;break;
    case"float_sprite":c.filename=pos[0]??"";c.frameWidth=pos[1]??96;c.frameHeight=pos[2]??96;c.frames=pos[3]??6;c.x=pos[4]??0;c.y=pos[5]??0;c.endY=kw.end_y??160;c.speed=kw.speed??1;c.fps=kw.fps??6;c.ghostInterval=kw.ghost_interval??1;c.bg=kw.bg??false;c.glow=kw.glow??false;c.fade=kw.fade??20;break;
    case"stop_float":c.fade=kw.fade??0;break;
    case"change_float_bitmap":c.filename=pos[0]??"";break;
    case"start_aura":c.filename=pos[0]??"";c.frameWidth=pos[1]??12;c.frameHeight=pos[2]??12;c.count=kw.count??8;c.rangeX=kw.range_x??30;c.rangeY=kw.range_y??60;c.duration=kw.duration??120;break;
    case"start_scrolling":c.filename=pos[0]??"";c.x=pos[1]??0;c.y=pos[2]??0;c.speed=kw.speed??1;c.z=kw.z??null;c.mirror=kw.mirror??false;c.horizontal=kw.horizontal??false;break;
    case"fade_out_images":c.duration=pos[0]??20;c.filenames=Array.isArray(pos[1])?pos[1]:[];break;
    case"fade_out_floating":case"fade_out_scrolling":case"fade_in_scrolling":c.duration=pos[0]??20;break;
    case"fade_out_sprites":c.targetsRuby=rawPos[0]||"[]";c.duration=pos[1]??20;break;
  }
  return c;
}

function balanceDelta(line){
  let q=null,esc=false,d=0;
  for(const ch of line){
    if(q){if(esc){esc=false;continue}if(ch==='\\'){esc=true;continue}if(ch===q)q=null;continue}
    if(ch==='"'||ch==="'"){q=ch;continue}
    if("([{".includes(ch))d++;
    if(")] }".replace(/ /g,"").includes(ch))d--;
  }
  return d;
}

function blockOpen(trim){
  if(/^(if|unless|case|begin|while|until|for)\b/.test(trim))return 1;
  if(/\b(?:times|each|each_with_index|loop)\s+do\b/.test(trim))return 1;
  return 0;
}
function blockClose(trim){return /^end\b/.test(trim)?1:0;}
function stripIndent(line,indent){return line.startsWith(indent)?line.slice(indent.length):line.replace(/^\s{0,4}/,"");}
function dedentChunk(lines,indent){return lines.map(x=>stripIndent(x,indent)).join("\n");}
function withSource(c,source,lineNo,fileName){
  c.sourceRuby=source;
  c.sourceLine=lineNo;
  c.sourceFile=fileName;
  c.sourceState=commandStateSignature(c);
  return c;
}

export function importRubyScene(text,fileName="scene.rb"){
  const lines=String(text||"").replace(/\r/g,"").split("\n");
  const start=lines.findIndex(l=>/SceneEngine\.play\s+do/.test(l));
  if(start<0)throw new Error("No encontré 'SceneEngine.play do' en este Ruby.");
  const outerIndent=(lines[start].match(/^(\s*)/)||["",""])[1];
  const bodyIndent=outerIndent+"  ";
  let end=lines.length-1,depth=1;
  for(let j=start+1;j<lines.length;j++){
    const tr=lines[j].trim();
    depth+=blockOpen(tr);depth-=blockClose(tr);
    if(depth===0){end=j;break;}
  }

  const scene=createScene(fileName.replace(/\.rb$/i,""));
  scene.key=slug(scene.name);scene.commands=[];
  scene.importInfo={sourceFile:fileName,sourceMethod:(lines.slice(0,start+1).join("\n").match(/def\s+([a-zA-Z_]\w*)[^\n]*[\s\S]*$/)||[])[1]||null,roundTrip:true};

  let i=start+1,script=[];
  const flushScript=()=>{
    if(script.some(x=>x.text.trim())){
      const code=script.map(x=>stripIndent(x.text,bodyIndent)).join("\n").replace(/\s+$/g,"");
      const c=cmd("script",{code});c.sourceLine=script[0].line;c.sourceFile=fileName;scene.commands.push(c);
    }
    script=[];
  };

  while(i<end){
    const line=lines[i],trim=line.trim(),lineNo=i+1;
    if(!trim){if(script.length)script.push({text:line,line:lineNo});i++;continue;}
    if(/^#/.test(trim)){
      const phase=trim.match(/FASE\s*(\d*)\s*:\s*(.+?)(?:\s*[═]+)?$/i);
      if(phase){
        flushScript();
        const c=cmd("section",{label:phase[2].trim(),phase:phase[1]?Number(phase[1]):null});
        scene.commands.push(withSource(c,stripIndent(line,bodyIndent),lineNo,fileName));
      }else script.push({text:line,line:lineNo});
      i++;continue;
    }

    if(blockOpen(trim)){
      flushScript();
      const chunk=[line];let d=blockOpen(trim)-blockClose(trim);let j=i;
      while(++j<end&&d>0){chunk.push(lines[j]);const t=lines[j].trim();d+=blockOpen(t);d-=blockClose(t);}
      const c=cmd("script",{code:dedentChunk(chunk,bodyIndent).replace(/\s+$/g,"")});
      c.sourceLine=lineNo;c.sourceFile=fileName;scene.commands.push(c);i=j;continue;
    }

    const chunk=[line];let d=balanceDelta(trim),j=i;
    while(j+1<end&&(d>0||/[,:]\s*$/.test(chunk[chunk.length-1].trim()))){
      j++;chunk.push(lines[j]);d+=balanceDelta(lines[j]);
    }
    const src=dedentChunk(chunk,bodyIndent);
    const parsed=parseCall(src);
    if(parsed){
      flushScript();scene.commands.push(withSource(parsed,src,lineNo,fileName));i=j+1;continue;
    }

    script.push({text:line,line:lineNo});i++;
  }
  flushScript();
  return scene;
}
