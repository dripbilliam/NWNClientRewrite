import {Object3D} from 'three';
import {isCachedRootMatrix} from './cached_root_matrix.js';
const commitOwners=new WeakMap(),compose=Object3D.prototype.updateMatrix;
function observedCompose(){const record=commitOwners.get(this);if(!record)return compose.call(this);for(const invalidate of record.owners)invalidate();return record.before.call(this);}
function observeCommits(object,invalidate){
 let record=commitOwners.get(object);
 if(record&&object.updateMatrix!==observedCompose)return null;
 if(!record){if(object.updateMatrix!==compose&&!(cooperate&&isCachedRootMatrix(object)))return null;record={before:object.updateMatrix,owners:new Set()};commitOwners.set(object,record);object.updateMatrix=observedCompose;}
 record.owners.add(invalidate);return()=>{record.owners.delete(invalidate);if(!record.owners.size){if(object.updateMatrix===observedCompose)object.updateMatrix=record.before;commitOwners.delete(object);}};
}
let enabled=false,cooperate=false;
const owners=new Set(),stats={walks:0,skipped:0};
export function setMatrixSubtreeReuse(value){enabled=Boolean(value);}
export function matrixOwnerCooperationEnabled(){return cooperate;}
export function isObservedRendererCompose(object){return commitOwners.has(object)&&object.updateMatrix===observedCompose;}
// Private experiment: recognize only the known renderer composition owners.
// Rebuild existing registrations at a mode boundary, so disabling restores the
// original fallback behavior and forces one fresh world walk.
export function setMatrixOwnerCooperation(value){const next=Boolean(value);if(next===cooperate)return;cooperate=next;for(const state of owners)state.rebuild();}
export function matrixSubtreeSnapshot(){return{enabled,cooperation:cooperate,owners:owners.size,nodes:[...owners].reduce((n,o)=>n+o.members.size,0),...stats};}
// Explicit renderer ownership only: local PQS writers must commit. Arbitrary
// automatic descendants retain ordinary traversal; queries remain untouched.
export function ownMatrixSubtree(root){
 const before=root.updateMatrixWorld;
 if(root.matrixAutoUpdate||!root.userData.rendererLocalMatrix||before!==Object3D.prototype.updateMatrixWorld)return()=>{};
 const state={members:new Map(),dirty:true,automatic:0};owners.add(state);
 const invalidate=()=>{state.dirty=true;};
 const watch=node=>{
  if(state.members.has(node))return;
  const manual=node.userData.rendererLocalMatrix&&node.matrixAutoUpdate===false;
  const added=e=>{watch(e.child);e.child.matrixWorldNeedsUpdate=true;state.dirty=true;},removed=e=>{unwatch(e.child);state.dirty=true;};
  const observed=manual?observeCommits(node,invalidate):null,release=observed??(()=>{}),eligible=manual&&Boolean(observed)&&(node.updateMatrixWorld===Object3D.prototype.updateMatrixWorld||node===root&&node.updateMatrixWorld===update);
  state.members.set(node,{added,removed,release,eligible});if(!eligible)state.automatic++;
  node.addEventListener('childadded',added);node.addEventListener('childremoved',removed);
  for(const child of node.children)watch(child);
 };
 const unwatch=node=>{const record=state.members.get(node);if(!record)return;record.release();node.removeEventListener('childadded',record.added);node.removeEventListener('childremoved',record.removed);if(!record.eligible)state.automatic--;state.members.delete(node);for(const child of node.children)unwatch(child);};
 const reparent=()=>{state.dirty=true;root.matrixWorldNeedsUpdate=true;};
 const update=function(force){
  if(enabled&&!force&&!state.dirty&&!this.matrixWorldNeedsUpdate&&!this.matrixAutoUpdate&&!state.automatic){stats.skipped++;return;}
  stats.walks++;state.dirty=false;try{return before.call(this,force);}catch(error){state.dirty=true;throw error;}
 };
 state.rebuild=()=>{unwatch(root);watch(root);state.dirty=true;root.matrixWorldNeedsUpdate=true;};
 try{watch(root);root.addEventListener('added',reparent);root.addEventListener('removed',reparent);root.updateMatrixWorld=update;}
 catch(error){unwatch(root);owners.delete(state);throw error;}
 let closed=false;return()=>{if(closed)return;closed=true;if(root.updateMatrixWorld===update)root.updateMatrixWorld=before;root.removeEventListener('added',reparent);root.removeEventListener('removed',reparent);unwatch(root);owners.delete(state);};
}
