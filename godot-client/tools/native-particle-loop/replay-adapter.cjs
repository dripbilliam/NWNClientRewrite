'use strict';
// Consume a deliberately private selection while retaining the normal replay
// driver's full feature, camera, movement, preferences and cleanup gates.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),helper=require('../native-production-selection.cjs');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function pin(file,sha){if(!/^[a-f0-9]{64}$/.test(sha??'')||hash(fs.readFileSync(file))!==sha)throw Error('Private particle pin differs: '+file);}
async function readSelection(file,expected){
 pin(file,expected);const s=JSON.parse(fs.readFileSync(file));
 if(s.version!==3||s.kind!=='private-particle-loop-selection'||s.production!==false||!s.experimental||!['control','candidate'].includes(s.particleLoop?.variant)||path.resolve(s.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private particle selection policy differs');
 const base=await helper.readProductionSelection(s.particleLoop.base.file,s.particleLoop.base.sha256);
 for(const field of ['options','runtime','engine','engineArguments','renderThread','flags','environment','featureSelection','performanceOptions','renderConfiguration','loadingPipeline','profiling','preferences','cameraPolicy'])if(JSON.stringify(s[field])!==JSON.stringify(base[field]))throw Error('Private particle configuration differs: '+field);
 helper.validatePins(s);helper.validatePreferencePins(s);
 if(require('../native-feature-manifest.cjs').sourceIdentity(s.sourceProject).sha256!==s.mainSourceIdentity.sha256)throw Error('Private particle source identity differs');
 for(const name of ['build','source'])pin(s.particleLoop[name].file,s.particleLoop[name].sha256);
 const proof=JSON.parse(fs.readFileSync(s.particleLoop.build.file));if(!proof.success||proof.variant!==s.particleLoop.variant||proof.binarySha256!==s.particleLoop.module.sha256)throw Error('Private particle build provenance differs');
 const moduleFile=path.join(s.sourceProject,'.cache/native-kernel/nwn-particle-kernel.dll');if(path.resolve(s.particleLoop.module.file)!==moduleFile)throw Error('Unexpected private DLL path');pin(moduleFile,s.particleLoop.module.sha256);
 if(fs.readFileSync(path.join(s.sourceProject,'.godot/extension_list.cfg'),'utf8')!=='res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n')throw Error('Private active extensions differ');
 return {...s,evidence:{file:path.resolve(file),sha256:expected,sourceProject:s.sourceProject,sourceSignature:s.mainSourceIdentity.sha256,engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256,flags:[...s.flags],production:false,experimental:'isolated-particle-loop',scope:'Private particle bookkeeping comparison. Normal DLL, source and launcher are unchanged.'}};
}
function runtimeFiles(s){return {particleReplayAdapter:__filename,particleBuildProof:s.particleLoop.build.file,particleSourceProof:s.particleLoop.source.file,particleBaseSelection:s.particleLoop.base.file};}
function verifyNative(s,native){const p=native?.world?.native_particles;const errors=[];if(!(p?.emitters>0&&p.fused_simulated>0&&p.active>0&&p.vertices>0))errors.push('Actual native particle population was not observed');return {status:errors.length?'rejected':'observed',errors,variant:s.particleLoop.variant,module:s.particleLoop.module,population:p?{emitters:p.emitters,fused:p.fused_simulated,active:p.active,vertices:p.vertices,failed:p.failed}:null,scope:'Actual native particle population plus pinned private build. OS loaded-module identity is independently required by the run wrapper.'};}
module.exports={readSelection,runtimeFiles,verifyNative};
