// Minimal Ruby Marshal 4.8 reader for RPG Maker XP / Essentials event data.
// Used by Translate Studio so the editor can discover the current project's
// MapInfos/MapXXX/CommonEvents directly without launching the game.
const td = new TextDecoder('utf-8', { fatal:false });

class MarshalReader {
  constructor(bytes){this.b=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);this.p=0;this.symbols=[];this.objects=[];}
  byte(){if(this.p>=this.b.length)throw new Error('Unexpected end of Ruby Marshal data');return this.b[this.p++];}
  signedByte(){const n=this.byte();return n>=128?n-256:n;}
  bytes(n){const end=this.p+n;if(end>this.b.length)throw new Error('Unexpected end of Ruby Marshal data');const out=this.b.slice(this.p,end);this.p=end;return out;}
  fixnum(){const c=this.signedByte();if(c===0)return 0;if(c>4)return c-5;if(c<-4)return c+5;const n=Math.abs(c);let v=0n;for(let i=0;i<n;i++)v|=BigInt(this.byte())<<BigInt(8*i);if(c<0)v-=1n<<BigInt(8*n);return Number(v);}
  rawString(){const n=this.fixnum();if(n<0)throw new Error('Invalid Ruby Marshal string length');return td.decode(this.bytes(n));}
  register(v){this.objects.push(v);return v;}
  attachIvars(v,ivars){if(v&&typeof v==='object')Object.assign(v.__ivars||={},ivars);return v;}
  value(){
    const tag=String.fromCharCode(this.byte());
    switch(tag){
      case '0':return null;case 'T':return true;case 'F':return false;case 'i':return this.fixnum();
      case 'f':{const s=this.rawString(),n=Number(s);return this.register(Number.isNaN(n)?0:n);}
      case ':':{const s=this.rawString();this.symbols.push(s);return s;}case ';':return this.symbols[this.fixnum()];
      case '@':return this.objects[this.fixnum()];case '"':return this.register(this.rawString());
      case '[':{const a=this.register([]),n=this.fixnum();for(let i=0;i<n;i++)a.push(this.value());return a;}
      case '{':{const m=this.register(new Map()),n=this.fixnum();for(let i=0;i<n;i++)m.set(this.value(),this.value());return m;}
      case '}':{const m=this.register(new Map()),n=this.fixnum();for(let i=0;i<n;i++)m.set(this.value(),this.value());m.__default=this.value();return m;}
      case 'o':{const klass=this.value(),o=this.register({__rubyClass:String(klass||'Object'),__ivars:{}}),n=this.fixnum();for(let i=0;i<n;i++)o.__ivars[String(this.value())]=this.value();return o;}
      case 'I':{const v=this.value(),n=this.fixnum(),ivars={};for(let i=0;i<n;i++)ivars[String(this.value())]=this.value();return this.attachIvars(v,ivars);}
      case 'u':{const klass=String(this.value()||''),n=this.fixnum();return this.register({__rubyClass:klass,__raw:this.bytes(n)});}
      case 'U':{const klass=String(this.value()||''),data=this.value();return this.register({__rubyClass:klass,__marshalData:data});}
      case 'l':{ // Bignum (rare in event data, supported for completeness)
        const sign=String.fromCharCode(this.byte()),words=this.fixnum();let v=0n;for(let i=0;i<words*2;i++)v|=BigInt(this.byte())<<BigInt(8*i);if(sign==='-')v=-v;return Number(v);
      }
      default:throw new Error(`Unsupported Ruby Marshal tag ${JSON.stringify(tag)} at 0x${(this.p-1).toString(16)}`);
    }
  }
  read(){const major=this.byte(),minor=this.byte();if(major!==4||minor!==8)throw new Error(`Unsupported Ruby Marshal version ${major}.${minor}`);return this.value();}
}

