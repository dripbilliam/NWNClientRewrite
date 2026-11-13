function verifyAcceptedBundleUse(renderCore,actual,{requireBusyUse=true}={}){
 const errors=[],features={};
 if(!renderCore||!actual)return {status:'rejected',errors:['Accepted normal bundle evidence is missing'],features};
 if(JSON.stringify(actual.flags)!==JSON.stringify(renderCore.flags))errors.push('Actual normal bundle flags differ');
 if(!renderCore.enabled)return {status:errors.length?'rejected':'observed',errors,features,scope:'Conservative bundle disabled; no optimized work is inferred'};
 if(actual.diagnostics?.profiling!==false||actual.diagnostics?.pacing?.enabled!==false||actual.particle_setup?.enabled!==false||actual.particle_setup?.coarse_phases!==false||actual.particle_setup?.scheduled_clock_pairs!==0)errors.push('Normal bundle diagnostic timers must remain OFF');
 const flags=renderCore.flags,engine=actual.engine_features??{},light=actual.light_inputs??{},boundary=actual.particle_boundary?.boundary??actual.particle_boundary,setup=actual.particle_setup??{},hot=actual.hot_parameters?.owners??[];
 const requireUse=(flag,name,value)=>{if(flags.includes(flag)){features[name]=value===true;if(requireBusyUse&&value!==true)errors.push('Actual accepted normal feature work was not observed: '+name);}};
 requireUse('--particle-scene-boundary=native','sceneBoundary',boundary?.eligibility_reads>0);
 requireUse('--particle-scene-direct=pod','directScene',boundary?.direct_enabled===true&&boundary?.direct_eligibility_calls>0&&boundary?.direct_pose_reads>0);
 requireUse('--particle-setup-boundary=bound','setupBoundary',setup.setup_boundary===true&&setup.animating_key_binds>0&&setup.static_noncallable_uses+setup.static_null_callable_uses>0);
 requireUse('--particle-hot-parameters=bound','hotFields',hot.some(owner=>owner.enabled===true&&(owner.fields??[]).some(field=>field.reads>0&&field.hits>0)));
 const visibility=engine.visibility_chain_cache;
 requireUse('--visibility-chain-cache=epochs','visibilityCache',visibility?.enabled===true&&visibility?.disabled===false&&visibility?.queries>10000&&visibility?.hits+visibility?.ancestor_hits>10000);
 requireUse('--light-input-read=typed','typedLight',light.plain_claims>0&&light.plain_rows>0&&light.plain_field_reads>0);
 requireUse('--light-input-proof=segments','segmentedLight',light.plain_segment_proofs>0&&light.plain_segment_reuses>0);
 requireUse('--light-pair-layer-repair=exact','layerRepairPrerequisite',flags.includes('--light-pair-filter=consumers')&&engine.light_filter_passes>0);
 requireUse('--light-pair-filter=consumers','lightFilter',engine.light_excluded>0&&engine.light_filter_passes>0);
 requireUse('--pair-record-reuse=exact','pairReuse',engine.pair_reused>0&&engine.pair_reuse_passes>0);
 requireUse('--rig-skin-publisher=native','rigSkin',(actual.skin_owners??[]).some(owner=>owner.totals?.completed>0));
 requireUse('--skeleton-force-pass=once','skeletonForce',engine.skeleton_force_once?.stable_calls>0&&engine.skeleton_force_once?.avoided_offsets>0);
 return {status:errors.length?'rejected':'observed',errors,features,requireBusyUse,scope:requireBusyUse?'Final heavy-world acceptance; every selected route needs observed work':'Capabilities and selected modes only; zero work in an empty/unsupported cohort is not an admission failure'};
}
