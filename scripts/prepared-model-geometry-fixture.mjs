import * as T from '../node_modules/three/build/three.module.js';
import {buildModelGeometry} from '../src/prepared_model_geometry.js';
const hash=async data=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',data))].map(v=>v.toString(16).padStart(2,'0')).join('');
window.runPreparedModelGeometryFixture=async({cold,warm})=>{
 const canvas=document.createElement('canvas'),renderer=new T.WebGLRenderer({canvas,antialias:false,preserveDrawingBuffer:true});renderer.setSize(900,680,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;renderer.setClearColor(0x20312a);document.body.append(canvas);
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(45,900/680,.1,100);camera.position.set(10,13,18);camera.lookAt(0,1,0);scene.add(new T.AmbientLight(0xbed3ed,.7));
 const light=new T.PointLight(0xffddbb,80,40,2);light.position.set(4,8,3);light.castShadow=true;light.shadow.mapSize.set(256,256);scene.add(light);
 const floor=new T.Mesh(new T.PlaneGeometry(30,30),new T.MeshLambertMaterial({color:0x567365}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
 const materials=[new T.MeshLambertMaterial({color:0xb5c476}),new T.MeshLambertMaterial({color:0xb576ac,transparent:true,opacity:.6})],meshes=[],geometries=[cold,warm].map(model=>buildModelGeometry(model.nodes[0]));
 for(let i=0;i<18;i++){const mesh=new T.Mesh(geometries[0],materials);mesh.castShadow=mesh.receiveShadow=true;scene.add(mesh);meshes.push(mesh);}
 const rows=[];let screenshot;
 try{for(let frame=0;frame<16;frame++){
  for(const[i,mesh]of meshes.entries()){mesh.position.set(i%6*2-5,1+Math.sin(frame*.25+i)*.2,Math.floor(i/6)*2-2);mesh.rotation.set(frame*.09+i*.2,frame*.13+i*.3,i*.04);mesh.scale.setScalar(.6+(i%3)*.15);}
  const images=[],shadows=[];
  for(let mode=0;mode<2;mode++){
   for(const mesh of meshes)mesh.geometry=geometries[mode];renderer.render(scene,camera);
   const gl=renderer.getContext(),pixels=new Uint8Array(900*680*4);gl.readPixels(0,0,900,680,gl.RGBA,gl.UNSIGNED_BYTE,pixels);images.push(await hash(pixels));
   const target=light.shadow.map,shadow=new Uint8Array(target.width*target.height*4);renderer.readRenderTargetPixels(target,0,0,target.width,target.height,shadow);shadows.push(await hash(shadow));
  }
  if(images[0]!==images[1]||shadows[0]!==shadows[1])throw Error('Persistent geometry changed color/shadow output at frame '+frame);
  rows.push({frame,image:images[0],shadow:shadows[0]});if(frame===15)screenshot=canvas.toDataURL('image/png');
 }return{success:true,frames:rows,screenshot,scope:'Disk-reloaded authored model versus cold geometry, live transforms, material groups, transparency and real point shadows; no server joins'};
 }finally{for(const geometry of geometries)geometry.dispose();for(const material of materials)material.dispose();floor.geometry.dispose();floor.material.dispose();light.shadow.map?.dispose();renderer.dispose();}
};
