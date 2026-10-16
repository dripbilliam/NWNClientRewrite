import {multiplyParticleQuaternion,rotateParticleVector} from './particle_math.js';
const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual node pose provider ${name} is unavailable`);return p[name](...args);};
// normalize140230710 uses exact squared==1, unlike Vector::Normalize's
// unit-length tolerance. Its nonpositive/NaN branch writes identity in-place.
export function normalizeVisualQuaternion(q){
  const [w,x,y,z]=q.map(f),squared=f(f(f(f(x*x)+f(w*w))+f(y*y))+f(z*z));
  if(squared===1)return[w,x,y,z];
  if(!(squared>0)){q.splice(0,4,1,0,0,0);return[1,0,0,0];}
  const scale=f(Math.sqrt(f(1/squared)));return[w,x,y,z].map(v=>f(v*scale));
}
// Gob::SetPartPosition1400950b0. The global-pose provider sees the reset
// local transform before calculating the parent/base pose. Native inverse
// sign flips w only; a full four-component negation would change no rotation.
export function setVisualNodePose(model,name,position,quaternion,p){
  const node=call(p,'findNode',model,name);if(!node)return 0;
  node.position10=[0,0,0];node.quaternion1c=[1,0,0,0];
  const base=call(p,'globalPose',node),inverse=base.quaternion.map(f);inverse[0]=f(-inverse[0]);
  const displacement=position.map((v,i)=>f(f(v)-f(base.position[i])));
  node.position10=rotateParticleVector(inverse,displacement);
  node.quaternion1c=normalizeVisualQuaternion(multiplyParticleQuaternion(inverse,quaternion));node.dirty60=1;return 1;
}
// Gob::GetPartPosition14008f4d0. Optional destinations remain untouched when
// node lookup fails; globalPose is queried even when both outputs are null.
export function getVisualNodePose(model,name,position,quaternion,p){
  const node=call(p,'findNode',model,name);if(!node)return 0;
  const pose=call(p,'globalPose',node);
  if(position)position.splice(0,3,...pose.position.map(f));
  if(quaternion)quaternion.splice(0,4,...pose.quaternion.map(f));return 1;
}

// Local virtual140/148 are direct node-field copies (140095050/14008f470),
// not global-pose queries. In particular the setter does NOT normalize q.
export function setVisualLocalNodePose(model,name,position,quaternion,p){
  const node=call(p,'findNode',model,name);if(!node)return 0;
  node.position10=position.map(f);node.quaternion1c=quaternion.map(f);node.dirty60=1;return 1;
}
export function getVisualLocalNodePose(model,name,position,quaternion,p){
  const node=call(p,'findNode',model,name);if(!node)return 0;
  if(position)position.splice(0,3,...node.position10.map(f));
  if(quaternion)quaternion.splice(0,4,...node.quaternion1c.map(f));return 1;
}
