// Read-only reference for original1406e8880; no renderer or integration hook.
// Positions are native screen center-bottom anchors, not rectangle top-lefts.
const f=Math.fround,I=n=>n|0,MAX=0x7fffffff;
const half=n=>I(Math.trunc(I(n)/2)),abs=n=>I((n^(n>>31))-(n>>31));
const cvtt=n=>{n=f(n);return !Number.isFinite(n)||n< -2147483648||n>=2147483648?-2147483648:Math.trunc(n)|0;};
export function nativePopupLayout(input,mode=1,enabled=true){
 const rows=input.map(r=>({...r,x:f(r.x),y:f(r.y),z:f(r.z??-5),width:f(r.width),height:f(r.height)})),placed=[];
 if(mode===0||!enabled)return {rows,placed};
 const padding=mode===2?40:0;
 for(let i=0;i<rows.length;i++){
  const a=rows[i];if(a.active!==1)continue;
  let negX=MAX,posX=MAX,negY=MAX,posY=MAX,spentX=0,spentY=0;
  for(let j=0;j<i;j++){
   const b=rows[j];if(b.active!==1)continue;
   const dx=cvtt(f(a.x-b.x)),dy=I(cvtt(f(a.y-b.y))+half(I(cvtt(a.height)-cvtt(b.height))));
   let ox=I(half(I(cvtt(a.width)+cvtt(b.width)+padding))-abs(dx));
   let oy=I(half(I(cvtt(a.height)+cvtt(b.height)))-abs(dy));
   if(ox>0||oy>0){
    if(dx<0)negX=Math.min(negX,I(-ox));else posX=Math.min(posX,I(-ox));
    if(dy<0)negY=Math.min(negY,I(-oy));else posY=Math.min(posY,I(-oy));
    if(ox>0&&oy>0){
     let moved=false;
     for(let attempt=0;attempt<2&&!moved;attempt++){
      const wantX=I(ox+spentX),wantY=I(oy+spentY);
      if(wantX<wantY){
       if(dx<0?ox<=posX:ox<=negX){a.x=f(dx<0?f(a.x)-f(ox):f(a.x)+f(ox));spentX=wantX;moved=true;}
       ox=MAX;
      }else{
       if(dy<0?oy<=posY:oy<=negY){a.y=f(dy<0?f(a.y)-f(oy):f(a.y)+f(oy));spentY=wantY;moved=true;}
       oy=MAX;
      }
     }
    }
   }
  }
  placed.push({index:i,x:a.x,y:a.y,z:a.z});
 }
 return {rows,placed};
}
