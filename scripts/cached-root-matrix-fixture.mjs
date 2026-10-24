import * as T from 'three';
import {cacheRootMatrix} from '../src/cached_root_matrix.js';
import {manageLocalMatrix,commitLocalMatrix} from '../src/managed_local_matrix.js';
const check=(value,message)=>{if(!value)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(value=>value.toString(16).padStart(2,'0')).join('');
window.runCachedRootMatrixFixture=async()=>{
 const results=[];let screenshot;
 for(const cached of [false,true]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(768,512,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(44,1.5,.1,100),a=new T.Group(),b=new T.Group(),wrappers=[],geometry=new T.BoxGeometry(.55,1,.55),material=new T.MeshLambertMaterial({color:0xc19861});manageLocalMatrix(scene);scene.background=new T.Color(0x19211e);scene.add(a,b);a.position.x=-1;b.position.set(.8,0,.3);
  for(let i=0;i<96;i++){const wrapper=new T.Group(),node=new T.Group(),mesh=new T.Mesh(geometry,material);wrapper.position.set((i%12-5.5)*.8,.5,(Math.floor(i/12)-3.5)*.8);manageLocalMatrix(node);manageLocalMatrix(mesh);mesh.castShadow=mesh.receiveShadow=true;node.add(mesh);wrapper.add(node);a.add(wrapper);wrappers.push({wrapper,node});}
  const ground=new T.Mesh(new T.PlaneGeometry(24,24),new T.MeshLambertMaterial({color:0x41634b}));ground.rotation.x=-Math.PI/2;ground.receiveShadow=true;scene.add(ground,new T.AmbientLight(0xffffff,.6));const sun=new T.DirectionalLight(0xffffff,2);sun.position.set(5,12,6);sun.castShadow=true;sun.shadow.camera.left=sun.shadow.camera.bottom=-12;sun.shadow.camera.right=sun.shadow.camera.top=12;sun.shadow.mapSize.set(512,512);scene.add(sun,sun.target);
  if(cached)scene.traverse(cacheRootMatrix);const rows=[];
  try{for(let frame=0;frame<24;frame++){
   if(frame%3===0)a.rotation.y=frame*.007;
   for(let i=0;i<wrappers.length;i++){const {wrapper,node}=wrappers[i];if(i%5===0){wrapper.position.y=.5+Math.sin(frame*.2+i)*.2;wrapper.rotation.y=frame*.03;}if(i%7===0){node.rotation.z=Math.sin(frame*.1+i)*.1;commitLocalMatrix(node);}}
   if(frame===5)b.add(wrappers[0].wrapper);if(frame===12)a.add(wrappers[0].wrapper);if(frame===16)wrappers[1].wrapper.matrix.elements[13]=99;
   camera.position.set(9+frame*.02,11,16-frame*.03);camera.lookAt(0,0,0);scene.updateMatrixWorld();if(frame%4===0)wrappers[2].node.updateWorldMatrix(true,false);renderer.render(scene,camera);const pixels=new Uint8Array(768*512*4);renderer.getContext().readPixels(0,0,768,512,renderer.getContext().RGBA,renderer.getContext().UNSIGNED_BYTE,pixels);rows.push({frame,pixels:await hash(pixels),draw:{calls:renderer.info.render.calls,triangles:renderer.info.render.triangles}});if(cached&&frame===23)screenshot=renderer.domElement.toDataURL();
  }results.push({cached,rows});}finally{geometry.dispose();material.dispose();ground.geometry.dispose();ground.material.dispose();sun.shadow.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 const comparisons=results[0].rows.map((row,i)=>({frame:i,pixels:row.pixels===results[1].rows[i].pixels,draw:JSON.stringify(row.draw)===JSON.stringify(results[1].rows[i].draw)}));check(comparisons.every(row=>row.pixels&&row.draw),'Cached-root GPU output differs');return{success:true,comparisons,results,screenshot,scope:'Authored moving/animated/reparented wrappers and local-matrix edits; exact main+shadow GPU output and draw counts. Not native performance acceptance.'};
};
