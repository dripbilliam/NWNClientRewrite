import test from 'node:test';
import assert from 'node:assert/strict';
import {Group,Mesh,BoxGeometry,MeshBasicMaterial} from 'three';
import {observeRendererHierarchy,invalidateRendererHierarchy} from '../src/renderer_hierarchy.js';
const expected=root=>{const nodes=[];root.traverse(n=>nodes.push(n));return nodes;};
test('shared ordered membership follows nested add/remove/reparent/clear without rebuilding for pose or visibility',()=>{
 const root=new Group(),a=new Group(),b=new Group(),mesh=new Mesh(new BoxGeometry(),new MeshBasicMaterial());root.add(a,b);a.add(mesh);
 const first=observeRendererHierarchy(root),second=observeRendererHierarchy(root),initial=first.nodes,revision=first.revision;
 a.position.x=5;a.visible=false;assert.equal(first.nodes,initial);assert.equal(first.revision,revision);assert.equal(first.nodes,second.nodes);
 const nested=new Group();a.add(nested);const child=new Group();nested.add(child);assert.deepEqual(first.nodes,expected(root));
 b.attach(mesh);assert.deepEqual(first.nodes,expected(root));nested.clear();assert.deepEqual(first.nodes,expected(root));
 nested.removeFromParent();const detachedRevision=first.revision;nested.add(new Group());assert.equal(first.revision,detachedRevision);
 first.release();first.release();b.add(new Group());assert.deepEqual(second.nodes,expected(root));
 const before=second.nodes;invalidateRendererHierarchy(root);assert.notEqual(second.nodes,before);assert.deepEqual(second.nodes,expected(root));
 second.release();assert.equal(root._listeners?.childadded?.length??0,0);assert.equal(mesh._listeners?.childremoved?.length??0,0);
});
test('overlapping roots retire their own subscriptions without disabling the remaining observer',()=>{
 const root=new Group(),subtree=new Group();root.add(subtree);const all=observeRendererHierarchy(root),sub=observeRendererHierarchy(subtree);all.release();const child=new Group();subtree.add(child);assert.deepEqual(sub.nodes,[subtree,child]);sub.release();assert.equal(child._listeners?.childadded?.length??0,0);
});
