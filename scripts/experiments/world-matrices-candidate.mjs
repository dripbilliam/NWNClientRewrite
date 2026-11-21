import {Object3D,Matrix4} from 'three';
const base=Object3D.prototype,matrix=Matrix4.prototype;
const equal=(a,b,k=0)=>Object.is(a[k],b[0])&&Object.is(a[k+1],b[1])&&Object.is(a[k+2],b[2])&&Object.is(a[k+3],b[3])&&Object.is(a[k+4],b[4])&&Object.is(a[k+5],b[5])&&Object.is(a[k+6],b[6])&&Object.is(a[k+7],b[7])&&Object.is(a[k+8],b[8])&&Object.is(a[k+9],b[9])&&Object.is(a[k+10],b[10])&&Object.is(a[k+11],b[11])&&Object.is(a[k+12],b[12])&&Object.is(a[k+13],b[13])&&Object.is(a[k+14],b[14])&&Object.is(a[k+15],b[15]);
const save=(a,b,offset=0)=>{for(let i=0;i<b.length;i++)a[offset+i]=b[i];};
const samePose=(r,o)=>Object.is(r[0],o.position.x)&&Object.is(r[1],o.position.y)&&Object.is(r[2],o.position.z)&&Object.is(r[3],o.quaternion.x)&&Object.is(r[4],o.quaternion.y)&&Object.is(r[5],o.quaternion.z)&&Object.is(r[6],o.quaternion.w)&&Object.is(r[7],o.scale.x)&&Object.is(r[8],o.scale.y)&&Object.is(r[9],o.scale.z);
function savePose(r,o){r[0]=o.position.x;r[1]=o.position.y;r[2]=o.position.z;r[3]=o.quaternion.x;r[4]=o.quaternion.y;r[5]=o.quaternion.z;r[6]=o.quaternion.w;r[7]=o.scale.x;r[8]=o.scale.y;r[9]=o.scale.z;}

// A frame-boundary equivalent of Object3D.updateMatrixWorld. No objects or
// prototypes are patched. Unchanged multiplication inputs need no repeat
// arithmetic; direct matrix edits and Three's manual-update flags remain live.
export class RendererWorldMatrices{
 constructor(){this.reset();}
 reset(){this.records=new WeakMap();this.stats={visited:0,composed:0,worldUpdated:0,fallbacks:0};}
 update(root,force=false){this.stats={visited:0,composed:0,worldUpdated:0,fallbacks:0};this.visit(root,force,true);return this.snapshot();}
 visit(object,force,parentChanged){
  this.stats.visited++;
  if(object.updateMatrixWorld!==base.updateMatrixWorld||object.updateMatrix!==base.updateMatrix||object.matrix.compose!==matrix.compose||object.matrixWorld.multiplyMatrices!==matrix.multiplyMatrices||object.matrixWorld.copy!==matrix.copy){this.records.delete(object);this.stats.fallbacks++;object.updateMatrixWorld(force);return;}
  let record=this.records.get(object);const fresh=!record;
  if(fresh){record={values:Array(42).fill(0),parent:object.parent,auto:false};this.records.set(object,record);}
  const values=record.values;
  let localChanged=fresh||!equal(values,object.matrix.elements,10);
  if(object.matrixAutoUpdate&&(fresh||!record.auto||localChanged||!samePose(values,object))){object.updateMatrix();savePose(values,object);localChanged=true;this.stats.composed++;}
  const nativeForce=Boolean(force||object.matrixWorldNeedsUpdate||object.matrixAutoUpdate);
  const worldChangedBefore=fresh||!equal(values,object.matrixWorld.elements,26);
  const worldInputsChanged=record.pending||fresh||localChanged||parentChanged||record.parent!==object.parent||worldChangedBefore;
  if(nativeForce&&object.matrixWorldAutoUpdate===true&&worldInputsChanged){
   if(object.parent===null)object.matrixWorld.copy(object.matrix);else object.matrixWorld.multiplyMatrices(object.parent.matrixWorld,object.matrix);
   this.stats.worldUpdated++;record.pending=false;
  }else if(worldInputsChanged)record.pending=true;
  if(nativeForce)object.matrixWorldNeedsUpdate=false;
  const changed=fresh||!equal(values,object.matrixWorld.elements,26);
  if(localChanged)save(values,object.matrix.elements,10);
  if(changed)save(values,object.matrixWorld.elements,26);
  record.parent=object.parent;record.auto=object.matrixAutoUpdate;
  for(let i=0,l=object.children.length;i<l;i++)this.visit(object.children[i],nativeForce,changed);
 }
 snapshot(){return{...this.stats};}
}
