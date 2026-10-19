import {particleRotationArc,multiplyParticleQuaternion} from './particle_math.js';
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native model reference provider ${n} is unavailable`);return p[n](...args);};
const f=Math.fround;

// Gob::ReattachReference140093b50. Physical breadth-first order matters:
// each eligible child changes the Gob quaternion before the next child.
export function reattachModelReferences(owner,target,name,p){
 const root=call(p,'root',owner);if(!root)throw new Error('Native reference reattachment requires a physical root');
 const queue=[root];
 while(queue.length){
  const part=queue[0],reference=call(p,'asReference',part);
  if(reference){
   const header=reference.header8;
   if(header&&(header.flags98&0x11)===0x11){
    if(!Number.isInteger(header.reattachableE0))throw new Error('Native reference reattachable field is unavailable');
    if(header.reattachableE0!==0&&reference.model68){
     call(p,'attach',reference.model68,target??owner,target?name:call(p,'name',reference),0);
     // Native reloads68 after AttachToObject, before querying its position.
     const child=call(p,'position',reference.model68),position=call(p,'position',owner),q=call(p,'orientation',owner).map(f),[w,x,y,z]=q;
     const delta=child.map((v,i)=>f(f(v)-f(position[i]))),xx=f(f(x*x)+f(y*y)),horizontal=f(f(z*x)+f(w*y)),vertical=f(f(z*y)-f(w*x));
     const forward=[f(horizontal+horizontal),f(vertical+vertical),f(1-f(xx+xx))];
     call(p,'setOrientation',owner,multiplyParticleQuaternion(particleRotationArc(forward,delta),q));
    }
   }
  }
  queue.shift();for(let i=0;i<part.children38.length;i++)queue.push(part.children38[i]);
 }
}

// Reference InternalControl1400524d0 ignores the cast result and delegates
// all transform channels to MdlNode::InternalControl140051c50.
export function controlReferencePart(node,part,previous,time,weight,p){
 call(p,'asReference',part);return call(p,'control',node,part,Math.fround(previous),Math.fround(time),Math.fround(weight));
}

// CreateReferenceObjects14008db90..14008dc59. The referenced CAurObject
// belongs to its PartReference68, not to the canonical game-object array.
export function createReferenceObjects(owner,part,p){
 const reference=call(p,'asReference',part);
 if(reference){
  const header=reference.header8;
  if(!header||(header.flags98&0x11)!==0x11)throw new Error('Native reference creation would dereference an invalid reference header');
  const model=call(p,'create',header.modelA0,null,null);reference.model68=model;
  if(!model)throw new Error('Native reference creation would dereference an unavailable child model');
  const name=call(p,'name',reference);call(p,'attach',model,owner,name,0);
 }
 // Re-read count/list at each step, matching the native recursive owner.
 for(let i=0;i<part.children38.length;i++)createReferenceObjects(owner,part.children38[i],p);
}

// PartReference deleting destructor14008acf0. Child destructor runs before
// Part::~Part; only flag bit0 requests freeing the reference part itself.
export function destroyReferencePart(part,flags,p){
 if(part.model68)call(p,'destroy',part.model68,1);
 call(p,'destroyPart',part);if((flags&1)!==0)call(p,'freePart',part,0x78);return part;
}
