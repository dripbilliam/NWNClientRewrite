import * as T from 'three';
import {RendererModelPreparation} from '../src/renderer_model_preparation.js';
const assert=(value,message)=>{if(!value)throw Error(message);};
const digest=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
window.runModelBatchGpuFixture=async()=>{
 const rows=[];let screenshot;
 for(const mode of ['individual','batch']){
  const canvas=document.createElement('canvas'),renderer=new T.WebGLRenderer({canvas,antialias:false,preserveDrawingBuffer:true});renderer.setPixelRatio(1);renderer.setSize(1024,768,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;renderer.outputColorSpace=T.SRGBColorSpace;renderer.setClearColor(0x17212a);
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(45,1024/768,.1,150);camera.position.set(13,22,28);camera.lookAt(0,0,0);scene.add(new T.AmbientLight(0xddddff,.6));
  for(let i=0;i<3;i++){const light=new T.PointLight([0xffddbb,0xbbeeff,0xffccff][i],150,50,2);light.position.set(i*8-8,9,5-i*5);light.castShadow=true;light.shadow.mapSize.set(128,128);scene.add(light);}
  const floor=new T.Mesh(new T.PlaneGeometry(40,30),new T.MeshLambertMaterial({color:0x667766}));floor.rotation.x=-Math.PI/2;floor.position.y=-.1;floor.receiveShadow=true;scene.add(floor);
  const assets=Array.from({length:19},(_,i)=>{const bytes=Uint8Array.from({length:4*4*4},(_,n)=>n%4===3?(n%8===7?128:255):(i*13+n*17)%256),texture=new T.DataTexture(bytes,4,4);texture.colorSpace=T.SRGBColorSpace;texture.needsUpdate=true;return{i,texture};});
  const createRoot=asset=>{const root=new T.Group(),material=new T.MeshLambertMaterial({map:asset.texture,alphaTest:asset.i%4===0?.4:0,transparent:asset.i%5===0,opacity:asset.i%5===0?.7:1,side:asset.i%3===0?T.DoubleSide:T.FrontSide}),mesh=new T.Mesh(new T.BoxGeometry(1.6,2.5,1.3),material);mesh.castShadow=true;mesh.receiveShadow=true;root.add(mesh);return root;};
  const destroyRoot=root=>root.traverse(node=>{node.geometry?.dispose();for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])material.dispose();});
  const owner=new RendererModelPreparation({renderer,scene,camera,createRoot,destroyRoot,profile:()=>JSON.stringify([3,3,renderer.shadowMap.type,renderer.outputColorSpace])}),entries=assets.map((asset,i)=>({asset,name:`authored_part_${i}`})),began=performance.now();
  try{
   if(mode==='batch')assert(await owner.prepareBatch(entries),'batch rejected');else for(const entry of entries)assert(await owner.prepare(entry.asset,entry.name),'individual rejected');
   const roots=[];for(const entry of entries){if(mode==='individual')assert(await owner.prepare(entry.asset,entry.name),'second individual rejected');const root=createRoot(entry.asset);root.position.set(entry.asset.i%7*2.5-7.5,1.25,Math.floor(entry.asset.i/7)*3-3);scene.add(root);roots.push(root);}
   const preparationMs=performance.now()-began,programsBefore=renderer.info.programs.length,pixels=new Uint8Array(1024*768*4),hashes=[],draws=[];
   for(let frame=0;frame<6;frame++){
    await new Promise(requestAnimationFrame);for(const [i,root]of roots.entries()){root.rotation.y=frame*.17+i*.05;root.position.y=1.25+Math.sin(frame*.4+i)*.2;}
    renderer.render(scene,camera);const gl=renderer.getContext();gl.finish();gl.readPixels(0,0,1024,768,gl.RGBA,gl.UNSIGNED_BYTE,pixels);hashes.push(await digest(pixels));draws.push({...renderer.info.render});assert(gl.getError()===0,'WebGL error');
   }
   screenshot=canvas.toDataURL('image/png');const programsAfterRender=renderer.info.programs.length,shadowMaps=[];scene.traverse(object=>{if(object.isPointLight){assert(Boolean(object.shadow.map),'point shadow was never drawn');shadowMaps.push([object.shadow.map.width,object.shadow.map.height]);}});const stats=owner.snapshot();owner.dispose();for(let i=0;i<12&&owner.stats.destroyed!==19;i++)await Promise.resolve();assert(owner.stats.destroyed===19,'templates did not retire');rows.push({mode,preparationMs,stats,programsBefore,programsAfterRender,shadowMaps,programsAfter:renderer.info.programs.length,hashes,draws,retired:owner.stats.destroyed});for(const root of roots)destroyRoot(root);
  }finally{owner.dispose();floor.geometry.dispose();floor.material.dispose();for(const asset of assets)asset.texture.dispose();scene.traverse(object=>object.shadow?.dispose());renderer.dispose();renderer.forceContextLoss();}
 }
 assert(JSON.stringify(rows[0].hashes)===JSON.stringify(rows[1].hashes),'batch pixels differ');assert(JSON.stringify(rows[0].draws.map(({calls,triangles})=>[calls,triangles]))===JSON.stringify(rows[1].draws.map(({calls,triangles})=>[calls,triangles])),'batch draw geometry differs');assert(rows[0].programsBefore===rows[1].programsBefore&&rows[0].programsAfter===rows[1].programsAfter&&rows[0].programsAfterRender===rows[1].programsAfterRender,'batch shader coverage differs');
 assert(rows[0].stats.profileScans===38&&rows[1].stats.profileScans===1,'profile grouping missing');assert(rows[0].stats.compileCalls===57&&rows[1].stats.compileCalls===3,'shader grouping missing');return{success:true,scope:'Authored WebGL shader variants, moving poses and shadow output; not native assets or live FPS',rows,screenshot};
};
