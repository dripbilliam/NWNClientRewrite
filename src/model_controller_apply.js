import {sampleModelFloat,sampleModelVector,sampleModelQuaternion,interpolateModelQuaternion} from './model_controller_sample.js';
const f=Math.fround;
// Complete generic MdlNodeControl140051c50..140051e59. Controllers contain
// remapped signed32-bit displacements in bytes into Part, not disk type IDs.
// Specialized emitter/light/mesh finalization and motion-run work are separate
// owners. Read the live controller array/count again after each callback.
export function applyModelControllers(node,part,previous,time,weight,p){
 previous=f(previous);time=f(time);weight=f(weight);
 for(let i=0;i<(node.controllerCount80|0);i++){
  const controller=node.controllers78[i],kind=controller.columnsA&15,offset=controller.displacement0|0;
  if(kind===1){
   const output=[0];sampleModelFloat(controller,time,node,output);
   const value=p.read(part,offset,1)[0];p.write(part,offset,[f(f(f(1-weight)*f(value))+f(output[0]*weight))]);
  }else if(kind===3){
   const output=[0,0,0];sampleModelVector(controller,time,node,output,offset===16?p.positionScale():1);
   const values=p.read(part,offset,3);p.write(part,offset,values.map((v,j)=>f(f(f(1-weight)*f(v))+f(output[j]*weight))));
  }else if(kind===4){
   const output=[1,0,0,0];sampleModelQuaternion(controller,time,node,output,p.math);
   const values=p.read(part,offset,4).map(f);p.write(part,offset,interpolateModelQuaternion(values,output,weight,p.math));
  }
  if(p.activeMotionRun())p.motion(node.controllers78[i],part,node,previous,time);
 }
}
