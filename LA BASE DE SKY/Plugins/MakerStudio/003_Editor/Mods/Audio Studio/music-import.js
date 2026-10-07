const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));

function u16(d,p){return (d[p]<<8)|d[p+1];}
function u32(d,p){return ((d[p]<<24)>>>0)|(d[p+1]<<16)|(d[p+2]<<8)|d[p+3];}
function str(d,p,n){let s='';for(let i=0;i<n;i++)s+=String.fromCharCode(d[p+i]);return s;}
function varlen(d,p){let v=0,b=0;do{if(p>=d.length)throw new Error('Unexpected end of MIDI data');b=d[p++];v=(v<<7)|(b&0x7f);}while(b&0x80);return [v,p];}
function decodeText(bytes){try{return new TextDecoder('utf-8').decode(bytes).replace(/\0/g,'').trim();}catch{return Array.from(bytes,b=>String.fromCharCode(b)).join('').replace(/\0/g,'').trim();}}

function tempoMapToSeconds(tempos,ppq){
  const list=[...tempos].sort((a,b)=>a.tick-b.tick);if(!list.length||list[0].tick!==0)list.unshift({tick:0,us:500000});
  const compact=[];for(const t of list){if(compact.length&&compact[compact.length-1].tick===t.tick)compact[compact.length-1]=t;else compact.push(t);}
  let lastTick=compact[0].tick,lastSec=0,lastUs=compact[0].us;for(let i=1;i<compact.length;i++){const t=compact[i];lastSec+=(t.tick-lastTick)*lastUs/1000000/ppq;t.sec=lastSec;lastTick=t.tick;lastUs=t.us;}compact[0].sec=0;
  return tick=>{let lo=0,hi=compact.length-1;while(lo<hi){const m=Math.ceil((lo+hi)/2);if(compact[m].tick<=tick)lo=m;else hi=m-1;}const t=compact[lo];return (t.sec||0)+(tick-t.tick)*t.us/1000000/ppq;};
}
function gmFamily(program){program=program|0;if(program<=7)return'Piano';if(program<=15)return'Chromatic';if(program<=23)return'Organ';if(program<=31)return'Guitar';if(program<=39)return'Bass';if(program<=47)return'Strings';if(program<=55)return'Ensemble';if(program<=63)return'Brass';if(program<=71)return'Reed';if(program<=79)return'Pipe';if(program<=87)return'Synth Lead';if(program<=95)return'Synth Pad';if(program<=103)return'Synth FX';if(program<=111)return'Ethnic';if(program<=119)return'Percussive';return'FX';}
function drumType(note){if([35,36].includes(note))return'kick';if([37,38,39,40].includes(note))return'snare';if([42,44,46,49,51,52,53,55,57,59].includes(note))return'hat';if(note<42)return'kick';return note<49?'snare':'hat';}
function polyphonyScore(notes){if(notes.length<2)return 0;const points=[];for(const n of notes){points.push([n.start,1],[n.start+n.duration,-1]);}points.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);let on=0,max=0,poly=0;for(const [,v] of points){on+=v;max=Math.max(max,on);if(on>1)poly++;}return Math.max(max>1?1:0,poly/Math.max(1,points.length));}
function suggestedTrack(track){const name=String(track.name||'').toLowerCase();if(track.isDrum||/drum|perc|kit|rhythm|beat/.test(name))return'drums';if(/bass|contrabass/.test(name)||gmFamily(track.program)==='Bass')return'bass';if(/chord|harmony|pad|string|ensemble|accomp/.test(name))return'harmony';if(/melody|lead|solo|vocal|voice|flute|sax|trumpet/.test(name))return'melody';const avg=track.notes.length?track.notes.reduce((s,n)=>s+n.midi,0)/track.notes.length:60;if(avg<50)return'bass';if(polyphonyScore(track.notes)>.14)return'harmony';return'melody';}

