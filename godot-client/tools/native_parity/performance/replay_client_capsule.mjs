// Read-only selection for the matched base-world experiment. Does not launch.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {verifyClientLaunchEngine} from '../loading/client_launch_engine.mjs';
import {verifyClientLaunchDisplay} from '../loading/client_launch_proofs.mjs';
const require=createRequire(import.meta.url);
const allowed=new Set([
 '92c8c6591d252b480d8afa3297aedcc68fbec1c5d6d997cc5a4869df13a5a504',
 '7d6111133aecd9dcebf9f10b1f5e9705c6174f061b776b817b92c298a8c2b8ab',
 // One-file diagnostic restorations of the failed candidate; not accepted builds.
 '7ff9cd7afbb7596d341db601bcfd4143bd6ebb5cbb44d9bf73d940621d0f6a2b',
 '9b5e7fe937ace3b9aae2c3bc938631e1c120f3e6e59f32619cc5456df9742d78',
 // Same failed candidate plus the verified inherited three-lane plan repair.
 'ffb1e4dd8c3c7525532918418581f104796c5539ecfde67448e23404031028e6',
 // Common-source control/owner/template cache experiments, not release builds.
 'ee1fb167e22955aba36ee18e7ac67df2b630e40650d9c4d3799cfaf2eaf6758d',
 '2e2d6d29c229cabc6ce9480674538b836f18c8e81ea427c30cabbe2edff3b8b0',
 '06e4567be757e28d10b28f937e9da5ffacfe041175627d2f54d264a4c3f3b057',
 // Same cache family with boundary-driven base progress, all controls common.
 'b68ec68e4d1fe7fa5f8aba18faadc9776af55be253c09717fa687f7a2991877f',
 '9a1c56f32224fcbd38d4faa946c99a729c87a14b13fd8a78408b4a609d7837c4',
 '69ff69415642241e6582b5f1ac37eafda9e0423406238f582ead9a8a1d81642a',
 // One-file cached model-layout experiment; residency controls remain off.
 'd60015c3225dac25650d68853d8e7da512b8d79643a8b49f360f52d11bdf7f86',
 // Common-source scheduling control / ready-probe + timed-base experiment.
 '2923346f20cddbb52c7617ade67348c5897c9152fe74c05cf8945764617124be',
 '5fd0472500d3deaa699592beec5ce3f17241ccf48b46db60f7fb33b1940f1367',
 // Common-source shared animation / continuous streaming / static draw family.
 '07f83e19997c59d937fce338e2704e962dce402e0fc4b31ab6dd4120f968cc78',
 'be90b503e2470336e9cf3eb621b9fdc5a35a39ab16e65032ebeeb180e8ad5974',
 '3dd72160e2dc5d1ababbeed9cbf84b244308424701974c9d5ac16daff1e06f14',
 '8a0289ee21097d2a9950d2634e1bd69e1332fa09493f3a0bba2a0a06f38494b8',
 // Revised selective rigs and material/cell merging with correct light unpairing.
 '50e31a3e45712ee3f0d743bc2c314b406b61695ee3e1aa685955498f43ebe3f8',
 'efde061de10e59a2f5e13c74c10eec84dd4d068dc5a05c3be2f9789b2519d09d',
 'b51f884e7b28140bc72da432e1c5d62502a303255353c6017529280675867a55',
 '6e2979fd503f79219537e9cedc2749e73d546a704f27a57871f840da2aedc676',
 // Same-source BASE mesh-leaf and native model draw-resource cache experiments.
 '45aa31efc132727cc826cbeb7837d3cc437247dbec4f056e4247653c3e36864f',
 '53204cced1bd7604334c2a07362d18c408c9fe0735369db5d17be7db01b80ef4',
 '0b3cadd5783b1071f88664b9bce75f9a5cdbfa03ca4cfc5ced9397097040e1c1',
 // Metadata-lock cleanup; same native cache and BASE behavior.
 '2785e5c00f1b7dfc394caade9e48973bbe4ad69fba6cc5be3d7f4795d4026869',
 'd8af9908b3b1ac9251fd31dfa010ba0227cb34a366e24e4c7c53568699104c0d',
 '74afc5c09cba6398fdc24aa0705ebe184c86db4970dcc6baf550ae4ff35d5320',
 // Reflection-free supported model recipe and earlier native draw cache reads.
 '4e94773a6f687dbeaa7752e0926a7087e123b01ca34c18836734dcb0107a96cd',
 '68a847eacfb251d8d9df7e2cd2f4d4e7a89481575b125a21a9a40b3f7ca536cd',
 '942080162cfd9a21361710f5c1ce7a077cc07b78eb3cdf0c10d298422085fd03',
]);
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
export function baseWorldExperimentFlags(experiments){
 if(experiments===undefined)return [];
 const choices={baseOwner:['original','retained'],baseTemplates:['original','retained'],baseReadyProbe:['ordinary','ready'],baseAdmission:['ordinary','timed'],sharedAnimations:['ordinary','shared'],baseStreaming:['waves','continuous'],staticScenery:['individual','batched','merged'],baseDraw:['individual','merged'],nativeDrawCache:['none','prepared'],modelTemplates:['packed','recipe']};
 if(experiments===null||typeof experiments!=='object'||Array.isArray(experiments)||Object.keys(experiments).some(key=>!Object.hasOwn(choices,key)))throw Error('Unsupported reviewed base-world experiment');
 for(const [key,value] of Object.entries(experiments))if(!choices[key].includes(value))throw Error('Invalid reviewed base-world experiment mode');
 if(experiments.baseTemplates==='retained'&&experiments.baseOwner!=='retained')throw Error('Early template reuse requires the retained scenery owner');
 if(experiments.baseReadyProbe==='ready'&&experiments.baseTemplates!=='retained')throw Error('Ready-template probing requires retained templates');
 if(experiments.baseStreaming==='continuous'&&(experiments.baseOwner!=='retained'||experiments.baseTemplates!=='retained'))throw Error('Continuous base streaming requires retained owner and templates');
 return [...(experiments.baseOwner==='retained'?['--base-scenery-owner=retained']:[]),...(experiments.baseTemplates==='retained'?['--base-scenery-templates=retained']:[]),...(experiments.baseReadyProbe==='ready'?['--base-scenery-template-probe=ready']:[]),...(experiments.baseAdmission==='timed'?['--base-scenery-admission=timed']:[]),...(experiments.sharedAnimations==='shared'?['--shared-animation-preparation=true']:[]),...(experiments.baseStreaming==='continuous'?['--base-scenery-stream=continuous']:[]),...(experiments.staticScenery==='batched'?['--static-scenery=batched']:experiments.staticScenery==='merged'?['--static-scenery=merged']:[]),...(experiments.baseDraw==='merged'?['--base-scenery-draw=merged']:[]),...(experiments.nativeDrawCache==='prepared'?['--native-draw-cache=prepared','--native-draw-cache-gib=25']:[]),...(experiments.modelTemplates==='recipe'?['--model-template=recipe']:[])];
}
export function readReplayClientCapsule(file,expected,project){
 if(!file&&!expected)return null;
 if(!file||!allowed.has(expected))throw Error('Explicit reviewed replay capsule and SHA-256 required');
 const bytes=fs.readFileSync(file);if(sha(bytes)!==expected)throw Error('Replay capsule manifest changed');
 const m=JSON.parse(bytes);
 if(m.version!==1||!['live-walk-diagnostic-stage','base-world-entry-diagnostic-stage'].includes(m.kind)||m.mode!=='--highlight=whole-character'||m.parkedWorkIncluded!==false)throw Error('Replay capsule policy differs');
 verifyClientLaunchEngine(m.engine);verifyClientLaunchDisplay(m.display);
 for(const p of m.pins){
  const target=path.resolve(m.project,p.relative),r=path.relative(m.project,target);
  if(r==='..'||r.startsWith('..'+path.sep)||path.isAbsolute(r)||sha(fs.readFileSync(target))!==p.sha256)throw Error('Replay capsule source changed: '+p.relative);
 }
 if(m.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Replay capsule particle library differs');
 const configurationFile=path.join(project,'tools/native-render-configuration.cjs');
 if(sha(fs.readFileSync(configurationFile))!=='cbee809d26508b3208c1020e359988d492a242421893e3e9c52e9524d7d4971c')throw Error('Reviewed gameplay render configuration changed');
 const configuration=require(configurationFile).resolveNativeRenderConfiguration({arg:n=>n==='render-profile'?'gameplay':undefined,env:{},isolated:false});
 const experimentFlags=baseWorldExperimentFlags(m.experiments);
 const flags=[...configuration.arguments,...experimentFlags,'--particle-random=native','--particle-clocks=native','--particle-pose-leases=managed','--light-input-registry=builtin','--drive-collision=indexed','--highlight=whole-character','--native-overhead-clocks=true','--render-preferences='+m.settings.file];
 return {manifest:m,engine:m.engine.path,sourceProject:m.project,screen:m.display.screen,flags,environment:{...configuration.environment,NWN_PARTICLE_KERNEL:'compiled'},evidence:{file:path.resolve(file),sha256:expected,sourceProject:m.project,engineSha256:m.engine.sha256,particleSha256:'672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea',preferences:{file:m.settings.file,sha256:sha(fs.readFileSync(m.settings.file))},configurationSha256:'cbee809d26508b3208c1020e359988d492a242421893e3e9c52e9524d7d4971c',renderConfiguration:configuration.summary,experiments:{baseOwner:m.experiments?.baseOwner??'original',baseTemplates:m.experiments?.baseTemplates??'original',baseReadyProbe:m.experiments?.baseReadyProbe??'ordinary',baseAdmission:m.experiments?.baseAdmission??'ordinary'},flags}};
}

export function validateReplayCapsuleOptions(capsule,arg){
 if(!capsule)return;
 if(arg('source-project')!==undefined&&path.resolve(arg('source-project'))!==capsule.sourceProject)throw Error('Replay capsule source-project override differs');
 if(arg('rendering-method')!==undefined&&arg('rendering-method')!=='forward_plus'||arg('render-thread')!==undefined&&arg('render-thread')!=='separate')throw Error('Replay capsule render policy override differs');
 // Display topology can change after a capsule is frozen. A current secondary
 // screen may be selected explicitly; native startup must verify it is nonprimary.
 if(arg('screen')!==undefined&&(!/^\d+$/.test(String(arg('screen')))||Number(arg('screen'))>31))throw Error('Invalid current replay display index');
 for(const name of ['base-scenery-owner','base-scenery-templates','base-scenery-template-probe','base-scenery-admission','shared-animation-preparation','base-scenery-stream','static-scenery','base-scenery-draw','native-draw-cache','native-draw-cache-gib','model-template'])if(arg(name)!==undefined)throw Error('Base-world experiments require a reviewed pinned capsule; command-line overrides differ');
 const locked=['render-profile','render-preferences','native-lighting','native-light-history','native-surface-output','native-postprocess-mask','native-postprocess-midpoint','native-postprocess-intensity','native-postprocess-vibrance','native-gamma','particle-random','particle-clocks','particle-pose-leases','particle-common','particle-scene-snapshot','static-emitter-route','light-input-registry','light-input-fields','particle-eligibility','particle-inputs','particle-pose-slots','generated-light-manual','drive-collision','drive-clear','static-parts','retirement-physics','material-prewarm','animation-keys','ascii-key-write','prepared-cache-write','prepared-cache-lock','ancestor-share','mesh-preparation','raster-conversion','model-float-stream','raster-cache-write','icon-model-reuse','skin-preparation','clip-preparation','ancestor-preparation','entry-prefetch'];
 for(const name of locked)if(arg(name)!==undefined)throw Error('Reviewed replay capsule fixes '+name+'; use a different reviewed capsule for another experiment');
}

// Separate current-production route. Legacy capsule policy/allowlist is unchanged.
export async function readReplayProductionSelection(file,expected,project){
 return require(path.join(project,'tools/native-production-selection.cjs')).readProductionSelection(file,expected);
}
export function validateReplayProductionOptions(selection,arg,project){
 return require(path.join(project,'tools/native-production-selection.cjs')).validateProductionReplayOptions(selection,arg);
}
