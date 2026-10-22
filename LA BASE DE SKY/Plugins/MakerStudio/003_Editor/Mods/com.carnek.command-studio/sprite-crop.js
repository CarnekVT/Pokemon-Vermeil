// Frame selection and alpha-tight crop for RMXP/Essentials event character graphics.
export function spriteGrid(width,height,file=""){
 const name=String(file||"");
 if(!Number.isFinite(width)||!Number.isFinite(height)||width<1||height<1)throw Error("Sprite sin dimensiones");
 // Essentials/RMXP uses 4 frames (left to right) and 4 directions (down,left,right,up).
 // Imported single PNGs and $ prefixed standalone graphics should not be quartered.
 if(/^\$/.test(name)||width<48||height<48)return{cols:1,rows:1,frame:0,direction:0};
 if(width>=64&&height>=64&&width%4===0&&height%4===0){
   return{cols:4,rows:4,frame:1,direction:0};
 }
 if(width%3===0&&height%4===0&&width>=96&&height>=96){
   return{cols:3,rows:4,frame:1,direction:0};
 }
 // Thin one-row strips/oversized standalones are treated as one sprite.
 return{cols:1,rows:1,frame:0,direction:0};
}
export function spriteCrop(imageData,frameWidth,frameHeight){
 const {data,width,height}=imageData;
 if(!data||!width||!height)return{x:0,y:0,width:frameWidth,height:frameHeight,empty:true};
 let left=width,right=-1,top=height,bottom=-1;
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  if(data[(y*width+x)*4+3]<16)continue;
  left=Math.min(left,x);right=Math.max(right,x);
  top=Math.min(top,y);bottom=Math.max(bottom,y);
 }
 if(right<left)return{x:0,y:0,width:width,height:height,empty:true};
 return{x:left,y:top,width:right-left+1,height:bottom-top+1,empty:false};
}
export function drawEventSprite(canvas,img,filename="",size=48){
 const width=Math.max(20,Math.round(size)),height=width;
 canvas.width=width;canvas.height=height;
 const ctx=canvas.getContext("2d",{willReadFrequently:true});
 if(!ctx)return false;
 ctx.clearRect(0,0,width,height);ctx.imageSmoothingEnabled=false;
 const grid=spriteGrid(img.width,img.height,filename);
 const fw=Math.floor(img.width/grid.cols),fh=Math.floor(img.height/grid.rows);
 const fx=grid.frame*fw,fy=grid.direction*fh;
 if(!fw||!fh)return false;
 // A temporary frame canvas avoids accidentally sampling neighbouring animation frames.
 const tmp=document.createElement("canvas");tmp.width=fw;tmp.height=fh;
 const t=tmp.getContext("2d",{willReadFrequently:true});
 if(!t)return false;
 t.clearRect(0,0,fw,fh);t.drawImage(img,fx,fy,fw,fh,0,0,fw,fh);
 let crop={x:0,y:0,width:fw,height:fh};
 try{crop=spriteCrop(t.getImageData(0,0,fw,fh),fw,fh);}catch(_){}
 if(crop.empty)return false;
 const margin=3;
 const scale=Math.min((width-margin*2)/crop.width,(height-margin*2)/crop.height);
 const w=Math.max(1,Math.round(crop.width*scale)),h=Math.max(1,Math.round(crop.height*scale));
 // Align to bottom for standing figures. Tiny props remain centered.
 const dx=Math.round((width-w)/2),dy=height-margin-h;
 ctx.drawImage(tmp,crop.x,crop.y,crop.width,crop.height,dx,dy,w,h);
 return true;
}
