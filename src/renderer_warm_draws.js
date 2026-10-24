import {Material,Object3D,Vector3} from 'three';
import {isLocalRendererHook} from './renderer_local_hooks.js';
const mb=Material.prototype,ob=Object3D.prototype;
const keys=['side','vertexColors','flatShading','fog','alphaTest','alphaHash','alphaToCoverage','dithering','toneMapped','premultipliedAlpha','precision','map','alphaMap','envMap','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','onBeforeCompile','customProgramCacheKey'];

// EXPERIMENT: reuse already compiled programs and exact Three GPU owners.
// All ordinary projection, animation, geometry uploads and callbacks still run.
// No shader math changes. Unsupported/changing programs use ordinary dispatch.
export class RendererWarmDraws{
 constructor(renderer){
  this.renderer=renderer;this.enabled=false;this.cameraPosition=new Vector3();this.frame=0;this.reset();const owner=this;
  this.beforeRender=renderer.render;this.renderHook=function(scene,camera){return owner.render(scene,camera,()=>owner.beforeRender.call(this,scene,camera));};renderer.render=this.renderHook;
  this.beforeDirect=renderer.renderBufferDirect;this.directHook=function(camera,scene,geometry,material,object,group){return owner.direct(camera,scene,geometry,material,object,group);};renderer.renderBufferDirect=this.directHook;
  this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);renderer.domElement?.addEventListener('webglcontextrestored',this.lost);
 }
 reset(){this.records=new WeakMap();this.programFrames=new WeakMap();this.stats={fast:0,ordinary:0,captured:0,unsupported:0};}
 supported(scene,camera,g,m,o){
  if(!o.isMesh||o.isSkinnedMesh||o.isInstancedMesh||o.isBatchedMesh||g.isInstancedBufferGeometry||g.drawRange.count<=0||o.children.length||m.wireframe||m.clippingPlanes?.length||m.uniformsGroups?.length||!(m.isMeshLambertMaterial||m.isMeshBasicMaterial||m.isShaderMaterial&&!m.isRawShaderMaterial))return false;
  if(o.onAfterRender!==ob.onAfterRender||o.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(o.onBeforeRender)||m.onBeforeRender!==mb.onBeforeRender||m.onBeforeCompile!==mb.onBeforeCompile&&!isLocalRendererHook(m.onBeforeCompile)||m.customProgramCacheKey!==mb.customProgramCacheKey&&!isLocalRendererHook(m.customProgramCacheKey))return false;
  for(const key in g.morphAttributes)if(g.morphAttributes[key]?.length)return false;
  return !camera.isArrayCamera&&!this.renderer.xr.enabled&&!this.renderer.clippingPlanes.length&&!scene.overrideMaterial;
 }
 valid(record,scene,g,m,props,api){
  if(record.version!==m.version||record.program!==props.currentProgram||record.lightVersion!==api.getState()?.lights.state.version||record.fog!==scene.fog||record.environment!==scene.environment||record.mapping!==this.renderer.toneMapping||record.output!==this.renderer.outputColorSpace||record.shadowType!==this.renderer.shadowMap.type||record.shadows!==this.renderer.shadowMap.enabled||record.target!==this.renderer.getRenderTarget()?.texture.colorSpace||record.index!==g.index)return false;
  for(let i=0;i<keys.length;i++)if(record.values[i]!==m[keys[i]])return false;
  for(const key in g.attributes)if(!record.attributes[key])return false;
  for(const key in record.attributes){const a=g.attributes[key],r=record.attributes[key];if(!a||a!==r.attribute||a.array!==r.array||a.itemSize!==r.size||a.normalized!==r.normalized||a.gpuType!==r.gpuType||a.isInterleavedBufferAttribute)return false;}
  return true;
 }
 capture(scene,g,m,props,api){
  const program=props.currentProgram;if(!program||!props.uniformsList||!props.uniforms)return;
  let records=this.records.get(m);if(!records)this.records.set(m,records=new WeakMap());
  records.set(g,{version:m.version,program,lightVersion:api.getState()?.lights.state.version,fog:scene.fog,environment:scene.environment,mapping:this.renderer.toneMapping,output:this.renderer.outputColorSpace,shadowType:this.renderer.shadowMap.type,shadows:this.renderer.shadowMap.enabled,target:this.renderer.getRenderTarget()?.texture.colorSpace,index:g.index,values:keys.map(k=>m[k]),attributes:Object.fromEntries(Object.entries(g.attributes).map(([k,a])=>[k,{attribute:a,array:a.array,size:a.itemSize,normalized:a.normalized,gpuType:a.gpuType}]))});this.stats.captured++;
 }
 direct(camera,scene,geometry,material,object,group){
  const renderer=this.renderer,api=renderer.nwnDrawAPI;
  if(!this.active||scene!==this.active.scene||camera!==this.active.camera||api?.version!==1)return this.beforeDirect.call(renderer,camera,scene,geometry,material,object,group);
  const ordinary=()=>{this.stats.ordinary++;const answer=this.beforeDirect.call(renderer,camera,scene,geometry,material,object,group);this.programFrames=new WeakMap();if(this.supported(scene,camera,geometry,material,object))this.capture(scene,geometry,material,renderer.properties.get(material),api);return answer;};
  if(!this.supported(scene,camera,geometry,material,object)){this.stats.unsupported++;return ordinary();}
  const props=renderer.properties.get(material),record=this.records.get(material)?.get(geometry);
  if(!record||!this.valid(record,scene,geometry,material,props,api))return ordinary();
  const gl=renderer.getContext(),program=record.program,uniforms=program.getUniforms(),state=renderer.state;
  api.textures.resetTextureUnits();state.useProgram(program.program);
  const first=this.programFrames.get(program)!==this.frame;
  if(first){uniforms.setValue(gl,'projectionMatrix',camera.projectionMatrix);uniforms.setValue(gl,'viewMatrix',camera.matrixWorldInverse);uniforms.setValue(gl,'cameraPosition',this.cameraPosition.setFromMatrixPosition(camera.matrixWorld));uniforms.setValue(gl,'isOrthographic',camera.isOrthographicCamera===true);if(renderer.capabilities.logarithmicDepthBuffer)uniforms.setValue(gl,'logDepthBufFC',2/(Math.log(camera.far+1)/Math.LN2));}
  uniforms.setValue(gl,'receiveShadow',object.receiveShadow);uniforms.setValue(gl,'toneMappingExposure',renderer.toneMappingExposure);
  if(props.needsLights)api.markLights(props.uniforms,first);
  if(scene.fog&&material.fog)api.materials.refreshFogUniforms(props.uniforms,scene.fog);
  api.materials.refreshMaterialUniforms(props.uniforms,material,renderer.getPixelRatio(),api.getHeight(),api.getState()?.transmissionRenderTarget?.[camera.id]);
  api.upload(props.uniformsList,props.uniforms);material.uniformsNeedUpdate=false;
  uniforms.setValue(gl,'modelViewMatrix',object.modelViewMatrix);uniforms.setValue(gl,'normalMatrix',object.normalMatrix);uniforms.setValue(gl,'modelMatrix',object.matrixWorld);
  state.setMaterial(material,object.matrixWorld.determinant()<0);
  const index=geometry.index,position=geometry.attributes.position,range=geometry.drawRange;let start=range.start,end=range.start+range.count;
  if(group!==null){start=Math.max(start,group.start);end=Math.min(end,group.start+group.count);}start=Math.max(start,0);if(index)end=Math.min(end,index.count);else if(position)end=Math.min(end,position.count);const count=end-start;
  if(count>=0&&Number.isFinite(count)){api.bindingStates.setup(object,material,program,geometry,index);if(index){const attribute=api.attributes.get(index);gl.drawElements(gl.TRIANGLES,count,attribute.type,start*attribute.bytesPerElement);}else gl.drawArrays(gl.TRIANGLES,start,count);renderer.info.update(count,gl.TRIANGLES,1);}
  api.dirtyMaterial();this.programFrames.set(program,this.frame);this.stats.fast++;
 }
 render(scene,camera,draw){
  if(!this.enabled)return draw();if(this.active){this.reset();return draw();}const previous=this.active;this.active={scene,camera};this.frame++;this.stats={fast:0,ordinary:0,captured:0,unsupported:0};
  try{return draw();}finally{this.active=previous;}
 }
 snapshot(){return{...this.stats,enabled:this.enabled,bridge:this.renderer.nwnDrawAPI?.version??null};}
 dispose(){const r=this.renderer;if(r.render===this.renderHook)r.render=this.beforeRender;if(r.renderBufferDirect===this.directHook)r.renderBufferDirect=this.beforeDirect;r.domElement?.removeEventListener('webglcontextlost',this.lost);r.domElement?.removeEventListener('webglcontextrestored',this.lost);this.enabled=false;this.reset();}
}
