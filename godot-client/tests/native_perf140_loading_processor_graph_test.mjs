// Source analysis correctness gate. This does not run Godot, mount a catalog,
// read a native DLL, change game/cache source, or produce reusable cache keys.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildGraph,collectGlobalClasses,digest,lex,imports,DRIVER,FINISHED,REJECTIONS} from '../tools/perf140/loading/processor-graph.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/renderer');
const label=process.argv[2];
if(!/^processor-graph-gate-[a-z0-9-]+$/.test(label??''))throw Error('Fresh owned processor graph gate label required');
const target=path.join(project,'.cache/native-140fps/loading-agent',label);
if(fs.existsSync(target))throw Error('Existing evidence is immutable');
fs.mkdirSync(target);
let checks=0;
const failures=[];
function check(condition,description){checks++;if(!condition)failures.push(description);}
const original=new Map();
function read(relative){if(!original.has(relative)){const file=path.join(source,relative);original.set(relative,fs.existsSync(file)?fs.readFileSync(file):null);}return original.get(relative);}
function withMutation(relative,change){return name=>name===relative?Buffer.from(change(read(name)?.toString()??'')):read(name);}
function signature(graph){return digest(JSON.stringify({kind:graph.kind,files:graph.files.map(v=>[v.path,v.mode,v.sha256,v.imports,v.functions]),nativeLibraries:graph.nativeLibraries}));}
const kinds=['static-model','actor-model','gui-icon-v1','finished-icon-v1','rejection:static-model','rejection:actor-model','rejection:gui-icon-v1'];
const graphs=new Map(kinds.map(kind=>[kind,buildGraph(kind,read)]));
for(const [kind,graph] of graphs){
 check(graph.ready,kind+' resolves current source');
 check(graph.nativeLibraries.includes('.cache/native-kernel/nwn-particle-kernel.dll'),kind+' retains actual kernel dependency');
 check(graph.nativeLibraries.includes('.cache/native-resource-index/nwn-resource-index.dll'),kind+' retains actual resource index dependency');
 check(graph.files.some(v=>v.path==='systems/native_render/particle_math.gd'),kind+' retains real particle math preparation dependency');
 check(signature(graph)===signature(buildGraph(kind,read)),kind+' source plan is deterministic');
}
for(const kind of ['static-model','actor-model','gui-icon-v1']){
 const paths=graphs.get(kind).files.map(v=>v.path);
 check(paths.filter(v=>v.startsWith('systems/native_render/')).join(',')==='systems/native_render/particle_math.gd',kind+' does not depend on runtime world materials/instances');
 check(!paths.includes('systems/model_rigs.gd'),kind+' rig bundle does not import live rig owner');
 check(!paths.includes(FINISHED)&&!paths.includes(REJECTIONS),kind+' separates pixel/rejection owners');
}
const pixelPaths=graphs.get('finished-icon-v1').files.map(v=>v.path);
for(const required of [FINISHED,'systems/native_render/native_model_material.gd','systems/native_render/gui_sampler.gd','systems/model_rigs.gd'])check(pixelPaths.includes(required),'finished pixels include '+required);
for(const kind of kinds){
 const graph=graphs.get(kind),model=kind!=='finished-icon-v1'&&!kind.startsWith('rejection:');
 for(const unrelated of ['native_live_world.gd','systems/native_render/frame_summary_job.gd','tools/perf140/shadows/static_shadow_proxy.gd']){
  const changed=buildGraph(kind,withMutation(unrelated,text=>text+'\n# unrelated source mutation\n'));
  const included=graph.files.some(v=>v.path===unrelated);
  check((signature(changed)!==signature(graph))===included,kind+' changes only if actual graph contains '+unrelated);
 }
 for(const related of [DRIVER,'systems/native_data/actor_model.gd','systems/native_data/mesh_preparation.gd','systems/native_render/particle_math.gd','systems/native_data/prepared_cache.gd']){
  const changed=buildGraph(kind,withMutation(related,text=>text+'\n# relevant implementation mutation\n'));
  check(changed.ready&&signature(changed)!==signature(graph),kind+' relevant source change invalidates plan: '+related);
 }
 const material=buildGraph(kind,withMutation('systems/native_render/native_model_material.gd',text=>text+'\n# material mutation\n'));
 check((signature(material)!==signature(graph))===(!model&&!kind.startsWith('rejection:')),kind+' material scope matches pixel ownership');
 const rejection=buildGraph(kind,withMutation(REJECTIONS,text=>text+'\n# deterministic error policy mutation\n'));
 check((signature(rejection)!==signature(graph))===kind.startsWith('rejection:'),kind+' rejection policy stays in its own artifact graph');
 const missing=buildGraph(kind,name=>name==='systems/native_render/particle_math.gd'?null:read(name));
 check(!missing.ready&&missing.issues.some(v=>v.reason==='missing-source'),kind+' missing true preparation dependency fails closed');
 const injected=buildGraph(kind,withMutation('systems/native_data/actor_model.gd',text=>text+'\nconst Injected = preload("res://systems/missing_graph_fixture.gd")\n'));
 check(!injected.ready&&injected.issues.some(v=>v.reason==='missing-source'),kind+' introduced missing dependency fails closed');
 const dynamic=buildGraph(kind,withMutation('systems/native_data/actor_model.gd',text=>text+'\nfunc dynamic_dependency(name):\n\treturn ResourceLoader.load(name)\n'));
 check(!dynamic.ready&&dynamic.issues.some(v=>v.reason==='nonliteral-resource-load'),kind+' dynamic qualified load fails closed');
 const directClass=buildGraph(kind,withMutation('systems/native_data/actor_model.gd',text=>text+'\nfunc unknown_native():\n\treturn NwnUnregisteredFixture.new()\n'));
 check(!directClass.ready&&directClass.issues.some(v=>v.reason==='unmapped-native-class'),kind+' direct unknown native class fails closed');
 const dynamicClass=buildGraph(kind,withMutation('systems/native_data/actor_model.gd',text=>text+'\nfunc dynamic_native(name):\n\treturn ClassDB.instantiate(name)\n'));
 check(!dynamicClass.ready&&dynamicClass.issues.some(v=>v.reason==='nonliteral-native-class'),kind+' dynamic native construction fails closed');
 const unknownBase=buildGraph(kind,withMutation('systems/native_data/actor_model.gd',text=>text.replace('extends RefCounted','extends UnknownGlobalFixture')));
 check(!unknownBase.ready&&unknownBase.issues.some(v=>v.reason==='unresolved-script-base'),kind+' untracked global script base fails closed');
 const resourcePath='systems/unsupported_graph_fixture.tres';
 const unsupportedRead=withMutation('systems/native_data/actor_model.gd',text=>text+'\nconst NewKind=preload("res://'+resourcePath+'")\n');
 const unsupported=buildGraph(kind,name=>name===resourcePath?Buffer.from('[gd_resource]'):unsupportedRead(name));
 check(!unsupported.ready&&unsupported.issues.some(v=>v.reason==='unsupported-resource-kind'),kind+' unsupported transitive resource format fails closed');
}
const lexical=lex('# preload("res://false.gd")\nconst text="load(ghost)"\nconst valid=preload("res://true.gd")\n');
check(!lexical.code.includes('ghost')&&!lexical.code.includes('false.gd'),'comments/string contents never become function dependency identifiers');
const literal=imports('const valid=ResourceLoader.load("res://true.gd")\nconst other=preload("res://other.gd")\n','fixture');
check(literal.issues.length===0&&literal.rows.map(v=>v.path).join(',')==='true.gd,other.gd','literal qualified and ordinary loads are tracked');
const inlineBase=imports('class_name InlineFixture extends "res://systems/base_fixture.gd"\n','fixture');
check(inlineBase.issues.length===0&&inlineBase.rows.some(v=>v.path==='systems/base_fixture.gd'),'inline class_name inheritance tracks its literal base resource');
const nestedBase=imports('extends RefCounted\nclass Inner extends "res://systems/inner_base.gd":\n\tpass\n','fixture');
check(nestedBase.issues.length===0&&nestedBase.rows.some(v=>v.path==='systems/inner_base.gd'),'nested class inheritance tracks its literal base resource');
const globalPath='systems/global_graph_fixture.gd',globalBytes=Buffer.from('extends RefCounted\nclass_name GlobalGraphFixture\n');
const globals=collectGlobalClasses([[globalPath,globalBytes],['unrelated.gd',Buffer.from('# class_name FalseGlobal\n')]]);
check(globals.get('GlobalGraphFixture')===globalPath&&!globals.has('FalseGlobal'),'global script class index excludes comments');
const globalRoot=withMutation('systems/native_data/actor_model.gd',text=>text+'\nfunc global_dependency():\n\treturn GlobalGraphFixture.new()\n');
const globalGraph=buildGraph('actor-model',name=>name===globalPath?globalBytes:globalRoot(name),{globalClasses:globals});
check(globalGraph.ready&&globalGraph.files.some(v=>v.path===globalPath),'global class-name use creates an explicit source dependency');
const globalBaseRoot=withMutation('systems/native_data/actor_model.gd',text=>text.replace('extends RefCounted','extends GlobalGraphFixture'));
const globalBaseGraph=buildGraph('actor-model',name=>name===globalPath?globalBytes:globalBaseRoot(name),{globalClasses:globals});
check(globalBaseGraph.ready&&globalBaseGraph.files.some(v=>v.path===globalPath),'indexed global script base creates an explicit source dependency');
let duplicateRejected=false;try{collectGlobalClasses([[globalPath,globalBytes],['second.gd',globalBytes]]);}catch{duplicateRejected=true;}
check(duplicateRejected,'ambiguous global class ownership fails closed');
const report={version:1,checks,failures,passed:!failures.length,scope:'Source-only dependency analysis, not runtime/cache/performance validation',source,testSha256:digest(fs.readFileSync(fileURLToPath(import.meta.url))),graphModuleSha256:digest(fs.readFileSync(path.join(project,'tools/perf140/loading/processor-graph.mjs'))),graphs:[...graphs.values()].map(v=>({kind:v.kind,files:v.files.length,nativeLibraries:v.nativeLibraries,ready:v.ready})),nativeBytesRead:0,engineProcessesStarted:0,sharedFilesChanged:0,builds:0};
fs.writeFileSync(path.join(target,'receipt.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({target,checks,passed:report.passed,failures}));
if(failures.length)process.exitCode=1;
