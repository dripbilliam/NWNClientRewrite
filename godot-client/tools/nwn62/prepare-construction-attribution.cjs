'use strict';
// PRIVATE attribution only. Frozen B stays untouched. No timing/client launch.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),directory=path.join(root,'.cache/nwn62/construction-attribution-b');assert(!fs.existsSync(directory));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex'),read=file=>fs.readFileSync(file),parentFile=path.join(root,'.cache/nwn62/entry-pairs/entry62-shared4-pair-b/pair.json'),parent=JSON.parse(read(parentFile));assert.equal(hash(read(parentFile)),'841fe874d8ce6a306da1a7fde4ced5f0b419384893780355d93be78fbd71ffd5');
const files=[];
function source(relative){const value=read(path.join(parent.candidate,relative)).toString('utf8');assert.equal(hash(value),parent.pins.candidate.find(pin=>pin.file===relative).sha256);return value;}
function exact(text,before,after){assert.equal(text.split(before).length-1,1,before);return text.replace(before,after);}
function write(relative,before,after){for(const [kind,value]of [['before',before],['overlay',after]]){const file=path.join(directory,kind,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,value,{flag:'wx'});}files.push({file:relative,beforeSHA256:hash(before),afterSHA256:hash(after)});}
const poolPath='systems/native_render/resource_pool.gd';let before=source(poolPath),after=before;
after=exact(after,'func construction_finished(began: int) -> void:','func construction_finished(began: int,caller: String="",model: String="",id: int=-1,phase_before: String="",phase_after: String="") -> void:');
after=exact(after,'_private_shared_audit.record("construction",elapsed,_completion_depth>0)','_private_shared_audit.record("construction",elapsed,_completion_depth>0,caller,model,id,phase_before,phase_after,publication_frame,began)');
after+=`
# PRIVATE: labels only, no clock reads and no retained builder/model owners.
static func private_pending_phase(pending: Dictionary) -> String:
\tif pending.has("template"):
\t\tvar state: Dictionary=pending.template._build_progress
\t\tvar phase:=str(state.get("phase","ready"))
\t\tif phase=="install" and is_instance_valid(state.get("source")):
\t\t\tvar install: Dictionary=state.source._installation
\t\t\tphase+="/"+str(install.get("phase","ready"))+":"+str(install.get("index",-1))
\t\treturn phase
\tif pending.has("placement_job"):return "placement"
\tif pending.has("job"):return "recipe"
\treturn "begin"
static func private_actor_phase(actor) -> String:
\tif not is_instance_valid(actor):return "begin"
\tvar state: Dictionary=actor._actor_install
\treturn str(state.get("phase","ready"))+"/model:"+str(state.get("model_index",-1))+"/index:"+str(state.get("index",-1))
static func private_plan_model(plan: Dictionary) -> String:
\tvar pieces: Array=plan.get("pieces",[])
\treturn str(pieces[0].get("name",pieces[0].get("key",""))) if not pieces.is_empty() else ""
func private_template_peak_snapshot() -> Dictionary:
\tvar top: Array=[]
\tfor key in templates:
\t\tvar template=templates[key]
\t\ttop.append({"model":str(template.source_model_name),"identity":str(key),"maximum_staged_step_us":int(template.staged_max_step_us),"staged_steps":int(template.staged_steps),"physical_parts":int(template.physical_part_count),"small_native_packed":bool(template.small_native_packed),"recipe":template.recipe!=null,"packed":template.scene!=null})
\t\ttop.sort_custom(func(a,b):return int(a.maximum_staged_step_us)>int(b.maximum_staged_step_us))
\t\tif top.size()>8:top.resize(8)
\treturn {"cached_templates":templates.size(),"top8":top,"scope":"PRIVATE final-report-only cached template census from existing always-on staged maxima; no new timers, live owners or per-frame sampling. Pending/evicted builders absent; construction boundary peak separately labels those."}
`;
assert.equal(after.split('if _completion_depth==0:elapsed=Time.get_ticks_usec()-began;publication_us+=elapsed').length-1,2);write(poolPath,before,after);
const auditPath='tools/nwn62/shared_budget_ledger_audit.gd';before=source(auditPath);after=before;
after=exact(after,'var denials: Dictionary={}','var denials: Dictionary={}\nvar maximum_construction: Dictionary={}');
after=exact(after,'func record(kind: String,elapsed: int,nested: bool)->void:','func record(kind: String,elapsed: int,nested: bool,caller: String="",model: String="",id: int=-1,phase_before: String="",phase_after: String="",frame: int=-1,began: int=0)->void:');
after=exact(after,'\tif not nested:row.timed_calls+=1;row.cpu_us+=elapsed;row.maximum_us=maxi(row.maximum_us,elapsed)','\tif not nested:row.timed_calls+=1;row.cpu_us+=elapsed;row.maximum_us=maxi(row.maximum_us,elapsed)\n\tif kind=="construction" and not nested and elapsed>5000 and elapsed>int(maximum_construction.get("elapsed_us",0)):\n\t\tmaximum_construction={"elapsed_us":elapsed,"caller":caller,"model":model,"id":id,"phase_before":phase_before,"phase_after":phase_after,"frame":frame,"began_us":began,"ended_us":began+elapsed,"scope":"One largest construction boundary above5ms, existing outer walltime only; before/after phases do not invent exact inner operation attribution"}');
after=exact(after,'"operations":operations.duplicate(true),','"operations":operations.duplicate(true),"maximum_construction":maximum_construction.duplicate(),');write(auditPath,before,after);
const objectPath='systems/native_render/object_stream.gd';before=source(objectPath);after=before;
after=exact(after,'pool.construction_finished(unit_began)\n\tif _planning_cursor','pool.construction_finished(unit_began,"objects.plan","",int(snapshot_objects[_planning_cursor-1].id),"row","row")\n\tif _planning_cursor');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\tcontinue\n\t\tif entry.get','pool.construction_finished(unit_began,"objects.stale",name,int(placement.id),"cancel","cancel")\n\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\tcontinue\n\t\tif entry.get');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\tcontinue\n\t\tif not door','pool.construction_finished(unit_began,"objects.retry",name,int(placement.id),"bound-check","request")\n\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\tcontinue\n\t\tif not door');
after=exact(after,'\t\t\t\tvar preparation: Dictionary=pool.model_template_step','\t\t\t\tvar private_template_before: String=pool.private_pending_phase(_template_pending)\n\t\t\t\tvar preparation: Dictionary=pool.model_template_step');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\t\t\telif','pool.construction_finished(unit_began,"objects.template",name,int(placement.id),private_template_before,str(preparation.get("phase","pending")))\n\t\t\t\t\telif');
after=exact(after,'\t\t\tvar creation: Dictionary=_animated_publication(entry,door)','\t\t\tvar private_animated_before: String=pool.private_actor_phase(_animated_instance)\n\t\t\tvar creation: Dictionary=_animated_publication(entry,door)');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\t\tcontinue\n\t\t\tif creation.status=="failed"','pool.construction_finished(unit_began,"objects.animated",name,int(placement.id),private_animated_before,str(creation.get("phase","pending")))\n\t\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\t\tcontinue\n\t\t\tif creation.status=="failed"');
after=exact(after,'\t\t\tvar creation: Dictionary=templates[name].create_step','\t\t\tvar private_clone_before: String=pool.private_pending_phase(_clone_pending)\n\t\t\tvar creation: Dictionary=templates[name].create_step');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\t\tcontinue\n\t\t\t_clone_entry','pool.construction_finished(unit_began,"objects.clone",name,int(placement.id),private_clone_before,str(creation.get("phase","pending")))\n\t\t\t\telif pool.has_method("publication_finished"):pool.publication_finished(unit_began)\n\t\t\t\tcontinue\n\t\t\t_clone_entry');
assert(!after.includes('pool.construction_finished(unit_began)'));write(objectPath,before,after);
const areaPath='systems/native_render/area_stream.gd';before=source(areaPath);after=before;
after=exact(after,'\t\t\t\tvar preparation: Dictionary=pool.model_template_step','\t\t\t\tvar private_template_before: String=pool.private_pending_phase(_template_pending)\n\t\t\t\tvar preparation: Dictionary=pool.model_template_step');
after=exact(after,'pool.construction_finished(tile_begin)\n\t\t\t\t\telif','pool.construction_finished(tile_begin,"terrain.template",str(row.model),int(row.index),private_template_before,str(preparation.get("phase","pending")))\n\t\t\t\t\telif');
after=exact(after,'\t\t\tvar creation: Dictionary=templates[key].create_step','\t\t\tvar private_clone_before: String=pool.private_pending_phase(_clone_pending)\n\t\t\tvar creation: Dictionary=templates[key].create_step');
after=exact(after,'pool.construction_finished(tile_begin)\n\t\t\t\telif','pool.construction_finished(tile_begin,"terrain.clone",str(row.model),int(row.index),private_clone_before,str(creation.get("phase","pending")))\n\t\t\t\telif');write(areaPath,before,after);
const creaturePath='systems/native_render/creature_stream.gd';before=source(creaturePath);after=before;
after=exact(after,'\t\tvar progress: Dictionary=actor.install_step','\t\tvar private_actor_before: String=pool.private_actor_phase(actor)\n\t\tvar progress: Dictionary=actor.install_step');
after=exact(after,'budget_owner.construction_finished(unit_began)','budget_owner.construction_finished(unit_began,"actors.abort",pool.private_plan_model(plan),int(plan.id),private_actor_before,str(progress.get("phase","aborted")))');
after=exact(after,'pool.construction_finished(unit_began)\n\t\t\telif','pool.construction_finished(unit_began,"actors.install",pool.private_plan_model(plan),int(plan.id),private_actor_before,str(progress.get("phase","pending")))\n\t\t\telif');
after=exact(after,'pool.construction_finished(unit_began)\n\tif _planning_cursor','pool.construction_finished(unit_began,"actors.plan","",int(objects[_planning_cursor-1].id),"row","row")\n\tif _planning_cursor');
after=exact(after,'pool.construction_finished(began)','pool.construction_finished(began,"actors.begin",pool.private_plan_model(plan),int(plan.id),"begin",pool.private_actor_phase(actor))');write(creaturePath,before,after);
const livePath='native_live_world.gd';before=source(livePath);after=exact(before,'\treport.render_cache_before_release=render_pool.snapshot(); render_pool.clear(); report.render_cache_after_release=render_pool.snapshot()','\treport.private_template_peaks=render_pool.private_template_peak_snapshot()\n\treport.render_cache_before_release=render_pool.snapshot(); render_pool.clear(); report.render_cache_after_release=render_pool.snapshot()');write(livePath,before,after);
const manifest={version:1,ticket:'NWN-62',scope:'PRIVATE attribution of one construction walltime peak only; existing4ms candidate policy unchanged; no new timers, default or frozenB edits',parent:{file:parentFile,sha256:hash(read(parentFile)),leg:'candidate'},directory,files,assertions:{onlyOneLargestConstructionRecord:true,thresholdUs:5000,existingLazyElapsedOnly:true,noNewClockReads:true,noPerFrameArrays:true,noLiveOwnerReferencesRetained:true,cachedTemplateTop8FinalReportOnly:true,phaseBeforeAfterNotExactInnerStageClaim:true,noTestBuildOrClientLaunch:true},limits:parent.unchangedBounds};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,manifestSHA256:hash(read(path.join(directory,'manifest.json'))),files},null,2));
