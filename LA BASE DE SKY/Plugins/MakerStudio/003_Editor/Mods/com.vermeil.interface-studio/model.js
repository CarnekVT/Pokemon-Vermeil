export const DATA_PATH = "Data/InterfaceStudio/layouts.json";
export const DATA_DIR = "Data/InterfaceStudio";
export const VERSION = 1;
export const TYPES = ["image", "text", "panel"];
export const COLORS = { image:"#586b85", text:"#e8eaf6", panel:"#35435c" };
const copy = value => JSON.parse(JSON.stringify(value));
export function uid(prefix="id") {
  return prefix + "_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2,8);
}
export const slug = value => String(value||"pantalla").trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9_-]+/g,"_").replace(/^_+|_+$/g,"").slice(0,55)||"pantalla";
export function newLayer(type="panel",index=0) {
  const base={id:uid("layer"),name:{image:"Imagen",text:"Texto",panel:"Panel"}[type]||"Elemento",type,x:40+index*12,y:40+index*12,w:type==="text"?240:128,h:type==="text"?48:96,opacity:255,visible:true,locked:false};
  if(type==="image")base.path="";
  if(type==="text"){base.text="Texto de ejemplo";base.fontSize=24;base.color="#f5f5f5";base.align="left";}
  if(type==="panel")base.color="#33445b";
  return base;
}
export function newScreen(name="Nueva pantalla",w=640,h=480) {
  return {id:uid("screen"),name:String(name),key:slug(name),width:Math.round(w),height:Math.round(h),layers:[]};
}
export function newProject() {
  const first=newScreen("Pantalla principal");
  first.layers=[{...newLayer("panel",0),name:"Área de ejemplo",x:60,y:68,w:520,h:330,color:"#25354d"},
    {...newLayer("text",1),name:"Título",text:"INTERFACE STUDIO",x:92,y:92,w:450,h:52,fontSize:30}];
  return {version:VERSION,screens:[first]};
}
function number(value,defaultValue,min,max) {
  const n=Number(value); return Number.isFinite(n)?Math.max(min,Math.min(max,Math.round(n))):defaultValue;
}
export function normalize(raw) {
  if(!raw || typeof raw!=="object" || !Array.isArray(raw.screens))throw new Error("Archivo de interfaces no válido: falta screens.");
  const seenScreens=new Set();
  const screens=raw.screens.slice(0,300).map((s,i)=>{
    if(!s || typeof s!=="object")throw new Error("Pantalla inválida en la posición "+(i+1));
    const id=String(s.id||uid("screen"));
    if(seenScreens.has(id))throw new Error("ID de pantalla duplicado: "+id);
    seenScreens.add(id);
    const seenLayers=new Set();
    const layers=(Array.isArray(s.layers)?s.layers:[]).slice(0,1000).map((l,j)=>{
      if(!l || !TYPES.includes(l.type))throw new Error("Elemento incompatible en "+(s.name||id)+", posición "+(j+1));
      const lid=String(l.id||uid("layer"));if(seenLayers.has(lid))throw new Error("ID de capa duplicado: "+lid);
      seenLayers.add(lid);
      const v={...copy(l),id:lid,name:String(l.name||l.type).slice(0,120),type:l.type,
        x:number(l.x,0,-10000,10000),y:number(l.y,0,-10000,10000),
        w:number(l.w,120,1,8192),h:number(l.h,64,1,8192),
        opacity:number(l.opacity,255,0,255),visible:l.visible!==false,locked:l.locked===true};
      if(v.type==="image")v.path=String(l.path||"").replace(/\\/g,"/");
      if(v.type==="text"){v.text=String(l.text||"");v.fontSize=number(l.fontSize,24,6,200);v.color=validColor(l.color,"#f5f5f5");v.align=["left","center","right"].includes(l.align)?l.align:"left";}
      if(v.type==="panel")v.color=validColor(l.color,"#33445b");
      return v;
    });
    return {id,name:String(s.name||"Pantalla "+(i+1)).slice(0,120),key:slug(s.key||s.name||"screen_"+i),width:number(s.width,640,160,4096),height:number(s.height,480,120,4096),layers};
  });
  if(!screens.length)throw new Error("El proyecto necesita al menos una pantalla.");
  return {version:VERSION,screens};
}
export function validColor(value,def="#ffffff") {return /^#[0-9a-f]{6}$/i.test(String(value||""))?String(value):def;}
export function clone(value){return copy(value);}
export function rubyString(value) {return "'" + String(value??"").replace(/\\/g,"\\\\").replace(/'/g,"\\'").replace(/\r/g,"").replace(/\n/g,"\\n") + "'";}
export function makeRuby(screen) {
  const key=slug(screen.key),out=[
    "# Código de disposición generado por Interface Studio.",
    "# Inserta este método en tu plugin Ruby; invócalo desde la escena correspondiente.",
    "# El método crea sprites; tu escena sigue siendo responsable de disponerlos.",
    "def pbVermeilUI_" + key + "(sprites, viewport = nil)"
  ];
  screen.layers.forEach((l,i)=>{
    if(!l.visible)return;
    const s="ui_sprite_"+i, b="ui_bitmap_"+i, w=Math.max(1,l.w|0),h=Math.max(1,l.h|0);
    out.push("  # "+String(l.name).replace(/[\r\n]/g," "));
    if(l.type==="image") {
      if(!/^Graphics\/[A-Za-z0-9 _./()-]+\.(png|jpg|jpeg|bmp)$/i.test(l.path||"") || (l.path||"").split("/").includes("..")) {
        out.push("  # Imagen omitida: selecciona un archivo válido de Graphics/.");
        return;
      }
      out.push("  "+s+" = Sprite.new(viewport)","  "+s+".bitmap = Bitmap.new("+rubyString(l.path)+")");
      out.push("  "+s+".zoom_x = "+w+".to_f / [1, "+s+".bitmap.width].max");
      out.push("  "+s+".zoom_y = "+h+".to_f / [1, "+s+".bitmap.height].max");
    } else {
      out.push("  "+b+" = Bitmap.new("+w+", "+h+")");
      if(l.type==="panel"){
        const rgb=parseHex(l.color);
        out.push("  "+b+".fill_rect(0, 0, "+w+", "+h+", Color.new("+rgb.join(", ")+"))");
      } else {
        const rgb=parseHex(l.color);
        out.push("  "+b+".font.size = "+Math.max(6,l.fontSize|0));
        out.push("  "+b+".font.color = Color.new("+rgb.join(", ")+")");
        out.push("  "+b+".draw_text(Rect.new(0, 0, "+w+", "+h+"), "+rubyString(l.text)+", "+({left:0,center:1,right:2}[l.align]??0)+")");
      }
      out.push("  "+s+" = Sprite.new(viewport)","  "+s+".bitmap = "+b);
    }
    out.push("  "+s+".x = "+(l.x|0),"  "+s+".y = "+(l.y|0),"  "+s+".z = "+(100+i),"  "+s+".opacity = "+(l.opacity|0));
    out.push("  sprites["+rubyString(l.id)+"] = "+s);
  });
  out.push("end","");
  return out.join("\n");
}
function parseHex(v){const s=validColor(v).slice(1);return [0,2,4].map(i=>parseInt(s.slice(i,i+2),16));}