export function parseMidi(arrayBuffer,name='MIDI'){
  const d=new Uint8Array(arrayBuffer);if(str(d,0,4)!=='MThd')throw new Error('Not a Standard MIDI File');const hlen=u32(d,4),format=u16(d,8),ntrks=u16(d,10),division=u16(d,12);if(division&0x8000)throw new Error('SMPTE-timed MIDI is not supported yet');const ppq=division||480;let p=8+hlen;const tempos=[];const parsed=[];
  for(let ti=0;ti<ntrks;ti++){
    if(str(d,p,4)!=='MTrk')throw new Error(`Missing MIDI track ${ti+1}`);const len=u32(d,p+4),end=p+8+len;let i=p+8,tick=0,running=0,trackName=`Track ${ti+1}`,program=0;const open=new Map(),notes=[],channels=new Set();
    const close=(ch,note,at)=>{const key=`${ch}:${note}`,stack=open.get(key);if(!stack?.length)return;const on=stack.shift();if(!stack.length)open.delete(key);notes.push({startTick:on.tick,endTick:Math.max(on.tick+1,at),midi:note,velocity:clamp(on.velocity/127,.05,1),channel:ch});};
    while(i<end){let delta;[delta,i]=varlen(d,i);tick+=delta;let status=d[i++];if(status<0x80){i--;status=running;}else if(status<0xf0)running=status;
      if(status===0xff){const type=d[i++];let l;[l,i]=varlen(d,i);const bytes=d.slice(i,i+l);if(type===0x03&&bytes.length)trackName=decodeText(bytes)||trackName;else if(type===0x51&&l===3)tempos.push({tick,us:(bytes[0]<<16)|(bytes[1]<<8)|bytes[2]});i+=l;continue;}
      if(status===0xf0||status===0xf7){let l;[l,i]=varlen(d,i);i+=l;continue;}
      const op=status&0xf0,ch=status&0x0f;channels.add(ch);if(op===0x80||op===0x90){const note=d[i++],vel=d[i++];if(op===0x90&&vel>0){const key=`${ch}:${note}`;if(!open.has(key))open.set(key,[]);open.get(key).push({tick,velocity:vel});}else close(ch,note,tick);}else if(op===0xc0){program=d[i++];}else if(op===0xd0){i+=1;}else{i+=2;}
    }
    for(const [key,stack] of open){const [ch,note]=key.split(':').map(Number);for(const on of stack)notes.push({startTick:on.tick,endTick:Math.max(on.tick+1,tick),midi:note,velocity:clamp(on.velocity/127,.05,1),channel:ch});}
    parsed.push({index:ti,name:trackName,program,channels:[...channels],rawNotes:notes});p=end;
  }
  const toSec=tempoMapToSeconds(tempos,ppq);const bpm=tempos.length?Math.round(60000000/tempos.sort((a,b)=>a.tick-b.tick)[0].us):120;
  const tracks=parsed.map(t=>{const isDrum=t.rawNotes.length>0&&t.rawNotes.filter(n=>n.channel===9).length/t.rawNotes.length>.5;const notes=t.rawNotes.filter(n=>!isDrum&&n.channel!==9).map(n=>({start:toSec(n.startTick),duration:Math.max(.02,toSec(n.endTick)-toSec(n.startTick)),midi:n.midi,velocity:n.velocity}));const drums=t.rawNotes.filter(n=>isDrum||n.channel===9).map(n=>({t:toSec(n.startTick),type:drumType(n.midi),gain:clamp(n.velocity,.08,1)}));const out={name:t.name||`Track ${t.index+1}`,program:t.program,programFamily:gmFamily(t.program),channel:t.channels.length===1?t.channels[0]:null,isDrum,notes,drums,count:isDrum?drums.length:notes.length};out.suggested=suggestedTrack(out);return out;}).filter(t=>t.count>0);
  return {format:`MIDI ${format}`,name,bpm,ppq,tracks,duration:Math.max(0,...tracks.flatMap(t=>t.isDrum?t.drums.map(d=>d.t+.15):t.notes.map(n=>n.start+n.duration)))};
}

const STEP={C:0,D:2,E:4,F:5,G:7,A:9,B:11};
function xmlNum(node,sel,fallback=0){const v=node.querySelector(sel)?.textContent;return Number.isFinite(+v)?+v:fallback;}
function pitchToMidi(note){const step=note.querySelector('pitch > step')?.textContent?.trim(),oct=xmlNum(note,'pitch > octave',4),alter=xmlNum(note,'pitch > alter',0);if(STEP[step]==null)return null;return clamp(12*(oct+1)+STEP[step]+alter,0,127);}
export function parseMusicXml(text,name='MusicXML'){
  const doc=new DOMParser().parseFromString(text,'application/xml');if(doc.querySelector('parsererror'))throw new Error('Invalid MusicXML file');const root=doc.querySelector('score-partwise');if(!root)throw new Error('Only score-partwise MusicXML is supported');
  const partNames=new Map();for(const sp of root.querySelectorAll('part-list > score-part'))partNames.set(sp.getAttribute('id'),sp.querySelector('part-name')?.textContent?.trim()||sp.getAttribute('id'));
  let bpm=120;const soundTempo=root.querySelector('sound[tempo]')?.getAttribute('tempo'),perMin=root.querySelector('direction metronome per-minute')?.textContent;if(Number.isFinite(+soundTempo))bpm=+soundTempo;else if(Number.isFinite(+perMin))bpm=+perMin;
  const secPerQuarter=60/bpm,tracks=[];for(const part of root.querySelectorAll(':scope > part')){let qpos=0,divisions=1,lastStart=0;const notes=[];for(const measure of part.querySelectorAll(':scope > measure')){const divNode=measure.querySelector(':scope > attributes > divisions');if(divNode&&+divNode.textContent>0)divisions=+divNode.textContent;for(const el of measure.children){if(el.tagName==='backup'){qpos-=xmlNum(el,'duration',0)/divisions;continue;}if(el.tagName==='forward'){qpos+=xmlNum(el,'duration',0)/divisions;continue;}if(el.tagName!=='note')continue;const durQ=xmlNum(el,'duration',0)/divisions,isChord=!!el.querySelector(':scope > chord'),isRest=!!el.querySelector(':scope > rest'),startQ=isChord?lastStart:qpos;if(!isRest){const midi=pitchToMidi(el);if(midi!=null)notes.push({start:startQ*secPerQuarter,duration:Math.max(.02,durQ*secPerQuarter),midi,velocity:.75});}if(!isChord){lastStart=qpos;qpos+=durQ;}}}
    const out={name:partNames.get(part.getAttribute('id'))||`Part ${tracks.length+1}`,program:0,programFamily:'MusicXML',channel:null,isDrum:false,notes,drums:[],count:notes.length};out.suggested=suggestedTrack(out);if(out.count)tracks.push(out);
  }
  return {format:'MusicXML',name,bpm,ppq:null,tracks,duration:Math.max(0,...tracks.flatMap(t=>t.notes.map(n=>n.start+n.duration)))};
}

export async function parseCompositionFile(file){const lower=file.name.toLowerCase();if(lower.endsWith('.mid')||lower.endsWith('.midi'))return parseMidi(await file.arrayBuffer(),file.name);if(lower.endsWith('.musicxml')||lower.endsWith('.xml'))return parseMusicXml(await file.text(),file.name);throw new Error('Supported composition files: .mid, .midi, .musicxml, .xml');}
