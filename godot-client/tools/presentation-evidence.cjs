const {controlledAnimationComplete}=require('./creation-evidence.cjs');
function presentationAnimationComplete(p,load){
 if(p?.animation?.changed_local_parts>0&&p.animation.maximum_local_skin_vertex_delta>0.0001)return true;
 // Rigid body-part models have no GPU skin vertices to sample. Require the
 // imported scene inventory AND controlled-actor clocks/parts/locomotion.
 return Boolean(load?.rigs?.skin_meshes===0&&load.rigs.rigid_meshes>0&&Array.isArray(load.rigs.failures)&&load.rigs.failures.length===0&&p?.animation?.skin_meshes_sampled===0&&controlledAnimationComplete(p)&&p.controlledAnimation.skin_meshes_sampled===0);
}
module.exports={presentationAnimationComplete};
