import {Box3,BoxGeometry,DoubleSide,Frustum,LessEqualDepth,LessDepth,Matrix4,Mesh,MeshBasicMaterial,Vector3} from 'three';

export async function measureReplayGPU({renderer,draw,requestFrame=callback=>requestAnimationFrame(callback),now=()=>performance.now(),deadlineMs=5000}){
 const gl=renderer.getContext(),extension=gl.getExtension('EXT_disjoint_timer_query_webgl2');if(!extension)return{available:false,scope:'GPU timer unavailable'};if(gl.getError()!==gl.NO_ERROR)throw Error('GPU timing needs a clean context');const query=gl.createQuery();if(!query)throw Error('GPU timer allocation failed');
 try{const start=now();gl.beginQuery(extension.TIME_ELAPSED_EXT,query);try{draw();}finally{gl.endQuery(extension.TIME_ELAPSED_EXT);}const cpuSubmitMs=now()-start,until=now()+deadlineMs;while(!gl.getQueryParameter(query,gl.QUERY_RESULT_AVAILABLE)){if(now()>until)throw Error('GPU timer deadline');await new Promise(requestFrame);}const disjoint=gl.getParameter(extension.GPU_DISJOINT_EXT),gpuDrawMs=disjoint?null:gl.getQueryParameter(query,gl.QUERY_RESULT)/1e6;if(gl.getError()!==gl.NO_ERROR)throw Error('GPU timer WebGL error');return{available:true,scope:'One cached frozen draw including shadows; excludes simulation and is sampled outside measured phase endpoints',gpuDrawMs,disjoint,cpuSubmitMs};}finally{gl.deleteQuery(query);}
}

