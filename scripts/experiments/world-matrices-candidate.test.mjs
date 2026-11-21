import test from 'node:test';
import assert from 'node:assert/strict';
import {Scene,Group,Mesh,BoxGeometry,MeshBasicMaterial,PerspectiveCamera,Vector3,Object3D} from 'three';
import {RendererWorldMatrices} from './world-matrices-candidate.mjs';
function fixture(){const root=new Scene(),nodes=[root];for(let i=1;i<140;i++){const o=i%7?new Group():new Mesh(new BoxGeometry(),new MeshBasicMaterial());o.position.set(Math.sin(i)*2,i*.013,Math.cos(i));o.rotation.set(i*.003,i*.004,-i*.006);o.scale.set(1+i*.001,.7+i*.002,1.3-i*.001);nodes[Math.floor((i-1)/4)].add(o);nodes.push(o);}return{root,nodes};}
function compare(a,b){for(let i=0;i<a.nodes.length;i++){const x=a.nodes[i],y=b.nodes[i];assert.deepEqual(x.matrix.elements,y.matrix.elements,`local${i}`);assert.deepEqual(x.matrixWorld.elements,y.matrixWorld.elements,`world${i}`);assert.equal(x.matrixWorldNeedsUpdate,y.matrixWorldNeedsUpdate,`dirty${i}`);}}
test('frame cache matches stock matrices and dirty flags across live/manual poses and hierarchy changes',()=>{
 const a=fixture(),b=fixture(),cache=new RendererWorldMatrices();
 for(let frame=0;frame<120;frame++){
  for(const f of [a,b]){
   f.nodes[frame%139+1].position.x=Math.sin(frame*.2);f.nodes[20].rotation.z=frame*.03;f.nodes[40].scale.y=frame%9===0?-1:.8;f.nodes[71].position.x=frame%2?-0:0;
   if(frame===4){f.nodes[10].matrixAutoUpdate=false;f.nodes[10].matrix.makeTranslation(2,5,7);f.nodes[10].matrixWorldNeedsUpdate=true;}
   if(frame===5){f.nodes[11].matrixWorldAutoUpdate=false;f.nodes[11].matrixWorld.makeTranslation(3,8,9);}
   if(frame===9)f.nodes[40].add(f.nodes[10]);if(frame===15){f.nodes[10].matrixAutoUpdate=true;f.nodes[11].matrixWorldAutoUpdate=true;}
   if(frame===22){f.root.matrixAutoUpdate=false;f.nodes[1].matrixAutoUpdate=false;f.nodes[1].matrixWorld.makeTranslation(11,13,17);}
   if(frame===23)f.nodes[1].matrix.makeTranslation(29,31,37);
   if(frame===24)f.nodes[1].matrixWorldNeedsUpdate=true;
   if(frame===25)f.root.matrixAutoUpdate=true;
   if(frame===30)f.nodes[14].matrix.makeScale(7,8,9); // automatic pose must overwrite direct local edit
   if(frame===31)f.nodes[15].matrixWorld.makeScale(2,4,6);
   if(frame===38)f.nodes[12].visible=false;
   if(frame===44)f.nodes[2].updateWorldMatrix(true,true); // external consumer between frame boundaries
   if(frame===60)f.nodes[16].removeFromParent();if(frame===61)f.nodes[4].add(f.nodes[16]);
  }
  a.root.updateMatrixWorld(frame%17===0);cache.update(b.root,frame%17===0);compare(a,b);
 }
 cache.reset();assert.equal(cache.snapshot().visited,0);
});
test('unchanged subtrees skip arithmetic; changed ancestors and explicit force keep exact output',()=>{
 const f=fixture(),cache=new RendererWorldMatrices();cache.update(f.root);assert.equal(cache.snapshot().worldUpdated,140);cache.update(f.root);assert.equal(cache.snapshot().worldUpdated,1);assert.equal(cache.snapshot().composed,0); // root parent is conservatively unknown
 f.nodes[1].position.x++;cache.update(f.root);assert.ok(cache.snapshot().worldUpdated>1);assert.ok(cache.snapshot().worldUpdated<140);assert.equal(cache.snapshot().composed,1);
});
test('custom update implementations and cameras retain their original subtree path',()=>{
 const a=fixture(),b=fixture(),cache=new RendererWorldMatrices();let before=0,after=0;
 for(const[f,callback]of [[a,()=>before++],[b,()=>after++]]){const custom=f.nodes[8];custom.updateMatrixWorld=function(force){callback();this.position.x+=.1;Object3D.prototype.updateMatrixWorld.call(this,force);};const c=new PerspectiveCamera();c.position.set(1,2,3);custom.add(c);f.nodes.push(c);}
 for(let i=0;i<5;i++){a.root.updateMatrixWorld();cache.update(b.root);compare(a,b);assert.deepEqual(a.nodes.at(-1).matrixWorldInverse.elements,b.nodes.at(-1).matrixWorldInverse.elements);}assert.equal(before,after);assert.equal(cache.snapshot().fallbacks,1);
});
test('a detached entry root observes its externally updated parent and preserves manual matrices',()=>{
 const parent=new Group(),child=new Group(),cache=new RendererWorldMatrices();parent.add(child);parent.position.x=3;parent.updateMatrixWorld();cache.update(child);parent.position.x=7;parent.updateMatrixWorld();cache.update(child);assert.equal(child.matrixWorld.elements[12],7);
 child.matrixAutoUpdate=false;child.matrixWorldNeedsUpdate=false;child.matrixWorld.makeTranslation(29,31,37);cache.update(child);assert.deepEqual(new Vector3().setFromMatrixPosition(child.matrixWorld).toArray(),[29,31,37]);
});
