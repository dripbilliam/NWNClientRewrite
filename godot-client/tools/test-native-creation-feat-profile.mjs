import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique profile evidence label');
const directory=path.join(project,'.cache/creation-feat-profile',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:sha(bytes)});
 if(file.endsWith('.gd')){for(const m of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));for(const m of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));}
}
for(const relative of ['tests/native_creation_feat_profile_test.gd','tests/native_profiled_creation.gd','tests/native_profiled_feats_chooser.gd','tests/native_profiled_feat_snapshot.gd','systems/native_data/feedback_descriptors.json'])include(path.join(project,relative));include(fileURLToPath(import.meta.url));
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(sha(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copy');}
const copiedProject=path.join(copy,'godot-client'),patches=[];
function copiedTransform(file,change){
 const target=path.join(copiedProject,file),source=fs.readFileSync(target,'utf8'),result=change(source);
 fs.writeFileSync(target,result);patches.push({file,kind:'clock-only function wrapper',beforeSha256:sha(Buffer.from(source)),afterSha256:sha(Buffer.from(result))});
}
function clockWrap(source,name,args,pass,result,label){
 const before='static func '+name+'(';if(source.split(before).length!==2)throw Error('One static method required: '+name);
 source=source.replace(before,'static func _profile_native_'+name+'(');
 return source+'\nstatic func '+name+'('+args+') -> '+result+':\n\tvar token:=ProfileClock.enter("'+label+'")\n\tvar value: '+result+'=_profile_native_'+name+'('+pass+')\n\tProfileClock.leave(token)\n\treturn value\n';
}
copiedTransform('systems/native_data/creation_feat_choice_rules.gd',s=>{
 s+='\nconst ProfileClock=preload("res://tests/native_creation_feat_profile_clock.gd")\n';
 s=clockWrap(s,'flags','source: Dictionary,id: int','source,id','Dictionary','choice.flags');
 return clockWrap(s,'evaluate','source: Dictionary','source','Dictionary','choice.evaluate');
});
copiedTransform('systems/native_data/creation_feat_requirements.gd',s=>{
 s+='\nconst ProfileClock=preload("res://tests/native_creation_feat_profile_clock.gd")\n';
 const indexed='\tif source.get(Context.KEY) is Dictionary:granted=',begin=s.includes(indexed)?indexed:'\tfor entry in cls.get("feats",[]):',end='\tif granted!=255 and granted>class_level:';
 if(s.split(begin).length!==2||s.split(end).length!==2)throw Error('One complete original/indexed prerequisite class lookup required');
 s=s.replace(begin,'\tvar class_lookup_token:=ProfileClock.enter("requirements.class_record")\n'+begin).replace(end,'\tProfileClock.leave(class_lookup_token)\n'+end);
 s=clockWrap(s,'owns','ids: Array,id: int','ids,id','bool','requirements.owns');
 s=clockWrap(s,'usable','source: Dictionary,id: int','source,id','bool','requirements.usable');
 return clockWrap(s,'evaluate','source: Dictionary,feat: Dictionary','source,feat','Dictionary','requirements.evaluate');
});
if(fs.existsSync(path.join(copiedProject,'systems/native_data/creation_feat_context.gd'))){
 copiedTransform('systems/native_data/creation_feat_context.gd',s=>{
  s+='\nconst ProfileClock=preload("res://tests/native_creation_feat_profile_clock.gd")\n';
  return clockWrap(s,'prepare','source: Dictionary','source','Dictionary','context.prepare');
 });
}
for(const [file,before,after]of [
 ['systems/native_gameplay_ui.gd','preload("res://systems/native_creation.gd")','preload("res://tests/native_profiled_creation.gd")'],
 ['systems/native_creation_frontend.gd','preload("res://systems/native_feats_chooser.gd")','preload("res://tests/native_profiled_feats_chooser.gd")'],
 ['systems/native_data/creation_feat_state.gd','preload("res://systems/native_data/creation_feat_snapshot.gd")','preload("res://tests/native_profiled_feat_snapshot.gd")']]){
 const target=path.join(copiedProject,file),source=fs.readFileSync(target,'utf8');if(source.split(before).length!==2)throw Error('Clock-only copied target must occur exactly once: '+file);
 const result=source.replace(before,after);fs.writeFileSync(target,result);patches.push({file,before,after,beforeSha256:sha(Buffer.from(source)),afterSha256:sha(Buffer.from(result))});
}
const sourceReport=path.join(project,'reports/native-creation-full-local-v3.json'),sourceBytes=fs.readFileSync(sourceReport),source=JSON.parse(sourceBytes);
if(source.creationProof?.success!==true||source.creationProof.checks!==91||source.creationTailExportProof?.success!==true)throw Error('Actual source91/export evidence unavailable');
const e=source.creationProof.expected,signature=e.sourceTailAppearance?.signature;
const recipe={sourceControls:91,classId:e.classId,race:e.race,abilities:e.abilities,skills:e.skills,packageId:Array.isArray(signature)&&signature.length===6?signature[5]:Number(source.creationProof.context.classRow.Package),feats:e.feats,classRow:source.creationProof.context.classRow};
const recipePath=path.join(directory,'detached-class-recipe.json');fs.writeFileSync(recipePath,JSON.stringify(recipe,null,2)+'\n');
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Creation Feat Phase Diagnostic"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=sha(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected Godot runtime');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');const child=spawnSync(godot,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_creation_feat_profile_test.gd','--','--report='+report,'--recipe='+recipePath,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall'),'--entity-api-rest=false'],{windowsHide:true,timeout:65000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
const changed=[...inputs].filter(([file,row])=>sha(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);if(sha(fs.readFileSync(sourceReport))!==sha(sourceBytes))changed.push(path.relative(workspace,sourceReport));
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length,checks:result?.checks??0,failures:result?.failures??[],counts:result?.counts??{},observations:result?.observations??[],directory,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,copiedClockOnlyRewrites:patches,sourceRecipe:{path:path.relative(workspace,sourceReport).replaceAll('\\','/'),sha256:sha(sourceBytes),detachedSha256:sha(fs.readFileSync(recipePath))},engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,responsivenessAccepted:false,scope:result?.scope??'No functional diagnostic result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,copiedClockOnlyRewrites:patches.length}));process.exitCode=proof.success?0:1;
