// Opt-in renderer ownership: these model nodes are written only by their
// animation/pose producers. Queries may update world matrices repeatedly
// without composing unchanged local transforms. Arbitrary Object3Ds retain
// Three's automatic behavior; opted-in writers must commit after changing PQS.
import {Object3D} from 'three';
import {matrixOwnerCooperationEnabled,isObservedRendererCompose} from './renderer_matrix_subtree.js';
import {isCachedRootMatrix} from './cached_root_matrix.js';
const compose=Object3D.prototype.updateMatrix,committed=new WeakMap();
let reuse=false;
const counters={commits:0,reused:0,composed:0,fallback:0};
export function setManagedMatrixReuse(enabled){reuse=Boolean(enabled);}
export function managedMatrixReuseSnapshot(){return{enabled:reuse,...counters};}
export function manageLocalMatrix(object){object.updateMatrix();object.matrixAutoUpdate=false;object.userData.rendererLocalMatrix=true;return object;}
export function commitLocalMatrix(object){
 if(!object.userData.rendererLocalMatrix||object.matrixAutoUpdate!==false)return;
 if(!reuse){object.updateMatrix();return;}
 counters.commits++;
 if(object.updateMatrix!==compose&&!(matrixOwnerCooperationEnabled()&&(isObservedRendererCompose(object)||isCachedRootMatrix(object)))){counters.fallback++;object.updateMatrix();return;}
 const p=object.position,q=object.quaternion,s=object.scale,m=object.matrix.elements;
 let state=committed.get(object),v=state?.values;
 let equal=Boolean(state&&state.parent===object.parent&&state.matrix===object.matrix&&state.elements===m&&Object.is(v[0],p.x)&&Object.is(v[1],p.y)&&Object.is(v[2],p.z)&&Object.is(v[3],q.x)&&Object.is(v[4],q.y)&&Object.is(v[5],q.z)&&Object.is(v[6],q.w)&&Object.is(v[7],s.x)&&Object.is(v[8],s.y)&&Object.is(v[9],s.z));
 if(equal)for(let i=0;i<16;i++)if(!Object.is(v[10+i],m[i])){equal=false;break;}
 if(equal){counters.reused++;return;}
 object.updateMatrix();counters.composed++;
 if(!state){state={values:new Float64Array(26)};committed.set(object,state);v=state.values;}
 state.parent=object.parent;state.matrix=object.matrix;state.elements=object.matrix.elements;
 v[0]=p.x;v[1]=p.y;v[2]=p.z;v[3]=q.x;v[4]=q.y;v[5]=q.z;v[6]=q.w;v[7]=s.x;v[8]=s.y;v[9]=s.z;
 for(let i=0;i<16;i++)v[10+i]=state.elements[i];
}
