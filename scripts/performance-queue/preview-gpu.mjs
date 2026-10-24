import * as THREE from 'three';
import {ModelParticlePresentation} from '../../src/model_particles.js';
import {createPreviewFactory,authoredPreviewModel,fixtureTextures,previewCounts,disposePreviewFixture,particleState,particleGraphSignature} from './preview-factory.mjs';
const check=(condition,message)=>{if(!condition)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');

window.runPreviewGpuFixture=async source=>{
  const renderer=new THREE.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(960,640,false);renderer.setPixelRatio(1);renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  document.body.append(renderer.domElement);
  const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(45,1.5,.1,100);camera.position.set(9,10,15);camera.lookAt(0,1,0);
  scene.add(new THREE.AmbientLight(0xbed3ed,.7));const light=new THREE.PointLight(0xffddbb,100,40,2);light.position.set(4,8,3);light.castShadow=true;light.shadow.mapSize.set(256,256);scene.add(light);
  const floor=new THREE.Mesh(new THREE.PlaneGeometry(24,24),new THREE.MeshLambertMaterial({color:0x556a54}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
  const modes=[true,false].map(previews=>{
    const factory=createPreviewFactory(source),textures=fixtureTextures(),root=factory.buildObject(authoredPreviewModel(),textures,null,{previews,shareGeometry:true,managedMatrices:true});scene.add(root);
    const reports=[],presentation=new ModelParticlePresentation({camera,seed:19645,report:(...row)=>reports.push(row)});
    return {previews,factory,textures,root,reports,presentation,counts:previewCounts(root)};
  });
  const rows=[];let screenshot;
  try {
    for(let frame=0;frame<24;frame++) {
      const frames=[];
      for(const item of modes) {
        item.root.position.set(Math.sin(frame*.13),0,0);item.root.rotation.y=frame*.07;item.root.scale.setScalar(frame<12?1:-1);
        item.presentation.update(item.root,[.016,.033,.05][frame%3]);
      }
      check(particleGraphSignature(particleState(modes[0].presentation))===particleGraphSignature(particleState(modes[1].presentation)),'Native particle state differs at '+frame);
      for(const item of modes) {
        for(const other of modes)other.root.visible=other===item;
        renderer.render(scene,camera);const gl=renderer.getContext(),pixels=new Uint8Array(960*640*4);gl.readPixels(0,0,960,640,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
        const target=light.shadow.map,shadow=new Uint8Array(target.width*target.height*4);renderer.readRenderTargetPixels(target,0,0,target.width,target.height,shadow);
        const ray=new THREE.Raycaster(camera.position.clone(),new THREE.Vector3(0,1.5,0).sub(camera.position).normalize());
        // Real emitters disable raycasting; invisible editor sprites are not
        // world targets. Compare the native model meshes explicitly.
        const meshes=[];item.root.traverse(n=>{if(n.userData.nativeModelMesh)meshes.push(n);});
        frames.push({color:await hash(pixels),shadow:await hash(shadow),draw:{calls:renderer.info.render.calls,triangles:renderer.info.render.triangles},hits:ray.intersectObjects(meshes,false).map(h=>({distance:h.distance,point:h.point.toArray(),face:h.faceIndex}))});
        check(gl.getError()===0,'WebGL error');
      }
      check(JSON.stringify(frames[0])===JSON.stringify(frames[1]),'GPU/picking parity differs at '+frame);
      rows.push({frame,...frames[0],random:{state:modes[0].presentation.random.state,draws:modes[0].presentation.random.draws}});
      if(frame===23)screenshot=renderer.domElement.toDataURL('image/png');
    }
    check(modes.every(item=>item.presentation.random.draws>0&&item.presentation.snapshot().every(e=>!e.failed&&e.active>0)),'Fixture did not exercise live particles');
    check(modes.every(item=>!item.reports.some(row=>row[0]==='particle.runtime-unavailable')),'Unavailable particle mode');
    return {success:true,scope:'Actual production factory; hidden editor preview opt-out versus original. Exact color, point-shadow, native particle/RNG, material and picking comparisons. Authored assets only.',counts:modes.map(item=>({previews:item.previews,...item.counts})),frames:rows,screenshot};
  } finally {
    for(const item of modes){disposePreviewFixture(item.root,item.factory,item.textures,item.presentation);const stats=item.factory.pool.snapshot();check(!stats.active&&!stats.owners&&stats.created===stats.retired,'Geometry ownership survived');}
    floor.geometry.dispose();floor.material.dispose();light.shadow.dispose();renderer.dispose();renderer.forceContextLoss();
  }
};
