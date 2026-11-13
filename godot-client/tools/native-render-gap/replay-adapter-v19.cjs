'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const helper=require('../native-production-selection.cjs');
const identity=require('../native-feature-manifest.cjs').sourceIdentity;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function pin(file,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||sha(fs.readFileSync(file))!==expected)throw Error('Render-gap pin changed '+file);}
// Explicit private E-C build closure. Original mutable source/objects are only
// historical names; validation uses frozen headers, private objects/archives,
// immutable baseline capsule and both byte-identical whole controls.
function manualLightFiles(r,verify=true){
 if(r.kind!=='private-manual-light-module-engine')return [];
 const project=path.resolve(__dirname,'../..'),buildRoot=path.join(project,'.cache/native-render-gap/scene/light-member-build-c-a'),capsule=path.join(buildRoot,'candidate'),baseline=path.join(project,'.cache/native-render-gap/engine/build-1794156669344');
 const engineSha='10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13',baselineSha='982ac567f31fa7e3a834f46585b75a2601f22047803533029dde97efd66f5b61',manifestSha='1f4d7aeecc0cf3c9a8d674f567bd7d6883e94d1f27e6e3405a1ff7b4367cfcb3',invocationSha='293bb51780a297ca3e7d34b60a643331cf34da7151c08ec137813943666d47d6';
 const same=(a,b)=>path.resolve(a)===path.resolve(b),single=a=>Array.isArray(a)&&a.length===1&&a[0]==='nwn_light_input_registry',files=[];
 function exact(file,expected){if(verify)pin(file,expected);files.push(file);}
 function bounded(file,root){const relative=path.relative(root,path.resolve(file));if(!relative||relative.startsWith('..')||path.isAbsolute(relative))throw Error('Manual light proof escaped immutable closure');return path.resolve(file);}
 function json(file,expected){exact(file,expected);return JSON.parse(fs.readFileSync(file));}
 function archive(file,expected){exact(file,expected);if(!verify)return null;const bytes=fs.readFileSync(file);if(bytes.subarray(0,8).toString()!=='!<arch>\n')throw Error('Manual light NORMAL archive required');let names=null;const rows=[];
  for(let at=8;at<bytes.length;){if(at+60>bytes.length||bytes.subarray(at+58,at+60).toString()!=='`\n')throw Error('Manual light archive header invalid');const raw=bytes.subarray(at,at+16).toString().trim(),size=Number(bytes.subarray(at+48,at+58).toString().trim()),start=at+60;if(!Number.isSafeInteger(size)||size<0||start+size>bytes.length)throw Error('Manual light archive truncated');const body=bytes.subarray(start,start+size);if(raw==='//')names=body;else if(raw!=='/'&&raw!=='/SYM64/'){let name=raw;if(/^\/\d+$/.test(raw)){if(!names)throw Error('Manual light name table absent');const offset=Number(raw.slice(1)),end=names.indexOf('/\n',offset);if(offset<0||end<offset)throw Error('Manual light name offset invalid');name=names.subarray(offset,end).toString();}else name=raw.replace(/\/$/,'');rows.push({name,bytes:body.length,sha256:sha(body)});}at=start+size+(size&1);}
  return rows;
 }
 if(r.exitCode!==0||r.sourceUnchanged!==false||r.sharedSourceUnchanged!==true||r.sharedOutputsChanged!==false||!single(r.modifiedModules)||!same(r.run,capsule)||!same(r.output,path.join(capsule,'godot.windows.template_release.x86_64.exe'))||r.outputSha256!==engineSha||r.trainingOnly===true)throw Error('Manual light engine policy differs');
 exact(path.join(capsule,'receipt.json'),'0cbc919fa8a0f8139fbf340a3d8eca4e51261b3f237cfaabe6e39690e85e8b49');exact(r.output,engineSha);
 if(!same(r.sourceManifest?.file,path.join(capsule,'source-manifest.json'))||r.sourceManifest.sha256!==manifestSha||!same(r.invocation?.file,path.join(capsule,'invocation.json'))||r.invocation.sha256!==invocationSha||!same(r.manualBuild?.file,path.join(capsule,'manual-build.json'))||r.manualBuild.sha256!=='e46edc6e8dddfecd1d2688496a8aa6e30daeea5e7ed24c11941cb566d03f6ace')throw Error('Manual light metadata binding differs');
 const manifest=json(r.sourceManifest.file,manifestSha),inv=json(r.invocation.file,invocationSha),m=json(r.manualBuild.file,r.manualBuild.sha256);
 if(manifest.kind!=='private-manual-light-module-source-manifest'||!single(manifest.modifiedModules)||manifest.patches!==undefined||manifest.modules!==undefined||inv.kind!=='private-manual-light-module-build-invocation'||inv.sourceManifestSha256!==manifestSha||inv.manifestSha256!==undefined||inv.manualBuild.file!==r.manualBuild.file||inv.manualBuild.sha256!==r.manualBuild.sha256||manifest.manualBuild.file!==r.manualBuild.file||manifest.manualBuild.sha256!==r.manualBuild.sha256)throw Error('Manual light source/invocation policy differs');
 if(m.kind!=='private-manual-light-module-proof'||m.changedModule!=='nwn_light_input_registry'||m.sharedSourceUnchanged!==true||m.sharedOutputsChanged!==false||m.moduleSourcesChanged!==true||!same(m.builder?.file,path.join(buildRoot,'receipt.json'))||m.builder.sha256!=='75f526e532af062e3fa15ecd9db8eb54ec65c6467feae06b30c7d63a09454415')throw Error('Manual light builder closure differs');
 const b=json(m.builder.file,m.builder.sha256);
 if(b.kind!=='private-manual-light-module-build'||b.success!==true||b.originalInputsUnchanged!==true||b.sharedOutputsChanged!==false||b.candidate.sha256!==engineSha||b.baselineSha256!==baselineSha||b.control.sha256!==baselineSha||b.controlAfter.sha256!==baselineSha||JSON.stringify(b.steps)!==JSON.stringify(inv.commands)||JSON.stringify(b.commands)!==JSON.stringify(m.compilerCommands)||JSON.stringify(b.candidateDependencies)!==JSON.stringify(m.compileDependencies)||JSON.stringify(b.frozenHeaders)!==JSON.stringify(m.frozenHeaders)||JSON.stringify(m.frozenHeaders)!==JSON.stringify(manifest.frozenHeaders))throw Error('Manual light actual build differs');
 const baselineReceipt=json(path.join(baseline,'receipt.json'),'ca86d1e2b3e9ce364bad98d18fe3609b6b6758d0ee73a30024b79230fd1aa5f8');
 if(baselineReceipt.exitCode!==0||baselineReceipt.sourceUnchanged!==true||baselineReceipt.sharedOutputsChanged!==false||baselineReceipt.outputSha256!==baselineSha||!same(m.originalEpoch.engine,baselineReceipt.output)||m.originalEpoch.sha256!==baselineSha)throw Error('Manual light NoTrace epoch differs');
 exact(baselineReceipt.output,baselineSha);
 const baseManifest=json(path.join(baseline,'source-manifest.json'),'b1a00dfd5190e3ce1d619be0afb48e329792ba09be414d02f6c20c7a5f660e51');
 exact(path.join(baseline,'invocation.json'),'e54c5fad5d4401e23849591b536192332592bfb50c90194c1804a084a511a6ac');
 if(!same(m.originalEpoch.sourceManifest.file,path.join(capsule,'baseline-source-manifest.json'))||m.originalEpoch.sourceManifest.sha256!=='b1a00dfd5190e3ce1d619be0afb48e329792ba09be414d02f6c20c7a5f660e51'||JSON.stringify(manifest.baselineManifest)!==JSON.stringify(m.originalEpoch.sourceManifest))throw Error('Manual light copied base source differs');
 exact(m.originalEpoch.sourceManifest.file,m.originalEpoch.sourceManifest.sha256);
 for(const row of baseManifest.patches??[])exact(path.join(baseline,'source-evidence',row.relative),row.afterSha256);for(const row of baseManifest.modules??[])exact(path.join(baseline,'source-evidence',row.relative),row.sha256);
 if(JSON.stringify(m.controls.before)!==JSON.stringify(b.control)||JSON.stringify(m.controls.after)!==JSON.stringify(b.controlAfter))throw Error('Manual light whole controls differ');
 for(const control of [m.controls.before,m.controls.after]){bounded(control.file,buildRoot);bounded(control.map,buildRoot);if(control.sha256!==baselineSha)throw Error('Manual light whole control SHA differs');exact(control.file,baselineSha);exact(control.map,control.mapSha256);}
 const expectedSources={'light_input_registry.cpp':'c3fba024fc4e0582b2c84bc35676f752aa3bc1aa4595b41a09b4e170c40d54d8','light_input_registry.h':'a0214be29f101ca7662eb35d76903e82b0fd30972cfada581e2d87659dc7babd','register_types.cpp':'af962ca09e875f2a9e1f4f498bd3348f9bed62a7b8ad49a47015de1e6a7988e8','register_types.h':'141ad3d533f6987f125f9c3cf2a6512b2495e876ac4376b9f9fc7f8a07fc919b'};
 if(!Array.isArray(manifest.files)||manifest.files.length!==4)throw Error('Manual light four source inputs required');const seenSources=new Set();
 for(const row of manifest.files){const name=path.basename(row.relative);if(row.relative!=='modules/nwn_light_input_registry/'+name||row.sha256!==expectedSources[name]||seenSources.has(name)||!same(row.file,path.join(capsule,'source-evidence',row.relative)))throw Error('Manual light source scope differs');seenSources.add(name);exact(row.file,row.sha256);if(verify&&fs.statSync(row.file).size!==row.bytes)throw Error('Manual light source size differs');}
 if(m.frozenHeaders.length!==475)throw Error('Manual light475 frozen inputs required');const frozen=new Map();
 for(const row of m.frozenHeaders){bounded(row.file,path.join(buildRoot,'frozen-headers'));if(frozen.has(row.original))throw Error('Manual light duplicate frozen input');frozen.set(row.original,row);exact(row.file,row.sha256);if(verify&&fs.statSync(row.file).size!==row.bytes)throw Error('Manual light frozen input size differs');}
 if(m.compileDependencies.length!==2||b.controlDependencies.length!==2)throw Error('Manual light two TU dependency closures required');
 for(const closure of [...m.compileDependencies,...b.controlDependencies]){bounded(closure.dependencyFile,buildRoot);exact(closure.dependencyFile,closure.sha256);if(!Array.isArray(closure.inputs)||closure.inputs.length<30)throw Error('Manual light dependency closure incomplete');for(const input of closure.inputs){const row=frozen.get(input.file);if(!row||row.sha256!==input.sha256||row.bytes!==input.bytes)throw Error('Manual light frozen dependency binding differs');}}
 if(!same(m.compilerCommands.file,path.join(buildRoot,'compile-command.json'))||!same(m.compilerCommands.profile,path.join(buildRoot,'capture-profile.py')))throw Error('Manual light command evidence path differs');exact(m.compilerCommands.file,m.compilerCommands.sha256);exact(m.compilerCommands.profile,m.compilerCommands.profileSha256);
 const commands=JSON.parse(fs.readFileSync(m.compilerCommands.file));if(JSON.stringify(commands.rows)!==JSON.stringify(m.compilerCommands.rows)||commands.rows.length!==2)throw Error('Manual light two exact TU commands required');
 const plan=json(b.planFile,b.planSha256);if(plan.baselineSha256!==baselineSha||plan.compilerSha256!=='03e15580dda29518716dc6f6840d5ea055f526ddc8f59f14192b8d3e3eeea622'||inv.compiler!==plan.compiler||inv.compilerSha256!==plan.compilerSha256)throw Error('Manual light compiler epoch differs');
 const originalNames=['light_input_registry.windows.template_release.x86_64.o','register_types.windows.template_release.x86_64.o'];
 if(m.normalArchive.before.length!==2||m.objects.length!==2||b.controlObjects.length!==2||JSON.stringify(m.normalArchive.control)!==JSON.stringify(b.controlArchive)||JSON.stringify(m.normalArchive.candidate)!==JSON.stringify(b.candidateArchive))throw Error('Manual light archive scope differs');
 for(const [role,record,objects]of [['control',m.normalArchive.control,b.controlObjects],['candidate',m.normalArchive.candidate,m.objects]]){
  if(!same(record.file,path.join(buildRoot,role,'libmodule_nwn_light_input_registry.windows.template_release.x86_64.a')))throw Error('Manual light archive path differs');const body=archive(record.file,record.sha256);if(body&&JSON.stringify(body)!==JSON.stringify(record.orderedMembers))throw Error('Manual light ordered NORMAL bodies differ');
  if(record.orderedMembers.length!==2||JSON.stringify(record.orderedMembers.map(row=>row.name))!==JSON.stringify(originalNames))throw Error('Manual light ordered module members differ');
  for(let index=0;index<2;++index){const member=record.orderedMembers[index],object=objects.find(row=>path.basename(row.original)===member.name);if(!object||object.sha256!==member.sha256||!same(object.file,path.join(buildRoot,role,'objects',member.name)))throw Error('Manual light object-to-archive binding differs');exact(object.file,object.sha256);if(role==='control'&&(member.sha256!==m.normalArchive.before[index].sha256||member.bytes!==m.normalArchive.before[index].bytes))throw Error('Manual light original TU reproduction differs');}
 }
 for(const row of commands.rows){const name=path.basename(row.source);if(!['light_input_registry.cpp','register_types.cpp'].includes(name)||row.arguments.length!==1)throw Error('Manual light unexpected TU');for(const role of ['control','candidate']){const step=b.steps.find(step=>step.name===name+'-'+role),args=row.arguments[0].slice(1),outAt=args.indexOf('-o'),sourceAt=args.findIndex(arg=>same(path.resolve(b.source,arg),row.source));if(outAt<0||sourceAt<0)throw Error('Manual light original TU command incomplete');args[outAt+1]=path.relative(b.source,path.join(buildRoot,role,'objects',path.basename(row.target))).replaceAll('\\','/');if(role==='candidate'){const object=m.objects.find(item=>item.original===row.target);if(!object||object.prefixMap.to!=='modules/nwn_light_input_registry'||!same(object.sourceFile,path.join(buildRoot,'shadow/modules/nwn_light_input_registry',name)))throw Error('Manual light private TU source differs');args[sourceAt]=path.relative(b.source,object.sourceFile).replaceAll('\\','/');args.push('-ffile-prefix-map='+object.prefixMap.from+'='+object.prefixMap.to);const sourcePin=frozen.get(object.sourceFile);if(!sourcePin||sourcePin.sha256!==expectedSources[name])throw Error('Manual light compiled source differs');}if(!step||step.tool!==plan.compiler||step.cwd!==b.source||JSON.stringify(step.args)!==JSON.stringify(args)||step.exit!==0)throw Error('Manual light actual TU flags differ');}}
 for(const [role,archiveFile]of [['control',m.normalArchive.control.file],['candidate',m.normalArchive.candidate.file],['control-after',m.normalArchive.control.file]]){const step=b.steps.find(step=>step.name===role+'-link'),args=[...plan.linkArgs],outAt=args.indexOf('-o'),archiveAt=args.findIndex(arg=>path.resolve(b.source,arg)===path.resolve(b.source,'bin/obj/modules/libmodule_nwn_light_input_registry.windows.template_release.x86_64.a')),mapAt=args.findIndex(arg=>arg.startsWith('-Wl,-Map='));if(outAt<0||archiveAt<0||mapAt<0)throw Error('Manual light frozen main link incomplete');args[outAt+1]=path.relative(b.source,path.join(buildRoot,role,'godot.windows.template_release.x86_64.exe')).replaceAll('\\','/');args[archiveAt]=path.relative(b.source,archiveFile).replaceAll('\\','/');args[mapAt]='-Wl,-Map='+path.relative(b.source,path.join(buildRoot,role,'godot-main.map')).replaceAll('\\','/');if(!step||step.tool!==plan.compiler||step.cwd!==b.source||step.exit!==0||JSON.stringify(step.args)!==JSON.stringify(args))throw Error('Manual light exact main link differs');}
 return [...new Set(files)];
}
function manualLightUse(light,indexed=false){
 const positive=value=>Number.isSafeInteger(value)&&value>0;
 if(light?.lifetime_guard_requested!==true||!positive(light.lifetime_staged_rows)||!positive(light.lifetime_post_checks))return false;
 return !indexed||(light.plain_member_index_requested===true&&light.plain_member_index_active===true&&positive(light.plain_member_index_reads)&&positive(light.plain_member_index_proofs));
}

