// Private diagnostic build only. No installed dependency file is changed.
// Reuse Three's exact uniform/material/binding owners while testing a smaller
// dispatch path. Missing/drifted bridge sites fail the QA build closed.
export function transformReplayThreeBridge(source){
 const site='_this.properties = properties;';if(source.split(site).length!==2||source.includes('_this.nwnDrawAPI'))throw Error('Private Three draw bridge site drift');
 const bridge=`
 _this.nwnDrawAPI={version:1,projectionVersion:1,bindingStates,attributes,textures,materials,
  upload:(seq,values)=>WebGLUniforms.upload(_gl,seq,values,textures),
  markLights:markUniformsLightsNeedsUpdate,
  renderObjects:(items,scene,camera)=>renderObjects(items,scene,camera),
  getState:()=>currentRenderState?.state,
  getHeight:()=>_height,
  dirtyMaterial:()=>{_currentMaterialId=-1;}
 };
 `;
 const project='projectObject( scene, camera, 0, _this.sortObjects );';
 if(source.split(project).length!==2)throw Error('Private Three projection bridge site drift');
 const after='if ( scene.isScene === true ) scene.onAfterRender( _this, scene, camera );';if(source.split(after).length!==2)throw Error('Private Three prepared-pass bridge site drift');
 return source.replace(site,site+bridge).replace(project,`if(_this.nwnDrawAPI.project?.(scene,camera,{list:currentRenderList,state:currentRenderState,objects,frustum:_frustum,projection:_projScreenMatrix,vector:_vector4})!==true){${project}}`).replace(after,'_this.nwnDrawAPI.afterPass?.(scene,camera);\n'+after);
}
