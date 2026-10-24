import {Object3D} from 'three';
const owned=Symbol('cached renderer root matrix'),compose=Object3D.prototype.updateMatrix;
function updateCachedMatrix(){
 const state=this[owned],v=state.values,p=this.position,q=this.quaternion,s=this.scale,m=this.matrix.elements;
 // Read public producer state on EVERY call, including direct component writes.
 // An edited local matrix must still be recomposed just like Object3D would.
 let equal=state.ready&&Object.is(v[0],p.x)&&Object.is(v[1],p.y)&&Object.is(v[2],p.z)&&Object.is(v[3],q.x)&&Object.is(v[4],q.y)&&Object.is(v[5],q.z)&&Object.is(v[6],q.w)&&Object.is(v[7],s.x)&&Object.is(v[8],s.y)&&Object.is(v[9],s.z);
 if(equal)for(let i=0;i<16;i++)if(!Object.is(v[10+i],m[i])){equal=false;break;}
 if(!equal){compose.call(this);v[0]=p.x;v[1]=p.y;v[2]=p.z;v[3]=q.x;v[4]=q.y;v[5]=q.z;v[6]=q.w;v[7]=s.x;v[8]=s.y;v[9]=s.z;for(let i=0;i<16;i++)v[10+i]=m[i];state.ready=true;}
 // Reparenting changes world space even when both parents were already clean.
 if(state.parent!==this.parent)this.matrixWorldNeedsUpdate=true;state.parent=this.parent;
}
// Renderer-owned automatic wrappers/roots only. Controlled model nodes keep
// their existing explicit commit path; custom updateMatrix methods stay intact.
// No Three prototype or matrixWorld update/query behavior is replaced.
export function cacheRootMatrix(object){
 if(!object.matrixAutoUpdate||object.updateMatrix!==compose)return false;
 object[owned]={values:new Float64Array(26),ready:false,parent:null};object.updateMatrix=updateCachedMatrix;return true;
}
export function isCachedRootMatrix(object){return Boolean(object[owned]&&object.updateMatrix===updateCachedMatrix);}