function pgoDerivativeFiles(r,verify=true){
 const generate=r.kind==='private-pgo-generation-build',use=r.kind==='private-pgo-use-build';if(!generate&&!use)return [];
 if(r.trainingOnly!==generate)throw Error('PGO training classification differs');
 if(verify)pin(r.compilerDerivative.file,r.compilerDerivative.sha256);const d=JSON.parse(fs.readFileSync(r.compilerDerivative.file));
 const delta=generate?['-fprofile-generate','-fprofile-update=atomic']:['-fprofile-use','-fprofile-partial-training','-Werror=missing-profile','-Werror=coverage-mismatch'];
 if(d.kind!==r.kind||d.mode!==(generate?'generate':'use')||d.sourceUnchangedAtOriginalBuildClosure!==true||d.sharedOutputsChanged!==false||JSON.stringify(d.delta)!==JSON.stringify(delta))throw Error('PGO derivative policy differs');
 if(d.selectedSources.length!==2||!d.selectedSources.every(p=>/[/\\]core[/\\]variant[/\\](dictionary|variant)\.cpp$/.test(p.source)))throw Error('PGO source scope differs');
 if(sha(fs.readFileSync(path.join(r.run,'source-manifest.json')))!==d.baseline.sourceManifestSha256)throw Error('PGO baseline source manifest differs');
 const manualFile=path.resolve(r.run,d.manualBuild.file);if(verify)pin(manualFile,d.manualBuild.sha256);const m=JSON.parse(fs.readFileSync(manualFile));
 const generationFile=path.join(r.run,'compiler-derivative/generation-build-receipt.json');
 if(use&&verify)pin(generationFile,m.generationReceipt?.sha256);
 const generation=generate?m:JSON.parse(fs.readFileSync(generationFile));
 if(!m.success||m.originalInputsUnchanged!==true||!generation.success||generation.control?.sha256!==d.baseline.engineSha256||generation.controlAfter?.sha256!==d.baseline.engineSha256||m.controlAfter?.sha256!==d.baseline.engineSha256||(generate?m.generation:m.use)?.sha256!==r.outputSha256||JSON.stringify(m.compileDelta)!==JSON.stringify(delta))throw Error('PGO actual control/build proof differs');
 const files=[r.compilerDerivative.file,manualFile];for(const p of d.pins){const f=path.resolve(r.run,p.relative),rel=path.relative(r.run,f);if(rel.startsWith('..')||path.isAbsolute(rel))throw Error('PGO evidence escaped capsule');if(verify){pin(f,p.sha256);if(fs.statSync(f).size!==p.bytes)throw Error('PGO byte size differs');}files.push(f);}
 if(verify){
  const archives=new Map();for(const p of d.members){const f=path.resolve(r.run,p.container),rel=path.relative(r.run,f);if(rel.startsWith('..')||path.isAbsolute(rel))throw Error('PGO archive escaped capsule');if(!archives.has(f)){const bytes=fs.readFileSync(f);if(bytes.subarray(0,8).toString()!=='!<arch>\n')throw Error('PGO normal archive required');const rows=[];let names=null;for(let at=8;at<bytes.length;){if(at+60>bytes.length||bytes.subarray(at+58,at+60).toString()!=='\x60\n')throw Error('PGO archive header invalid');const raw=bytes.subarray(at,at+16).toString().trim(),size=Number(bytes.subarray(at+48,at+58).toString().trim()),start=at+60;if(!Number.isSafeInteger(size)||size<0||start+size>bytes.length)throw Error('PGO archive truncated');const body=bytes.subarray(start,start+size);if(raw==='//')names=body;else if(raw!=='/'&&raw!=='/SYM64/'){let name=raw;if(/^\/\d+$/.test(raw)){if(!names)throw Error('PGO name table absent');const offset=Number(raw.slice(1)),end=names.indexOf('/\n',offset);if(offset<0||end<offset)throw Error('PGO long name invalid');name=names.subarray(offset,end).toString();}else name=raw.replace(/\/$/,'');rows.push({name,body});}at=start+size+(size&1);}archives.set(f,rows);}const rows=archives.get(f),row=rows[p.memberIndex];if(!row||row.name!==p.member||row.body.length!==p.bytes||sha(row.body)!==p.sha256)throw Error('PGO ordered member differs');}
 }
 return [...new Set(files)];
}
function compilerDerivativeFiles(r,verify=true){
 if(r.kind==='private-pgo-generation-build'||r.kind==='private-pgo-use-build')return pgoDerivativeFiles(r,verify);
 if(r.kind!=='private-vm-codegen-build')return [];
 if(verify)pin(r.compilerDerivative.file,r.compilerDerivative.sha256);
 const d=JSON.parse(fs.readFileSync(r.compilerDerivative.file));
 if(d.kind!==r.kind||d.sourceUnchangedAtOriginalBuildClosure!==true||d.sharedOutputsChanged!==false||JSON.stringify(d.delta)!==JSON.stringify(['-fno-gcse only for modules/gdscript/gdscript_vm.cpp']))throw Error('Private compiler derivative policy differs');
 if(verify)pin(d.manualBuild.file,d.manualBuild.sha256);
 const manual=JSON.parse(fs.readFileSync(d.manualBuild.file));
 if(!manual.success||manual.originalInputsUnchanged!==true||manual.candidate.sha256!==r.outputSha256||manual.control.sha256!==d.baseline.engineSha256||manual.controlAfter.sha256!==d.baseline.engineSha256||JSON.stringify(manual.compileDelta)!==JSON.stringify(['-fno-gcse']))throw Error('Private compiler control/candidate proof differs');
 const files=[r.compilerDerivative.file,d.manualBuild.file],archives=new Map();
 for(const p of d.pins){const f=path.resolve(r.run,p.relative),rel=path.relative(r.run,f);if(rel.startsWith('..')||path.isAbsolute(rel))throw Error('Compiler evidence escaped capsule');if(verify){pin(f,p.sha256);if(fs.statSync(f).size!==p.bytes)throw Error('Compiler evidence byte size differs');}files.push(f);}
 if(verify)for(const p of d.members){const f=path.resolve(r.run,p.container),rel=path.relative(r.run,f);if(rel.startsWith('..')||path.isAbsolute(rel))throw Error('Compiler archive escaped capsule');if(!archives.has(f))archives.set(f,fs.readFileSync(f));const bytes=archives.get(f);if(p.containerOffset<0||p.bytes<0||p.containerOffset+p.bytes>bytes.length||sha(bytes.subarray(p.containerOffset,p.containerOffset+p.bytes))!==p.sha256)throw Error('Historical compiler archive member differs');}
 return [...new Set(files)];
}
async function readSelection(file,expected){
 pin(file,expected);const s=JSON.parse(fs.readFileSync(file));
 if(s.version!==3||s.kind!=='private-render-gap-selection'||s.production!==false||s.experimental!==true||path.resolve(s.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private render-gap selection policy differs');
 const base=await helper.readProductionSelection(s.renderGap.base.file,s.renderGap.base.sha256);
 for(const field of ['options','engineArguments','renderThread','environment','featureSelection','renderConfiguration','loadingPipeline','profiling','preferences','cameraPolicy'])if(JSON.stringify(s[field])!==JSON.stringify(base[field]))throw Error('Private render-gap configuration differs '+field);
 if(JSON.stringify(s.flags)!==JSON.stringify([...base.flags,...s.renderGap.extraFlags]))throw Error('Private native flags differ');
 for(const f of s.renderGap.extraFlags)if(!['--rig-skin-publisher=native','--particle-scene-boundary=native','--particle-scene-boundary=legacy','--skeleton-upload-guard=exact','--skeleton-pair-guard=exact','--motion-facing=native','--pair-record-reuse=exact','--particle-chunk-admission=childless','--light-pair-layer-repair=exact','--light-pair-filter=consumers','--light-input-read=typed','--frame-pacing-metrics=on','--particle-sparse-timing','--particle-coarse-timing','--particle-setup-boundary=bound','--particle-scene-direct=pod','--particle-scene-direct=legacy','--skeleton-force-pass=once','--visibility-chain-cache=epochs','--light-input-proof=segments','--particle-hot-parameters=bound','--particle-hot-parameters=legacy','--window-feature-counters','--script-owner-trace=on','--particle-resident-text=borrow','--particle-resident-text=legacy','--particle-empty-clips=skip','--particle-empty-clips=legacy','--light-dictionary-read=single','--particle-core-survey','--light-input-lifetime=guarded','--light-member-read=indices','--particle-key-survey'].includes(f))throw Error('Unsupported private flag');
 if(s.flags.includes('--light-member-read=indices')&&!['--light-input-read=typed','--light-input-proof=segments','--light-input-lifetime=guarded'].every(flag=>s.flags.includes(flag)))throw Error('Indexed light reads require typed segmented lifetime control');
 const proof=s.renderGap.engineProof;
 if(proof){
  pin(proof.file,proof.sha256); const r=JSON.parse(fs.readFileSync(proof.file));
  const manual=r.kind==='private-manual-light-module-engine';
  if(r.exitCode!==0||r.sharedOutputsChanged!==false||r.output!==s.engine||r.outputSha256!==s.runtime.executableSha256||(manual?r.sourceUnchanged!==false:r.sourceUnchanged!==true))throw Error('Private engine build proof differs');
  if(manual?s.renderGap.engineCapsule!=='light-member-c':s.renderGap.engineCapsule!=null)throw Error('Private engine capsule classification differs');
  if((r.trainingOnly===true)!==(s.renderGap.trainingOnly===true))throw Error('Private training mode differs');
  pin(s.engine,r.outputSha256);
  if(manual)manualLightFiles(r);else compilerDerivativeFiles(r);
  pin(proof.invocation.file,proof.invocation.sha256);
  const inv=JSON.parse(fs.readFileSync(proof.invocation.file));
  pin(proof.manifest.file,proof.manifest.sha256);
  if(path.resolve(proof.manifest.file)!==path.join(r.run,'source-manifest.json')||(manual?inv.sourceManifestSha256!==proof.manifest.sha256:inv.manifestSha256!==proof.manifest.sha256))throw Error('Sealed engine manifest differs');
  if(manual&&(JSON.stringify(proof.manifest)!==JSON.stringify(r.sourceManifest)||JSON.stringify(proof.invocation)!==JSON.stringify(r.invocation)))throw Error('Manual source proof binding differs');
  const manifest=JSON.parse(fs.readFileSync(proof.manifest.file));
  if(!manual)for(const p of manifest.patches)pin(path.join(r.run,'source-evidence',p.relative),p.afterSha256);
  if(!manual)for(const p of manifest.modules)pin(path.join(r.run,'source-evidence',p.relative),p.sha256);
  const expectedRuntime={...base.runtime,executable:s.engine,executableSha256:r.outputSha256,experimentalOverrides:{engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256}};
  if(JSON.stringify(s.runtime)!==JSON.stringify(expectedRuntime))throw Error('Private runtime differs beyond executable');
 }else if(JSON.stringify(s.runtime)!==JSON.stringify({...base.runtime,experimentalOverrides:{engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256}})||s.engine!==base.engine)throw Error('Installed runtime changed');
 const expectedPerformance=structuredClone(base.performanceOptions);
 if(expectedPerformance.renderCore){expectedPerformance.renderCore={...expectedPerformance.renderCore,engineSha256:s.runtime.executableSha256,nativeKernelSha256:s.particleLoop.module.sha256,scope:'Private experimental derivative of the accepted functional bundle; exact engine and DLL overrides are independently pinned. Not a production promotion.'};}
 if(JSON.stringify(s.performanceOptions)!==JSON.stringify(expectedPerformance)||JSON.stringify(s.renderCore)!==JSON.stringify(expectedPerformance.renderCore))throw Error('Private selected core binding differs');
 for(const p of s.renderGap.overrides)pin(p.file,p.sha256);
 helper.validatePins(s);helper.validatePreferencePins(s);
 if(identity(s.sourceProject).sha256!==s.mainSourceIdentity.sha256)throw Error('Private source identity changed');
 pin(s.particleLoop.module.file,s.particleLoop.module.sha256);
 return {...s,evidence:{file:path.resolve(file),sha256:expected,sourceProject:s.sourceProject,sourceSignature:s.mainSourceIdentity.sha256,engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256,flags:[...s.flags],production:false,experimental:'isolated-render-gap',trainingOnly:s.renderGap.trainingOnly===true,performanceAccepted:false,scope:'Pinned current application plus explicit private overrides; matched settings/display/camera/authority gates remain required.'}};
}
function runtimeFiles(s){
 const proof=s.renderGap.engineProof,out={renderGapAdapter:__filename,renderGapBase:s.renderGap.base.file};
 if(proof){
  out.renderGapEngineProof=proof.file;out.renderGapEngineInvocation=proof.invocation.file;out.renderGapEngineManifest=proof.manifest.file;
  const r=JSON.parse(fs.readFileSync(proof.file)),m=JSON.parse(fs.readFileSync(proof.manifest.file));
  let compilerIndex=0;for(const f of compilerDerivativeFiles(r,false))out['renderGapCompilerInput'+compilerIndex++]=f;
  let i=0;if(r.kind==='private-manual-light-module-engine'){for(const file of manualLightFiles(r,false))out['renderGapManualSource'+i++]=file;}else for(const p of [...m.patches,...m.modules])out['renderGapEngineSource'+i++]=path.join(r.run,'source-evidence',p.relative);
 }
 return out;
}
function coreSurveyUse(core,pacing){
 if(core?.enabled!==true||core.stride!==120||core.capacity!==256||core.clocks_per_frame!==0||!Number.isSafeInteger(core.frame_calls)||core.frame_calls<1||!Number.isSafeInteger(core.samples)||core.samples!==Math.ceil(core.frame_calls/120)||core.dropped_distinct_cores!==0)return false;
 if(!Number.isSafeInteger(core.process_id)||core.process_id<=0||!Number.isSafeInteger(core.frame_thread_id)||core.frame_thread_id<=0||core.frame_thread_id!==core.report_thread_id||core.frame_thread_id!==pacing?.main_thread_policy?.thread_id||pacing.main_thread_policy.available!==true)return false;
 const exactPositive=x=>typeof x==='string'&&/^[1-9][0-9]*$/.test(x)&&BigInt(x)<=9223372036854775807n;
 if(!exactPositive(core.process_creation_100ns_exact)||!exactPositive(core.report_thread_creation_100ns_exact)||core.report_thread_creation_100ns_exact!==pacing.main_thread_policy.expected_creation_100ns_exact)return false;
 const topology=core.topology;
 if(topology?.error!==0||!Array.isArray(topology.rows)||!topology.rows.length)return false;
 const cpus=new Set(),classes=new Set();
 for(const r of topology.rows){if(![r.group,r.logical_processor_index,r.core_index,r.efficiency_class].every(x=>Number.isSafeInteger(x)&&x>=0))return false;const key=r.group+':'+r.logical_processor_index;if(cpus.has(key))return false;cpus.add(key);classes.add(r.efficiency_class);}
 if(classes.size<2||!Array.isArray(core.histogram)||!Array.isArray(core.records)||core.histogram.length>256||core.records.length!==Math.min(core.samples,256))return false;
 let total=0;const seen=new Set();
 for(const r of core.histogram){const key=r.group+':'+r.number;if(!cpus.has(key)||seen.has(key)||!Number.isSafeInteger(r.count)||r.count<1)return false;seen.add(key);total+=r.count;}
 if(total!==core.samples)return false;
 let previous=0,expected=1+120*Math.max(0,core.samples-256);for(const r of core.records){if(!Number.isSafeInteger(r.frame)||r.frame!==expected||r.frame>core.frame_calls||!cpus.has(r.group+':'+r.number))return false;previous=r.frame;expected+=120;}
 return previous===1+120*(core.samples-1);
}
function keySurveyUse(k){
 if(k?.enabled!==true||k.stride!==120||k.clocks_per_frame!==0||k.global_key_capacity!==2048||k.global_key_overflow!==0||k.field_overflow!==0||!Number.isSafeInteger(k.frames)||k.frames<1||!Number.isSafeInteger(k.samples)||k.samples!==Math.ceil(k.frames/120))return false;
 if(![k.unknown_field_reads,k.unknown_map_fallbacks,k.clip_lookups,k.clip_hits].every(x=>Number.isSafeInteger(x)&&x>=0)||k.unknown_map_fallbacks>k.unknown_field_reads||k.clip_lookups<1||k.clip_hits>k.clip_lookups||!Array.isArray(k.global_keys)||!k.global_keys.length||k.global_keys.length>2048||!Array.isArray(k.private_fields)||k.private_fields.length>128)return false;
 const globalIds=new Set(),fieldIds=new Set();
 for(const r of k.global_keys){if(!Number.isSafeInteger(r.id)||r.id<0||r.id>=2048||globalIds.has(r.id)||typeof r.name!=='string'||!r.name.length||!Number.isSafeInteger(r.reads)||r.reads<1)return false;globalIds.add(r.id);}
 for(const r of k.private_fields){if(!Number.isSafeInteger(r.id)||r.id<0||r.id>=128||fieldIds.has(r.id)||typeof r.name!=='string'||!r.name.length||!Number.isSafeInteger(r.reads)||r.reads<1||!Number.isSafeInteger(r.map_fallbacks)||r.map_fallbacks<0||r.map_fallbacks>r.reads)return false;fieldIds.add(r.id);}
 return true;
}
function verifyNative(s,n){
 const errors=[];
 if(n?.runtime_features?.executable&&path.resolve(n.runtime_features.executable)!==path.resolve(s.engine))errors.push('Native executable mismatch');
 const g=n?.render_gap??{},flags=s.renderGap.extraFlags,proof={};
 const requireUse=(flag,name,value)=>{if(flags.includes(flag)){proof[name]=value===true;if(value!==true)errors.push('Actual feature work was not observed: '+name);}};
 requireUse('--motion-facing=native','motion',g.motion?.supported>0);
 requireUse('--particle-scene-boundary=native','boundary',g.particle_boundary?.boundary?.eligibility_reads>0||g.particle_boundary?.eligibility_reads>0);
 requireUse('--rig-skin-publisher=native','skin',(g.skin_owners??[]).some(x=>x.totals?.completed>0));
 requireUse('--light-input-read=typed','lightReader',g.light_inputs?.plain_claims>0&&g.light_inputs?.plain_rows>0&&g.light_inputs?.plain_field_reads>0);
 requireUse('--pair-record-reuse=exact','pairReuse',g.engine_features?.pair_reused>0&&g.engine_features?.pair_reuse_passes>0);
 requireUse('--light-pair-filter=consumers','lightFilter',g.engine_features?.light_excluded>0&&g.engine_features?.light_filter_passes>0);
 requireUse('--particle-chunk-admission=childless','childless',(g.chunk_admission?.entries??[]).some(x=>x.requested===true&&x.last_checked===true));
 requireUse('--particle-sparse-timing','sparseTiming',g.particle_sample?.enabled===true&&g.particle_sample?.samples>0&&g.particle_sample?.successes===g.particle_sample?.samples&&g.particle_sample?.errors===0);
 requireUse('--particle-setup-boundary=bound','setupBoundary',g.particle_sample?.setup_boundary===true&&g.particle_sample?.animating_key_binds>0&&g.particle_sample?.static_noncallable_uses+g.particle_sample?.static_null_callable_uses>0);
 requireUse('--frame-pacing-metrics=on','pacing',g.pacing?.enabled===true&&g.pacing?.main?.length>0&&g.pacing?.render?.length>0&&g.pacing?.cpu_windows?.length>0);
 requireUse('--particle-core-survey','coreSurvey',coreSurveyUse(g.core_survey,g.pacing));
 requireUse('--particle-key-survey','keySurvey',keySurveyUse(g.key_survey));
 const boundary=g.particle_boundary?.boundary??g.particle_boundary;
 requireUse('--particle-scene-direct=pod','directScene',boundary?.direct_enabled===true&&boundary?.direct_eligibility_calls>0&&boundary?.direct_pose_reads>0);
 requireUse('--skeleton-force-pass=once','skeletonForce',g.engine_features?.skeleton_force_once?.stable_calls>0&&g.engine_features?.skeleton_force_once?.avoided_offsets>0);
 requireUse('--particle-coarse-timing','coarseTiming',g.particle_sample?.coarse_phases===true&&g.particle_sample?.phase_success_samples>0&&g.particle_sample?.phase_clock_reads===4*g.particle_sample?.phase_success_samples);
 const empty=g.empty_clips?.owners??[];
 requireUse('--particle-empty-clips=skip','emptyClipLookup',empty.some(x=>x.configured===true&&x.enabled===true&&x.map_sealed===true&&x.configure_depth===0&&x.copied_channel_count===0&&x.lookup_skips>0));
 requireUse('--particle-empty-clips=legacy','emptyClipLegacy',empty.length>0&&empty.every(x=>x.enabled===false)&&empty.some(x=>x.lookup_calls>0));
 const light=g.light_inputs??n?.accepted_render_bundle?.light_inputs;
 requireUse('--light-dictionary-read=single','singleDictionaryRead',light?.dictionary_single_requested===true&&light?.dictionary_single_reads>0);
 requireUse('--light-input-lifetime=guarded','lightLifetimeGuard',manualLightUse(light,false));
 requireUse('--light-member-read=indices','lightMemberIndices',manualLightUse(light,true));
 const script=g.script_context;
 requireUse('--script-owner-trace=on','scriptOwnerTrace',script?.enabled===true&&script?.available===true&&script?.registered>0&&script?.registered===script?.rows?.length&&script?.main_native_thread_id===g.pacing?.main_thread_policy?.thread_id);
 requireUse('--particle-resident-text=borrow','residentTextBorrow',g.resident_text?.borrowed===true&&g.resident_text?.borrowed_reads>0);
 requireUse('--particle-resident-text=legacy','residentTextLegacy',g.resident_text?.borrowed===false&&g.resident_text?.legacy_reads>0);
 const visibility=g.engine_features?.visibility_chain_cache;
 requireUse('--visibility-chain-cache=epochs','visibilityCache',visibility?.enabled===true&&visibility?.disabled===false&&visibility?.queries>10000&&(visibility?.hits+visibility?.ancestor_hits)>10000);
 requireUse('--light-input-proof=segments','lightProofSegments',g.light_inputs?.plain_segment_proofs>0&&g.light_inputs?.plain_segment_reuses>0);
 const hotOwners=g.hot_parameters?.owners??[];
 requireUse('--particle-hot-parameters=legacy','hotLegacy',hotOwners.length>0&&hotOwners.every(x=>x.enabled===false));
 requireUse('--particle-hot-parameters=bound','hotFields',hotOwners.some(x=>x.enabled===true&&(x.fields??[]).some(f=>f.reads>0&&f.hits>0)));
 requireUse('--window-feature-counters','windowFeatures',Object.keys(n?.performance_window?.engine_features_begin??{}).length>0&&Object.keys(n?.performance_window?.engine_features_end??{}).length>0&&n?.performance_window?.engine_process_frame_end>n?.performance_window?.engine_process_frame_begin);
 if(s.performanceOptions.renderCore?.enabled&&!s.renderGap.extraFlags.some(x=>['--frame-pacing-metrics=on','--particle-sparse-timing','--particle-coarse-timing'].includes(x))){const bundle=require(path.join(s.sourceProject,'tools/native-feature-manifest.cjs')).verifyAcceptedBundleUse(s.performanceOptions.renderCore,n?.accepted_render_bundle,{requireBusyUse:true});proof.acceptedFunctionalBundle=bundle.status==='observed';errors.push(...bundle.errors);}
 return {status:errors.length?'rejected':'observed',errors,variant:s.renderGap.variant,features:proof,scope:'Pinned source/engine selection plus requested current-route feature counters. Performance, visual and public-server acceptance remain separate.'};
}
module.exports={readSelection,runtimeFiles,verifyNative,coreSurveyUse,keySurveyUse,manualLightFiles,manualLightUse};
