import {nativeAtan2f} from './native_math.js';
const f=Math.fround,tenth=f(.1),pixel=f(.01),half=f(.5),cvtt=value=>Number.isFinite(value)&&value>=-2147483648&&value<2147483648?Math.trunc(value)|0:-2147483648;

// Complete direction angle14022f690..14022f6ce, called at140894c88.
// Constant140d81948; the following Euler/model rotation is a graphics lower.
export function mapPlayerHeading(direction){const x=f(direction[0]),y=f(direction[1]);return x===0&&y===0?0:f(nativeAtan2f(f(-x),y)*57.2957763671875);}

// Bounded player-marker projection140894ba6..140894c74. Unlike pin
// widgets it keeps fractional pixel positions. Heading/model updates follow
// this block and are separate owners.
export function playerMapPosition(map,point){
 const scale=f(f(map.zoom514|0)*pixel),axis=(value,size)=>f(f(f(f(value)*tenth)*scale)-f(f(f(size|0)*scale)*half));
 let z=f(f(f(point[2])*tenth)*scale);if(z<f(-.09))z=f(-.09);
 return[axis(point[0],map.width),axis(point[1],map.height),z];
}

// Complete pin presentation140893860..140893ab9. GUI position lookup,
// attachment and model/view transforms are explicit lower-owner boundaries.
// This is native WXYZ identity, not the MDL/THREE XYZW storage convention.
export async function presentMapPin(map,pin,force,p){
 let attached=0;force|=0;let state=force;
 const finish=value=>{pin.nativeStateE8=state;return value;};
 if(force===0){
  const point=(await p.position(pin)).map(f),x=cvtt(f(point[0]*tenth)),y=cvtt(f(point[1]*tenth));
  if(x<0||x>=(map.width|0)||y<0||y>=(map.height|0))return finish(0);
  const tile=await p.tileState(map,(Math.imul(map.width,y)+x)|0);
  if(!Number.isInteger(tile))throw new Error('Native map pin tile state is unavailable');
  if((tile|0)!==1)return finish(0);state=1;
 }
 if((pin.nativeStateE8|0)===0){await p.attach(pin,map.container1e8,'root');attached=1;}
 const point=(await p.position(pin)).map(f),model=await p.model(pin),scale=f(f(map.zoom514|0)*pixel);
 const coordinate=(value,size)=>{
  let result=f(f(f(value*tenth)*scale)-f(f(f(size|0)*scale)*half));
  result=f(f(result/pixel)+half);return f(f(cvtt(result))*pixel);
 };
 const x=coordinate(point[0],map.width),y=coordinate(point[1],map.height),origin=await p.viewOrigin(map.view110);
 await p.transform(model,'root',[f(x+f(origin[0])),f(y+f(origin[1])),f(f(origin[2])+0)],[1,0,0,0]);return finish(attached);
}
