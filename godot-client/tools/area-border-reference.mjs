// Original CNWCArea.LoadBorder1407dea10. Private value plan only.
const f=Math.fround,lower=s=>String(s).replace(/[A-Z]/g,c=>c.toLowerCase());
const corners=['TopRight','BottomRight','BottomLeft','TopLeft'],edges=['Top','Right','Bottom','Left'];
const i32=n=>n|0;
export function nativeAreaBorderPlan(area,set,table,{enabled,disabled}){
 if(typeof enabled!=='boolean'||typeof disabled!=='boolean')throw Error('Explicit native setting/area gate required');
 if(!enabled||disabled)return {enabled:false,placements:[],attempts:[]};
 if(table===null)return {enabled:true,loaded:false,placements:[],attempts:[]};
 const w=area.width,h=area.height;if(!Number.isInteger(w)||!Number.isInteger(h)||w<1||h<1||area.tiles.length!==w*h)throw Error('Invalid native area grid');
 const attempts=[],placements=[],rows=table.rows??table.orderedRows;
 const string=v=>v===undefined||v==='****'?'':String(v);
 const field=(row,name)=>{const key=Object.keys(row).find(k=>lower(k)===lower(name));return string(key===undefined?table.defaultValue??'':row[key]);};
 const corner=(tile,side)=>string(set.tiles[tile.id??tile.tile_id][corners[(side+tile.orientation)&3]]);
 const edge=(tile,side)=>string(set.tiles[tile.id??tile.tile_id][edges[(side+tile.orientation)&3]]);
 function add(side,x,y,index,a,b,e,direct){
  const tile=area.tiles[index];let selected=-1,orientation=null,rawModel='',height=0;
  for(let row=0;row<rows.length;row++){
   const value=rows[row],one=lower(field(value,'Corner1')),two=lower(field(value,'Corner2'));
   if(lower(field(value,'Edge'))!==lower(e))continue;
   if(one===lower(a)&&two===lower(b))orientation=direct;else if(one===lower(b)&&two===lower(a))orientation=(direct+2)&3;else continue;
   selected=row;rawModel=field(value,'Model');const rawHeight=field(value,'Height');
   if(!/^[+-]?\d+$/.test(rawHeight)&&rawHeight!=='')throw Error('Reference only admits resolved decimal native height in these installed samples');
   height=Number(rawHeight||0);break;
  }
  const nativePosition=[f(f(f(x)*f(10))+f(5)),f(f(f(y)*f(10))+f(5)),f(f(set.transition)*f(i32(height+tile.height)))];
  const result={side,x,y,sourceIndex:index,row:selected,rawModel,model:lower(rawModel.slice(0,16)),orientation,nativePosition,position:[nativePosition[0],nativePosition[2],-nativePosition[1]],nativeSpawnFlags:1};
  attempts.push(result);if(rawModel)placements.push(result);
 }
 for(let y=-5;y<h+5;y++)for(let x=-5;x<0;x++){
  const index=Math.max(0,Math.min(h-1,y))*w,t=area.tiles[index];
  add('left',x,y,index,y<0?'':corner(t,3),y>=h?'':corner(t,2),y<0||y>=h?'':edge(t,3),0);
 }
 for(let y=-5;y<h+5;y++)for(let x=w;x<w+5;x++){
  const index=Math.max(0,Math.min(h-1,y))*w+w-1,t=area.tiles[index];
  add('right',x,y,index,y>=h?'':corner(t,y<0?1:0),y<0?'':corner(t,y>=h?0:1),y<0||y>=h?'':edge(t,1),0);
 }
 for(let y=-5;y<0;y++)for(let x=0;x<w;x++){const index=x,t=area.tiles[index];add('bottom',x,y,index,corner(t,2),corner(t,1),edge(t,2),1);}
 for(let y=h;y<h+5;y++)for(let x=0;x<w;x++){const index=(h-1)*w+x,t=area.tiles[index];add('top',x,y,index,corner(t,3),corner(t,0),edge(t,0),1);}
 return {enabled:true,loaded:true,attempts,placements};
}
