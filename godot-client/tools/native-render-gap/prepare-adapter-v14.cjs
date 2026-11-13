'use strict';
const fs=require('fs'),path=require('path');
const root=__dirname;
let a=fs.readFileSync(path.join(root,'replay-adapter-v13.cjs'),'utf8');
function once(s,x,y){if(s.split(x).length!==2)throw Error('Exact V14 seam '+x.slice(0,90));return s.replace(x,()=>y);}
const derivative=`function compilerDerivativeFiles(r,verify=true){
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
`;
a=once(a,'async function readSelection(file,expected){',derivative+'async function readSelection(file,expected){');
a=once(a,'  pin(s.engine,r.outputSha256);','  pin(s.engine,r.outputSha256);\n  compilerDerivativeFiles(r);');
a=once(a,"  let i=0;for(const p of [...m.patches,...m.modules])", "  let compilerIndex=0;for(const f of compilerDerivativeFiles(r,false))out['renderGapCompilerInput'+compilerIndex++]=f;\n  let i=0;for(const p of [...m.patches,...m.modules])");
a=once(a,' const script=g.script_context;'," const light=g.light_inputs??n?.accepted_render_bundle?.light_inputs;\n requireUse('--light-dictionary-read=single','singleDictionaryRead',light?.dictionary_single_requested===true&&light?.dictionary_single_reads>0);\n const script=g.script_context;");
fs.writeFileSync(path.join(root,'replay-adapter-v14.cjs'),a,{flag:'wx'});
let s=fs.readFileSync(path.join(root,'prepare-replay.cjs'),'utf8');
s=once(s,'replay-adapter-v13.cjs','replay-adapter-v14.cjs');
s=once(s,"const kernelArg=inputs.find(x=>x.startsWith('--kernel-stage='))?.slice('--kernel-stage='.length);", "const kernelArg=inputs.find(x=>x.startsWith('--kernel-stage='))?.slice('--kernel-stage='.length);\nconst reuseBase=inputs.find(x=>x.startsWith('--reuse-base='))?.slice('--reuse-base='.length);\nif(reuseBase&&!/^[a-z0-9-]+$/.test(reuseBase))throw Error('Explicit sealed base label required');");
s=once(s,"&&x!=='--kernel-stage='+kernelArg)","&&x!=='--kernel-stage='+kernelArg&&x!=='--reuse-base='+reuseBase)");
s=once(s," const base=await helper.stageProductionSelection({project,label:'render-gap-'+label,argv:options,preferenceSeeds:seeds});",` let base;
 if(reuseBase){const file=path.join(project,'.cache/native-presentation-parity/production-replay',reuseBase,'production-selection.json'),digest=sha(fs.readFileSync(file)),selection=await helper.readProductionSelection(file,digest);if(selection.mainSourceIdentity.sha256!==identity(project).sha256||JSON.stringify(selection.options)!==JSON.stringify(options))throw Error('Sealed base differs from current subject/options');for(const name of ['render','layout'])if(selection.preferences[name].sha256!==seeds[name].sha256)throw Error('Sealed common preferences differ');base={file,sha256:digest,selection};}
 else base=await helper.stageProductionSelection({project,label:'render-gap-'+label,argv:options,preferenceSeeds:seeds});`);
const old=" const pins=[];for(const [relative,bytes]of data){const f=path.join(destination,relative);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,bytes,{flag:'wx'});pins.push({relative,sha256:sha(bytes)});}";
const newer=` const immutableDossiers=new Set(['native-actor-alpha-propagation-v1.json','native-actor-alpha-propagation-v2.json','native-static-mesh-membership-fields-v1.json','native-static-placeable-spawntile-v1.json','native-static-placeable-spawntile-v2.json']),basePins=new Map(base.selection.pins.map(p=>[p.relative,p.sha256])),changed=new Set(overrides.map(p=>p.relative)),storage={reusedBase:reuseBase??null,linkedDossiers:0,linkedLogicalBytes:0};
 // All overrides are resolved before the single destination write. Only five
 // static REA evidence JSON files may link, and only to an immutable base.
 // Runtime/code/metadata/DLL paths remain independent writable copies.
 const pins=[];for(const [relative,bytes]of data){const f=path.join(destination,relative),digest=sha(bytes);fs.mkdirSync(path.dirname(f),{recursive:true});if(relative.startsWith('tools/native_parity/visibility/evidence/')&&immutableDossiers.has(path.basename(relative))&&!changed.has(relative)&&basePins.get(relative)===digest){fs.linkSync(path.join(base.selection.sourceProject,relative),f);storage.linkedDossiers++;storage.linkedLogicalBytes+=bytes.length;}else fs.writeFileSync(f,bytes,{flag:'wx'});pins.push({relative,sha256:digest});}`;
s=once(s,old,newer);
s=once(s,' const result={root,variant,adapter:', ' const result={root,variant,storage,adapter:');
fs.writeFileSync(path.join(root,'prepare-replay.cjs'),s);
console.log('Prepared V14 compiler-proof/actual-use adapter and bounded immutable dossier sharing');
