import { SCALES, snapMidiToScale } from './pitch.js';

export const MOODS = {
  town: { label:'Town / Pueblo', scale:'major', bpm:104, energy:.35, darkness:.2 },
  route: { label:'Route / Ruta', scale:'major', bpm:122, energy:.55, darkness:.18 },
  battle: { label:'Battle / Batalla', scale:'minor', bpm:152, energy:.9, darkness:.52 },
  boss: { label:'Boss / Jefe', scale:'minor', bpm:168, energy:1, darkness:.78 },
  mystery: { label:'Mystery / Misterio', scale:'dorian', bpm:92, energy:.38, darkness:.68 },
  emotional: { label:'Emotional / Emotivo', scale:'minor', bpm:78, energy:.25, darkness:.46 },
  happy: { label:'Happy / Alegre', scale:'major', bpm:132, energy:.7, darkness:.05 },
  horror: { label:'Horror / Terror', scale:'minorPentatonic', bpm:72, energy:.42, darkness:1 }
};

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const triad = (root, scaleName, degree, octave=4) => {
  const scale=SCALES[scaleName]||SCALES.minor;
  const base=12*(octave+1)+root;
  const idx=(degree%scale.length+scale.length)%scale.length;
  const at=(d)=>{ const i=idx+d; const oct=Math.floor(i/scale.length); return base+scale[i%scale.length]+12*oct; };
  return [at(0),at(2),at(4)];
};
const progressionFor=(mood)=>mood==='happy'||mood==='town'||mood==='route'?[0,4,5,3]:mood==='horror'?[0,1,0,6]:[0,5,2,6];
const songEnd=(notes,bpm)=>notes.length?Math.max(...notes.map(n=>n.start+n.duration)):(60/bpm)*16;

export function generateHarmony(notes,opts={}) {
  if(!notes.length) return [];
  const root=opts.root||0,scale=opts.scale||'minor',bpm=opts.bpm||120,mood=opts.mood||'battle',beat=60/bpm,bar=beat*4,end=songEnd(notes,bpm),progression=progressionFor(mood);
  const style=opts.generatorStyle||opts.harmonyStyle||'chords',rate=clamp(+opts.rate||1,.5,4),velocity=clamp(opts.velocity??.3,.05,1),density=clamp(opts.density??.75,.1,1),octave=clamp(Math.round(opts.octave??3),2,6),out=[];
  if(style==='arp'){
    const step=beat/rate;
    for(let t=0,i=0;t<end+step;t+=step,i++){
      const chord=triad(root,scale,progression[Math.floor(t/bar)%progression.length],octave),note=chord[i%chord.length];
      if((i%8)/8<=density+.08)out.push({start:t,duration:step*.82,midi:note,velocity});
    }
    return out;
  }
  const step=style==='pad'?bar:bar/rate;
  for(let t=0,i=0;t<end+step;t+=step,i++){
    const chord=triad(root,scale,progression[Math.floor(t/bar)%progression.length],octave);let tones=style==='fifths'?[chord[0],chord[2]]:chord;
    if(density<.5&&tones.length===3)tones=[tones[0],tones[2]];
    const dur=style==='pad'?bar*.96:step*.92;
    for(const midi of tones)out.push({start:t,duration:dur,midi,velocity});
  }
  return out;
}

export function generateBass(notes,opts={}) {
  if(!notes.length)return[];
  const root=opts.root||0,scale=opts.scale||'minor',bpm=opts.bpm||120,mood=opts.mood||'battle',beat=60/bpm,end=songEnd(notes,bpm),progression=progressionFor(mood),sc=SCALES[scale]||SCALES.minor,out=[];
  const style=opts.generatorStyle||opts.bassStyle||'pulse',rate=clamp(+opts.rate||1,.5,4),velocity=clamp(opts.velocity??(.5+(mood==='boss'?.16:0)),.08,1),density=clamp(opts.density??.8,.1,1),octave=clamp(Math.round(opts.octave??2),1,4),step=beat/rate,base=12*(octave+1);
  for(let t=0,i=0;t<end;t+=step,i++){
    const degree=progression[Math.floor(t/(beat*4))%progression.length]%sc.length,rootMidi=base+root+sc[degree];let midi=rootMidi;
    if(style==='root5'&&i%2)midi=snapMidiToScale(rootMidi+7,root,scale);
    else if(style==='octave'&&i%2)midi=rootMidi+12;
    else if(style==='walking'){const moves=[0,2,4,5],d=moves[i%moves.length];midi=snapMidiToScale(rootMidi+d,root,scale);}
    const active=((i*37)%100)/100<density;if(active)out.push({start:t,duration:step*(style==='pulse'?.68:.84),midi,velocity:clamp(velocity*(i%4===0?1.08:1),.05,1)});
  }
  return out;
}

