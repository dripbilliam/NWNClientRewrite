import {nuiValue,nuiText} from './nui_state.js';
const NS='http://www.w3.org/2000/svg',svg=(tag,attributes={})=>{const node=document.createElementNS(NS,tag);for(const[k,v]of Object.entries(attributes))node.setAttribute(k,String(v));return node;};
export const nuiColor=(value,fallback='#fff')=>value&&typeof value==='object'?`rgba(${value.r??255},${value.g??255},${value.b??255},${Math.max(0,Math.min(255,value.a??255))/255})`:fallback;
// Draw commands are SVG primitives, never server HTML or executable code.
export function nuiDrawList(host,window,element,index,{image,text,interaction={},order=1}){
 const list=nuiValue(window,element.draw_list,index);if(!Array.isArray(list)||!list.length)return null;const layer=svg('svg');layer.classList.add('nui-draw-list');if(nuiValue(window,element.draw_list_scissor,index)!==false)layer.style.overflow='hidden';else layer.style.overflow='visible';
 for(const item of list){if(!item||typeof item!=='object')continue;let count=1;if(item.arrayBinds)for(const[key,value]of Object.entries(item)){if(key==='arrayBinds')continue;const v=nuiValue(window,value,-1);if(value?.bind&&Array.isArray(v))count=Math.max(count,v.length);}for(let arrayIndex=0;arrayIndex<count;arrayIndex++){
  const at=key=>nuiValue(window,item[key],item.arrayBinds?arrayIndex:index),enabled=at('enabled');if(enabled===false||(Number(at('order')??1)===-1?-1:1)!==order)continue;const render=Number(at('render')??0);if(render===1&&interaction.hover||render===2&&!interaction.hover||render>=3&&interaction.button!==({3:0,4:2,5:1})[render])continue;
  const color=nuiColor(at('color')),fill=at('fill')?color:'none',width=Number(at('line_thickness')??1),style={fill,stroke:color,'stroke-width':width},rect=at('rect')??{},a=at('a')??{},b=at('b')??{};let shape;
  switch(Number(item.type)){
   case 0:{const raw=at('points')??[],points=typeof raw[0]==='number'?Array.from({length:Math.floor(raw.length/2)},(_,i)=>({x:raw[i*2],y:raw[i*2+1]})):raw;shape=svg(at('fill')?'polygon':'polyline',{...style,points:points.map(p=>`${p.x??0},${p.y??0}`).join(' ')});break;}
   case 1:{const c=at('ctrl0')??{},d=at('ctrl1')??{};shape=svg('path',{...style,fill:'none',d:`M${a.x??0} ${a.y??0} C${c.x??0} ${c.y??0},${d.x??0} ${d.y??0},${b.x??0} ${b.y??0}`});break;}
   case 2:shape=svg('ellipse',{...style,cx:(rect.x??0)+(rect.w??0)/2,cy:(rect.y??0)+(rect.h??0)/2,rx:Math.max(0,(rect.w??0)/2),ry:Math.max(0,(rect.h??0)/2)});break;
   case 3:{const c=at('c')??{},radius=Number(at('radius')??0),start=Number(at('amin')??0),end=Number(at('amax')??0),x0=(c.x??0)+Math.cos(start)*radius,y0=(c.y??0)+Math.sin(start)*radius,x1=(c.x??0)+Math.cos(end)*radius,y1=(c.y??0)+Math.sin(end)*radius;shape=svg('path',{...style,d:`M${x0} ${y0} A${radius} ${radius} 0 ${Math.abs(end-start)>Math.PI?1:0} ${end>=start?1:0} ${x1} ${y1}${at('fill')?` L${c.x??0} ${c.y??0} Z`:''}`});break;}
   case 4:shape=svg('text',{x:rect.x??0,y:rect.y??0,fill:color,'dominant-baseline':'text-before-edge'});shape.textContent=nuiText(at('text'),item.text);if(at('font'))shape.style.fontFamily=String(at('font'));if(text)text(shape,at('text'),window,item.text,index);break;
   case 5:{shape=svg('svg',{x:rect.x??0,y:rect.y??0,width:Math.max(0,rect.w??0),height:Math.max(0,rect.h??0)});const region=at('image_region'),img=svg('image',{x:0,y:0,width:rect.w??0,height:rect.h??0,preserveAspectRatio:Number(at('image_aspect'))===5?'none':'xMidYMid meet'});shape.append(img);image?.(img,at('image'),region);break;}
   case 6:shape=svg('line',{...style,x1:a.x??0,y1:a.y??0,x2:b.x??0,y2:b.y??0});break;
   case 7:shape=svg('rect',{...style,x:rect.x??0,y:rect.y??0,width:Math.max(0,rect.w??0),height:Math.max(0,rect.h??0)});break;
   default:throw Error(`Unsupported NUI draw command ${item.type}`);
  }
  shape.dataset.order=String(at('order')??1);layer.append(shape);
 }}layer.dataset.order=String(order);host.append(layer);return layer;
}
export function nuiChart(host,slots,{resolve=value=>value,onPoint=()=>{}}={}){
 const chart=svg('svg',{viewBox:'0 0 300 120',preserveAspectRatio:'none'});chart.classList.add('nui-chart');const list=Array.isArray(slots)?slots:[],values=list.flatMap(s=>resolve(s.data)??[]).map(Number).filter(Number.isFinite),min=Math.min(0,...values),max=Math.max(1,...values),y=n=>110-(Number(n)-min)/(max-min)*100;
 list.forEach((slot,slotIndex)=>{const data=resolve(slot.data)??[],color=nuiColor(resolve(slot.color));if(Number(slot.type)===1)for(const[n,value]of data.entries()){const width=280/Math.max(1,data.length),shape=svg('rect',{x:10+n*width,y:y(value),width:Math.max(0,width-2),height:110-y(value),fill:color});shape.addEventListener('click',()=>onPoint(slotIndex,n));chart.append(shape);}else{chart.append(svg('polyline',{points:data.map((v,i)=>`${10+i*280/Math.max(1,data.length-1)},${y(v)}`).join(' '),fill:'none',stroke:color,'stroke-width':2}));for(const[n,value]of data.entries()){const point=svg('circle',{cx:10+n*280/Math.max(1,data.length-1),cy:y(value),r:4,fill:color});point.addEventListener('click',()=>onPoint(slotIndex,n));chart.append(point);}}});host.append(chart);return chart;
}