function iv(o,name,fallback=null){const key=String(name).replace(/^@/,'');const v=o?.__ivars?.[`@${key}`]??o?.__ivars?.[key];return v===undefined?fallback:v;}
function clean(v){return String(v??'').replace(/\0/g,'').trim();}
function rubyLiteral(s,q){s=String(s??'');return q==='"'?s.replace(/\\n/g,'\n').replace(/\\r/g,'\r').replace(/\\t/g,'\t').replace(/\\"/g,'"').replace(/\\\\/g,'\\'):s.replace(/\\'/g,"'").replace(/\\\\/g,'\\');}
function codeTexts(code,context){
  const out=[],text=String(code??'');
  const patterns=[
    /(?:_INTL|_ISPRINTF|pbEnter(?:Text|PlayerName|PokemonName|NPCName|BoxName))\s*\(\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g,
    /(?:text_inline|show_centered_text)\s*(?:\(\s*)?(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g,
    /speaker\s*:\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g
  ];
  for(const re of patterns){let m;while((m=re.exec(text))){const source=rubyLiteral(m[2],m[1]);if(source)out.push({source,context:`${context} · Script`});}}
  return out;
}
function extractList(list,context){
  const out=[];if(!Array.isArray(list))return out;
  for(let i=0;i<list.length;i++){
    const cmd=list[i],code=Number(iv(cmd,'code',0))||0,params=iv(cmd,'parameters',[])||[];
    if(code===101){let text=String(params[0]??'');let j=i+1;while(j<list.length&&Number(iv(list[j],'code',0))===401){text+=(text?'\n':'')+String((iv(list[j],'parameters',[])||[])[0]??'');j++;}if(text)out.push({source:text,context:`${context} · Mensaje`});}
    else if(code===102){for(const choice of (Array.isArray(params[0])?params[0]:[]))if(String(choice??''))out.push({source:String(choice),context:`${context} · Opción`});}
    else if(code===355){let script=String(params[0]??'');let j=i+1;while(j<list.length&&Number(iv(list[j],'code',0))===655){script+='\n'+String((iv(list[j],'parameters',[])||[])[0]??'');j++;}out.push(...codeTexts(script,context));}
    else if(code===111&&Number(params[0])===12)out.push(...codeTexts(String(params[1]??''),`${context} · Condición`));
    else if(code===209){const route=params[1],routeList=iv(route,'list',[]);for(const rcmd of (Array.isArray(routeList)?routeList:[])){if(Number(iv(rcmd,'code',0))===45)out.push(...codeTexts(String((iv(rcmd,'parameters',[])||[])[0]??''),`${context} · Ruta de movimiento`));}}
  }
  return out;
}
export function parseRubyMarshal(bytes){return new MarshalReader(bytes).read();}
export function parseMapInfos(bytes){
  const raw=parseRubyMarshal(bytes),out=new Map();if(!(raw instanceof Map))return out;
  for(const [id,info] of raw.entries()){const n=Number(id);if(Number.isFinite(n)&&info)out.set(n,clean(iv(info,'name','')));}
  return out;
}
export function parseMapEventTexts(bytes,mapId,mapName=''){
  const map=parseRubyMarshal(bytes),events=iv(map,'events',new Map()),out=[];if(!(events instanceof Map))return out;
  for(const [,event] of events.entries()){
    if(!event)continue;const eid=Number(iv(event,'id',0))||0,name=clean(iv(event,'name','')),pages=iv(event,'pages',[]);if(!Array.isArray(pages))continue;
    pages.forEach((page,pi)=>{const label=name?`Evento ${eid} "${name}"`:`Evento ${eid}`;const ctx=`Map${String(mapId).padStart(3,'0')} · ${mapName||'Sin nombre'} · ${label} · Pág. ${pi+1}`;out.push(...extractList(iv(page,'list',[]),ctx));});
  }
  return out;
}
export function parseCommonEventTexts(bytes){
  const arr=parseRubyMarshal(bytes),out=[];if(!Array.isArray(arr))return out;
  for(const event of arr){if(!event)continue;const id=Number(iv(event,'id',0))||0,name=clean(iv(event,'name','')),ctx=name?`Evento común ${id} "${name}"`:`Evento común ${id}`;out.push(...extractList(iv(event,'list',[]),ctx));}
  return out;
}