// Offline diagnostic only. Query conservative object boxes against the complete
// CURRENT frame's depth. Nothing is hidden and no result survives into gameplay.
// This estimates room-specific headroom; it is not a temporal culling algorithm.
export async function auditReplayOcclusion({renderer,scene,camera,bindings,draw,requestFrame=callback=>requestAnimationFrame(callback),now=()=>performance.now(),deadlineMs=5000}){
 const gl=renderer.getContext();if(!gl.createQuery||renderer.getRenderTarget()!==null||gl.getError()!==gl.NO_ERROR)throw Error('Occlusion audit needs a clean WebGL2 default framebuffer');
 const geometry=new BoxGeometry(),material=new MeshBasicMaterial({colorWrite:false,depthWrite:false,depthTest:true,depthFunc:LessEqualDepth,side:DoubleSide,fog:false}),proxy=new Mesh(geometry,material),box=new Box3(),part=new Box3(),center=new Vector3(),size=new Vector3(),eye=new Vector3(),corner=new Vector3(),frustum=new Frustum().setFromProjectionMatrix(new Matrix4().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse)),rows=[],queries=[],timerExtension=gl.getExtension('EXT_disjoint_timer_query_webgl2'),gpuTimer=timerExtension?gl.createQuery():null;
 if(gpuTimer)queries.push(gpuTimer);
 camera.getWorldPosition(eye);let eligible=0,outside=0,near=0,unsupported=0,sourceMeshes=0;
 try{
  const submit=()=>{for(const [id,binding]of bindings){
   box.makeEmpty();let meshes=0,valid=true;
   binding.wrapper.traverseVisible(mesh=>{
    if(!mesh.isMesh||mesh.userData.mdlEmitter||!mesh.layers.test(camera.layers))return;
    const materials=Array.isArray(mesh.material)?mesh.material:[mesh.material];if(!materials.some(m=>m.visible))return;
    if(materials.some(m=>m.visible&&(!m.depthTest||![LessEqualDepth,LessDepth].includes(m.depthFunc)||m.polygonOffset))||!mesh.geometry?.attributes.position?.array||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.isBatchedMesh){valid=false;return;}
    mesh.geometry.computeBoundingBox();part.copy(mesh.geometry.boundingBox).applyMatrix4(mesh.matrixWorld);if(![...part.min,...part.max].every(Number.isFinite)){valid=false;return;}box.union(part);meshes++;
   });
   if(!valid||box.isEmpty()||!meshes){unsupported++;continue;}sourceMeshes+=meshes;
   // Padding makes the tested volume larger, retaining conservative positives.
   box.getSize(size);box.expandByScalar(Math.max(size.x,size.y,size.z)*.0001+.0001);
   if(!frustum.intersectsBox(box)){outside++;continue;}
   let crossesNear=box.containsPoint(eye);for(let mask=0;mask<8;mask++){corner.set(mask&1?box.max.x:box.min.x,mask&2?box.max.y:box.min.y,mask&4?box.max.z:box.min.z).applyMatrix4(camera.matrixWorldInverse);if(corner.z>=-camera.near)crossesNear=true;}
   if(crossesNear){near++;continue;}
   box.getCenter(center);box.getSize(size);proxy.matrixWorld.compose(center,proxy.quaternion,size);proxy.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse,proxy.matrixWorld);proxy.normalMatrix.getNormalMatrix(proxy.modelViewMatrix);
   const query=gl.createQuery();if(!query)throw Error('Occlusion query allocation failed');queries.push(query);eligible++;
   gl.beginQuery(gl.ANY_SAMPLES_PASSED_CONSERVATIVE,query);try{renderer.renderBufferDirect(camera,scene,geometry,material,proxy,null);}finally{gl.endQuery(gl.ANY_SAMPLES_PASSED_CONSERVATIVE);}
   rows.push({id,meshes,query});
  }};
  // Direct draws need Three's current render state. Submit from after-render,
  // before that state is popped, then immediately restore the callback. This
  // diagnostic callback makes ordinary submission adapters use their fallback.
  const beforeAfter=scene.onAfterRender;let submitted=false,timed=false;
  scene.onAfterRender=function(...args){beforeAfter.apply(this,args);if(submitted)return;submitted=true;if(timed){gl.endQuery(timerExtension.TIME_ELAPSED_EXT);timed=false;}submit();};
  try{if(gpuTimer){gl.beginQuery(timerExtension.TIME_ELAPSED_EXT,gpuTimer);timed=true;}draw();if(!submitted)throw Error('Occlusion after-render hook was not reached');}
  finally{scene.onAfterRender=beforeAfter;if(timed)gl.endQuery(timerExtension.TIME_ELAPSED_EXT);}
  const until=now()+deadlineMs;while(queries.some(query=>!gl.getQueryParameter(query,gl.QUERY_RESULT_AVAILABLE))){if(now()>until)throw Error('Occlusion query deadline');await new Promise(requestFrame);}
  const objects=rows.map(({id,meshes,query})=>({id,meshes,samplesPassed:Boolean(gl.getQueryParameter(query,gl.QUERY_RESULT))}));if(gl.getError()!==gl.NO_ERROR)throw Error('Occlusion audit WebGL error');
  const gpuDisjoint=gpuTimer?gl.getParameter(timerExtension.GPU_DISJOINT_EXT):null,gpuDrawMs=gpuTimer&&!gpuDisjoint?gl.getQueryParameter(gpuTimer,gl.QUERY_RESULT)/1e6:null;
  return{scope:'Single current-frame conservative bounding-box queries against complete scene depth; no visibility changes or FPS claim. Temporal validity and moving/transparent occluders remain unresolved.',gpuTimingScope:'One cached ordinary fallback render under an after-render diagnostic callback, including shadows; excludes simulation/queries and is not an average FPS measurement',gpuDrawMs,gpuDisjoint,eligible,outside,near,unsupported,sourceMeshes,hiddenObjects:objects.filter(o=>!o.samplesPassed).length,hiddenMeshes:objects.filter(o=>!o.samplesPassed).reduce((n,o)=>n+o.meshes,0),objects};
 }finally{for(const query of queries)gl.deleteQuery(query);geometry.dispose();material.dispose();renderer.resetState();}
}