export function generateDrums(notes,opts={}) {
  const bpm=opts.bpm||120,beat=60/bpm,end=songEnd(notes,bpm),energy=opts.energy??.65,style=opts.generatorStyle||opts.drumStyle||'basic',rate=clamp(+opts.rate||1,.5,4),velocity=clamp(opts.velocity??.72,.08,1),density=clamp(opts.density??(.55+energy*.35),.1,1),step=beat/(2*rate),hits=[];
  const add=(t,type,g)=>hits.push({t,type,gain:clamp(g*velocity,.06,1)});
  for(let t=0,i=0;t<end;t+=step,i++){
    const beatPos=(t/beat)%4,half=Math.round(beatPos*2)%8,quarter=Math.round(beatPos)%4,rand=((i*53+17)%101)/101;
    if(style==='halftime'){
      if(Math.abs(beatPos)<.03||Math.abs(beatPos-2)<.03)add(t,'kick',.9);if(Math.abs(beatPos-3)<.03)add(t,'snare',.85);if(rand<density*.75)add(t,'hat',.26);
    } else if(style==='driving'){
      if(half===0||half===4||half===5)add(t,'kick',half===5?.55:.88);if(half===2||half===6)add(t,'snare',.78);if(rand<density)add(t,'hat',half%2?.34:.24);
    } else if(style==='syncopated'){
      if([0,3,5].includes(half))add(t,'kick',half===0?.9:.62);if([2,6].includes(half))add(t,'snare',.8);if(rand<density*.9)add(t,'hat',half%2?.38:.2);
    } else if(style==='breakbeat'){
      if([0,3,7].includes(half))add(t,'kick',half===0?.92:.58);if([2,6].includes(half))add(t,'snare',.84);if(rand<density)add(t,'hat',half%2?.42:.22);
    } else {
      if(half===0||half===4)add(t,'kick',.86);if(half===2||half===6)add(t,'snare',.72);if(rand<density*.86)add(t,'hat',energy>.75&&half%2?.32:.22);
    }
  }
  return hits.sort((a,b)=>a.t-b.t);
}

function seeded(seed){let s=(seed|0)||1;return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296;};}
export function makeVariation(notes,opts={}) {
  const root=opts.root||0,scale=opts.scale||'minor',amount=clamp(opts.amount??.45,0,1),rhythm=clamp(opts.rhythmAmount??.25,0,1),pitchRange=clamp(Math.round(opts.pitchRange??2),0,7),preserveRhythm=opts.preserveRhythm!==false,rng=seeded(opts.seed??17);
  return notes.map((n,i)=>{
    if(rng()>amount)return {...n};let midi=n.midi,start=n.start,duration=n.duration;
    if(pitchRange>0){const dir=rng()>.5?1:-1,steps=1+Math.floor(rng()*pitchRange);midi=snapMidiToScale(n.midi+dir*steps,root,scale);}
    if(!preserveRhythm&&rhythm>0){const shift=(rng()-.5)*n.duration*.35*rhythm;start=Math.max(0,n.start+shift);duration=Math.max(.03,n.duration*(1+(rng()-.5)*.35*rhythm));}
    return {...n,midi,start,duration,velocity:clamp((n.velocity??.75)*(1+(rng()-.5)*.18*amount),.15,1)};
  });
}

export function humanize(notes,amount=.12) {
  return notes.map(n=>({...n,start:Math.max(0,n.start+(Math.random()-.5)*.035*amount*4),velocity:Math.max(.2,Math.min(1,n.velocity+(Math.random()-.5)*.1*amount*4))}));
}
