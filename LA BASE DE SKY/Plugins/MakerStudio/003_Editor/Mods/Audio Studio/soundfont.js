// Minimal SoundFont 2 (.sf2) reader for Audio Studio.
// Supports standard PCM16 smpl data, preset/instrument zones, key/velocity ranges,
// tuning, looping, attenuation and basic volume envelopes.

const GEN = {
  startAddrsOffset:0,endAddrsOffset:1,startloopAddrsOffset:2,endloopAddrsOffset:3,
  startAddrsCoarseOffset:4,endAddrsCoarseOffset:12,pan:17,
  delayVolEnv:33,attackVolEnv:34,holdVolEnv:35,decayVolEnv:36,sustainVolEnv:37,releaseVolEnv:38,
  instrument:41,keyRange:43,velRange:44,startloopAddrsCoarseOffset:45,
  initialAttenuation:48,endloopAddrsCoarseOffset:50,coarseTune:51,fineTune:52,
  sampleID:53,sampleModes:54,scaleTuning:56,exclusiveClass:57,overridingRootKey:58
};
const ADDITIVE = new Set([0,1,2,3,4,12,17,33,34,35,36,37,38,45,48,50,51,52]);
const dec = new TextDecoder('ascii');
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));

function str(view,off,len){
  const u=new Uint8Array(view.buffer,view.byteOffset+off,len); let s=dec.decode(u); const z=s.indexOf('\0'); if(z>=0)s=s.slice(0,z); return s.trim();
}
function four(view,off){return str(view,off,4);}
function s16(view,o){return view.getInt16(o,true);} function u16(view,o){return view.getUint16(o,true);} function u32(view,o){return view.getUint32(o,true);}
function timecents(v, fallback){ if(v==null)return fallback; if(v<=-32768)return 0; return clamp(Math.pow(2,v/1200),0,30); }
function rangeFrom(raw){return {lo:raw&255,hi:(raw>>8)&255};}
function intersectRange(a,b){return {lo:Math.max(a?.lo??0,b?.lo??0),hi:Math.min(a?.hi??127,b?.hi??127)};}

function parseRecords(view, chunk, size, reader){
  if(!chunk)return[]; const out=[]; for(let o=chunk.off;o+size<=chunk.off+chunk.size;o+=size)out.push(reader(o)); return out;
}
function parseGens(view,chunk){
  return parseRecords(view,chunk,4,o=>{const op=u16(view,o),raw=u16(view,o+2);return {op,raw,signed:s16(view,o+2),range:(op===43||op===44)?rangeFrom(raw):null};});
}
function gensMap(arr,start,end){
  const m=new Map(); for(let i=start;i<end;i++){const g=arr[i]; if(!g)continue; m.set(g.op,g);} return m;
}
function mergeGens(a,b){
  const out=new Map(); for(const [k,v] of a||[])out.set(k,{...v});
  for(const [k,v] of b||[]){
    if(ADDITIVE.has(k)&&out.has(k)){
      const old=out.get(k); out.set(k,{...v,signed:(old.signed||0)+(v.signed||0),raw:(old.raw||0)+(v.raw||0)});
    } else out.set(k,{...v});
  }
  return out;
}
function gv(m,op,def=0){const g=m.get(op);return g?g.signed:def;}
function gu(m,op,def=0){const g=m.get(op);return g?g.raw:def;}

