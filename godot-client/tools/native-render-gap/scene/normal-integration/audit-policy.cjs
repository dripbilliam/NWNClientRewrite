'use strict';
function normalPolicyChecks(selection,native){
 const requested=selection.featureSelection,world=native?.world;
 const rendering=native?.runtime_features?.rendering,actual=rendering?.render_thread;
 const expectedSeparate=selection.renderThread==='separate';
 // Frozen normal baseline has no project/engine override: Godot's Safe default
 // must be confirmed by the supported render-thread callback, not inferred from
 // the absence of a request. Candidate must independently prove separate IDs.
 const thread=actual?.observed===true&&Number.isSafeInteger(actual.thread_id)&&Number.isSafeInteger(actual.main_thread_id)&&typeof actual.separate==='boolean'&&actual.separate===(actual.thread_id!==actual.main_thread_id)&&actual.separate===expectedSeparate&&rendering.render_thread_requirement===(selection.renderThread==='default'?'not-requested':'matched');
 return {owners:world?.drive_collision_configuration?.effective===requested['drive-collision'].value&&world?.focus_lighting?.light_input_registry?.effective===requested['light-input-registry'].value,thread};
}
module.exports={normalPolicyChecks};
