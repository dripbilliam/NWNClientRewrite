// Renderer membership only. Object3D add/remove/attach/clear events invalidate
// the ordered traversal; animation, visibility and gameplay state stay live.
// Model emitter/static-tile tags are assigned before attachment. A producer
// changing those tags in place must explicitly invalidate its hierarchy.
const roots=new WeakMap();
class Hierarchy{
 constructor(root){this.root=root;this.users=0;this.revision=0;this.cachedRevision=-1;this.members=new Set();this.ordered=[];this.added=e=>{this.watch(e.child);this.revision++;};this.removed=e=>{this.unwatch(e.child);this.revision++;};this.watch(root);}
 watch(node){if(this.members.has(node))return;this.members.add(node);node.addEventListener('childadded',this.added);node.addEventListener('childremoved',this.removed);for(const child of node.children)this.watch(child);}
 unwatch(node){this.members.delete(node);node.removeEventListener('childadded',this.added);node.removeEventListener('childremoved',this.removed);for(const child of node.children)this.unwatch(child);}
 nodes(){if(this.cachedRevision!==this.revision){this.ordered=[];this.root.traverse(node=>this.ordered.push(node));this.cachedRevision=this.revision;}return this.ordered;}
 dispose(){this.unwatch(this.root);this.ordered=[];roots.delete(this.root);}
}
export function observeRendererHierarchy(root){
 let state=roots.get(root);if(!state){state=new Hierarchy(root);roots.set(root,state);}state.users++;let released=false;
 return{get revision(){return state.revision;},get nodes(){return state.nodes();},release(){if(released)return;released=true;if(--state.users===0)state.dispose();}};
}
export function invalidateRendererHierarchy(root){const state=roots.get(root);if(state)state.revision++;}
