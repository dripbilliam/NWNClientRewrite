import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),base=path.join(project,'.cache/native-140fps/render-agent');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=f=>hash(fs.readFileSync(f));
const freezeLabel='pushed-source-guard-v5',freezeDirectory=path.join(base,freezeLabel),freezeFile=path.join(freezeDirectory,'manifest.json');
const parentFolder=path.join(base,'engine-pushed-fields-v4'),parentFile=path.join(parentFolder,'manifest.json'),parent=JSON.parse(fs.readFileSync(parentFile));
const parentDescriptorFile=path.join(parentFolder,'engine-descriptor.json'),descriptor=JSON.parse(fs.readFileSync(parentDescriptorFile));
if(!process.argv.includes('--stage-engine')){
 if(fs.existsSync(freezeDirectory))throw Error('Retain earlier source freeze');
 fs.mkdirSync(freezeDirectory,{recursive:true});const module=path.join(freezeDirectory,'engine_module/nwn_light_input_registry'),pins=[];fs.mkdirSync(module,{recursive:true});
 const cpp='light_input_registry.cpp',before=fs.readFileSync(path.join(parent.moduleDirectory,cpp),'utf8');
 const anchor='namespace {\n',old='entry.writer->get_source_code()!=entry.writer_source';
 if(before.split(anchor).length!==2||before.split(old).length!==2)throw Error('Exact V4 guard anchor changed');
 const helper='// Exact public COW storage identity, retaining original value fallback.\n// Entry owns the verified source buffer; changed source cannot reuse it.\nbool same_verified_source(const String &current,const String &verified) {\n return current.length()==verified.length()&&(current.ptr()==verified.ptr()||current==verified);\n}\n';
 const after=before.replace(anchor,anchor+helper).replace(old,'!same_verified_source(entry.writer->get_source_code(),entry.writer_source)');
 for(const pin of parent.modulePins){const bytes=fs.readFileSync(path.join(parent.moduleDirectory,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen V4 module drift');const result=pin.relative===cpp?Buffer.from(after):bytes;fs.writeFileSync(path.join(module,pin.relative),result,{flag:'wx'});pins.push({relative:pin.relative,sha256:hash(result)});}
 fs.writeFileSync(path.join(freezeDirectory,'light_input_registry.cpp.before'),before,{flag:'wx'});
 const fixtureBeforeFile=path.join(project,'tests/native_perf140_render_pushed_fields_v4_test.gd'),fixtureBefore=fs.readFileSync(fixtureBeforeFile,'utf8');
 const equalBefore='changed_script.source_code=(same_source+"x").left(same_source.length())';
 const equalAfter='changed_script.source_code=same_source+"\\n# transient unequal source, no poll before restoration\\n"\n\tchanged_script.source_code=(same_source+"x").left(same_source.length())';
 const mutationAnchor='\tdispose(changed);changed_script=null';
 if(fixtureBefore.split(equalBefore).length!==2||fixtureBefore.split(mutationAnchor).length!==2)throw Error('Exact source oracle anchor changed');
 const extra='\t# Force real COW replacements: set_source_code intentionally ignores equal\n\t# values. No reload means the actual canonical instance stays alive.\n\tvar variants:Array=["X"+same_source.substr(1),same_source.left(same_source.length()-1)+"X",same_source.left(same_source.length()-1),same_source+"\\n# longer source\\n",""]\n\tfor value in variants:\n\t\tchanged_script.source_code=same_source\n\t\tcheck(claim(changed,changed_script).accepted,"Actual source writer reclaims before a new source mutation")\n\t\tpoll(changed)\n\t\tvar revocations_before:int=stats(changed).script_revocations\n\t\tchanged_script.source_code=value\n\t\tpoll(changed)\n\t\tcheck(int(stats(changed).cached_members)==0 and int(stats(changed).script_revocations)==revocations_before+1,"Changed first/last/short/long/empty source revokes exactly once")\n'+mutationAnchor;
 const fixture=fixtureBefore.replace(equalBefore,equalAfter).replace(mutationAnchor,extra),fixtureRelative='tests/native_perf140_render_pushed_fields_v5_test.gd',fixtureFile=path.join(freezeDirectory,'native_perf140_render_pushed_fields_v5_test.gd');
 fs.writeFileSync(fixtureFile,fixture,{flag:'wx'});
 const closeFile=path.join(base,'pushed-fields-close-check-v2/corrected-adapter.gd'),closeManifest=JSON.parse(fs.readFileSync(path.join(base,'pushed-fields-close-check-v2/manifest.json')));
 if(fileHash(closeFile)!==closeManifest.correctedAdapterSha256)throw Error('Frozen close successor drift');
 const closeFixture=path.join(project,'tests/native_perf140_render_pushed_fields_close_test.gd');
 const manifest={version:1,module,pins,parentEngineDescriptor:parentDescriptorFile,parentEngineDescriptorSha256:fileHash(parentDescriptorFile),parentSourceManifest:parentFile,parentSourceManifestSha256:fileHash(parentFile),cppPatch:{relative:cpp,beforeSha256:hash(Buffer.from(before)),afterSha256:hash(Buffer.from(after)),changedSites:1},fixtures:[{relative:fixtureRelative,file:fixtureFile,sha256:hash(Buffer.from(fixture))},{relative:'tests/native_perf140_render_pushed_fields_close_test.gd',file:closeFixture,sha256:fileHash(closeFixture)}],runtimeClose:{relative:'systems/native_render/focus_lighting_native_input_candidate.gd',file:closeFile,sha256:fileHash(closeFile)},fixtureParent:{file:fixtureBeforeFile,sha256:hash(Buffer.from(fixtureBefore))},scope:'Only public const COW ptr/length source equality fastpath with original value fallback; script identity/getter shortcircuit and all other V4 semantics unchanged. Corrected close GDS is a separate runtime dependency. No font engine bundle.',builds:0,gpuTests:0};
 fs.writeFileSync(freezeFile,JSON.stringify(manifest,null,2),{flag:'wx'});console.log(JSON.stringify({freezeFile,sha256:fileHash(freezeFile),cppPatch:manifest.cppPatch,builds:0,gpuTests:0},null,2));
}else{
 const freeze=JSON.parse(fs.readFileSync(freezeFile)),stage=path.join(base,'engine-pushed-source-guard-v5');if(fs.existsSync(stage))throw Error('Retain previous engine stages');
 if(fileHash(parentDescriptorFile)!==freeze.parentEngineDescriptorSha256||fileHash(parentFile)!==freeze.parentSourceManifestSha256||fileHash(descriptor.engines.candidate.path)!==descriptor.engines.candidate.sha256)throw Error('Exact V4 parent changed');
 for(const guard of parent.guards)if(fileHash(guard.path)!==guard.sha256)throw Error('Retained/shared guard drift');
 for(const pin of parent.modulePins)if(fileHash(path.join(parent.moduleDirectory,pin.relative))!==pin.sha256)throw Error('Retained V4 source drift');
 for(const pin of freeze.pins)if(fileHash(path.join(freeze.module,pin.relative))!==pin.sha256)throw Error('V5 source freeze drift');
 for(const pin of freeze.fixtures)if(fileHash(pin.file)!==pin.sha256)throw Error('V5 fixture freeze drift');
 const source=path.join(stage,'source');fs.mkdirSync(stage,{recursive:true});fs.cpSync(parent.source,source,{recursive:true,preserveTimestamps:true,force:false,errorOnExist:true});
 const moduleDirectory=path.join(source,path.relative(parent.source,parent.moduleDirectory));for(const pin of freeze.pins)fs.copyFileSync(path.join(freeze.module,pin.relative),path.join(moduleDirectory,pin.relative));
 const inheritedModules=parent.inheritedModules.map(m=>({...m,directory:path.join(source,path.relative(parent.source,m.directory))}));
 const guards=[...parent.guards,{path:descriptor.engines.candidate.path,sha256:descriptor.engines.candidate.sha256,kind:'frozen-V4-engine'},{path:parentDescriptorFile,sha256:fileHash(parentDescriptorFile),kind:'frozen-V4-descriptor'},{path:path.join(parent.moduleDirectory,'light_input_registry.cpp'),sha256:freeze.cppPatch.beforeSha256,kind:'frozen-V4-guard-source'}];
 const manifest={...parent,directory:stage,source,reusedSource:undefined,parentDescriptor:parentDescriptorFile,parentDescriptorSha256:fileHash(parentDescriptorFile),moduleManifest:freezeFile,moduleManifestSha256:fileHash(freezeFile),moduleDirectory,modulePins:freeze.pins,inheritedModules,guards,variantDescription:freeze.scope,baselineRole:'Frozen V4 source-value guard engine; not promoted after slower measured published mode',candidateRole:'Same V4 engine with exact source COW ptr/length fastpath; default remains pull',copyPolicy:'Real source/object copies; retained engines and shared outputs unchanged',buildStarted:false};
 fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});console.log(JSON.stringify({stage,freezeFile,guards:guards.length,builds:0,engineStarts:0}));
}