export class SoundFontBank {
  constructor(arrayBuffer,name='SoundFont'){
    this.name=name; this.buffer=arrayBuffer; this.view=new DataView(arrayBuffer); this.chunks={}; this.sampleCache=new Map(); this._parse();
  }
  _parse(){
    const v=this.view; if(four(v,0)!=='RIFF'||four(v,8)!=='sfbk')throw new Error('Not a SoundFont 2 RIFF file');
    const end=Math.min(v.byteLength,8+u32(v,4));
    const walk=(start,stop,parent='')=>{
      let o=start; while(o+8<=stop){const id=four(v,o),size=u32(v,o+4),data=o+8,next=data+size+(size&1); if(next>v.byteLength+1)break;
        if(id==='LIST'&&size>=4){const type=four(v,data);walk(data+4,data+size,type);}
        else this.chunks[`${parent}:${id}`]={off:data,size}; o=next;
      }
    };
    walk(12,end,'RIFF');
    const c=(id)=>this.chunks[`pdta:${id}`];
    const smpl=this.chunks['sdta:smpl']; if(!smpl)throw new Error('SF2 has no PCM smpl chunk');
    this.smpl={off:smpl.off,size:smpl.size,samples:Math.floor(smpl.size/2)};
    this.phdr=parseRecords(v,c('phdr'),38,o=>({name:str(v,o,20),preset:u16(v,o+20),bank:u16(v,o+22),bag:u16(v,o+24)}));
    this.pbag=parseRecords(v,c('pbag'),4,o=>({gen:u16(v,o),mod:u16(v,o+2)}));
    this.pgen=parseGens(v,c('pgen'));
    this.inst=parseRecords(v,c('inst'),22,o=>({name:str(v,o,20),bag:u16(v,o+20)}));
    this.ibag=parseRecords(v,c('ibag'),4,o=>({gen:u16(v,o),mod:u16(v,o+2)}));
    this.igen=parseGens(v,c('igen'));
    this.shdr=parseRecords(v,c('shdr'),46,o=>({name:str(v,o,20),start:u32(v,o+20),end:u32(v,o+24),loopStart:u32(v,o+28),loopEnd:u32(v,o+32),sampleRate:u32(v,o+36),originalPitch:v.getUint8(o+40),pitchCorrection:v.getInt8(o+41),link:u16(v,o+42),type:u16(v,o+44)}));
    // Terminal records EOP/EOI/EOS are not playable.
    this.presets=this.phdr.slice(0,-1).map((p,i)=>({index:i,name:p.name||`Preset ${i}`,bank:p.bank,program:p.preset,regions:this._resolvePreset(i)}));
  }
  _zoneGens(bags,gens,idx,nextIdx){
    const b=bags[idx]; if(!b)return new Map(); const endGen=(bags[idx+1]?.gen ?? gens.length); return gensMap(gens,b.gen,endGen);
  }
  _resolvePreset(pi){
    const p=this.phdr[pi], pNext=this.phdr[pi+1]; if(!p||!pNext)return[]; let pGlobal=new Map(), out=[];
    for(let bi=p.bag;bi<pNext.bag;bi++){
      const pg=this._zoneGens(this.pbag,this.pgen,bi,pNext.bag); const instG=pg.get(GEN.instrument);
      if(!instG){pGlobal=mergeGens(pGlobal,pg);continue;}
      const instId=instG.raw, inst=this.inst[instId], instNext=this.inst[instId+1]; if(!inst||!instNext)continue;
      let iGlobal=new Map();
      for(let ib=inst.bag;ib<instNext.bag;ib++){
        const ig=this._zoneGens(this.ibag,this.igen,ib,instNext.bag); const sampleG=ig.get(GEN.sampleID);
        if(!sampleG){iGlobal=mergeGens(iGlobal,ig);continue;}
        let g=mergeGens(pGlobal,pg); g.delete(GEN.instrument); g=mergeGens(g,iGlobal); g=mergeGens(g,ig);
        const sampleID=gu(g,GEN.sampleID,-1); if(sampleID<0||sampleID>=this.shdr.length-1)continue;
        const kr=intersectRange(pGlobal.get(GEN.keyRange)?.range,pg.get(GEN.keyRange)?.range); const kr2=intersectRange(kr,iGlobal.get(GEN.keyRange)?.range); const keyRange=intersectRange(kr2,ig.get(GEN.keyRange)?.range);
        const vr=intersectRange(pGlobal.get(GEN.velRange)?.range,pg.get(GEN.velRange)?.range); const vr2=intersectRange(vr,iGlobal.get(GEN.velRange)?.range); const velRange=intersectRange(vr2,ig.get(GEN.velRange)?.range);
        if(keyRange.lo>keyRange.hi||velRange.lo>velRange.hi)continue;
        const s=this.shdr[sampleID], coarse=gv(g,GEN.coarseTune,0), fine=gv(g,GEN.fineTune,0), root=gu(g,GEN.overridingRootKey,255)===255?s.originalPitch:gu(g,GEN.overridingRootKey,255);
        const startOff=gv(g,GEN.startAddrsOffset,0)+gv(g,GEN.startAddrsCoarseOffset,0)*32768;
        const endOff=gv(g,GEN.endAddrsOffset,0)+gv(g,GEN.endAddrsCoarseOffset,0)*32768;
        const loopStartOff=gv(g,GEN.startloopAddrsOffset,0)+gv(g,GEN.startloopAddrsCoarseOffset,0)*32768;
        const loopEndOff=gv(g,GEN.endloopAddrsOffset,0)+gv(g,GEN.endloopAddrsCoarseOffset,0)*32768;
        out.push({sampleID,keyRange,velRange,coarse,fine,root,pitchCorrection:s.pitchCorrection||0,scaleTuning:gu(g,GEN.scaleTuning,100)||100,
          sampleModes:gu(g,GEN.sampleModes,0),attenuation:Math.max(0,gv(g,GEN.initialAttenuation,0)),pan:clamp(gv(g,GEN.pan,0)/500,-1,1),
          startOffset:startOff,endOffset:endOff,loopStartOffset:loopStartOff,loopEndOffset:loopEndOff,
          env:{delay:timecents(gv(g,GEN.delayVolEnv,null),0),attack:timecents(gv(g,GEN.attackVolEnv,null),.008),hold:timecents(gv(g,GEN.holdVolEnv,null),0),decay:timecents(gv(g,GEN.decayVolEnv,null),.08),sustainCb:Math.max(0,gv(g,GEN.sustainVolEnv,0)),release:timecents(gv(g,GEN.releaseVolEnv,null),.08)}});
      }
    }
    return out;
  }
  presetList(){return this.presets.map(p=>({index:p.index,name:p.name,bank:p.bank,program:p.program,regions:p.regions.length}));}
  regionFor(presetIndex,midi,velocity=100){
    const p=this.presets[presetIndex]||this.presets[0]; if(!p)return null; const v=clamp(Math.round(velocity),0,127);
    return p.regions.find(r=>midi>=r.keyRange.lo&&midi<=r.keyRange.hi&&v>=r.velRange.lo&&v<=r.velRange.hi)||p.regions.find(r=>midi>=r.keyRange.lo&&midi<=r.keyRange.hi)||p.regions[0]||null;
  }
  sampleInfo(region){
    const s=this.shdr[region.sampleID]; if(!s)return null;
    const start=clamp(s.start+region.startOffset,0,this.smpl.samples-1), end=clamp(s.end+region.endOffset,start+1,this.smpl.samples);
    const loopStart=clamp(s.loopStart+region.loopStartOffset,start,end-1),loopEnd=clamp(s.loopEnd+region.loopEndOffset,loopStart+1,end);
    return {...s,start,end,loopStart,loopEnd};
  }
  sampleData(sampleID){
    if(this.sampleCache.has(sampleID))return this.sampleCache.get(sampleID); const s=this.shdr[sampleID]; if(!s)return null;
    const start=clamp(s.start,0,this.smpl.samples),end=clamp(s.end,start,this.smpl.samples), n=Math.max(1,end-start), out=new Float32Array(n); let o=this.smpl.off+start*2;
    for(let i=0;i<n;i++,o+=2)out[i]=this.view.getInt16(o,true)/32768;
    this.sampleCache.set(sampleID,out); return out;
  }
  playbackRate(region,midi){
    const semis=(midi-region.root)*(region.scaleTuning/100)+region.coarse+region.fine/100-(region.pitchCorrection||0)/100; return Math.pow(2,semis/12);
  }
  describe(){return `${this.name}: ${this.presets.length} presets, ${Math.max(0,this.shdr.length-1)} samples`;}
}
