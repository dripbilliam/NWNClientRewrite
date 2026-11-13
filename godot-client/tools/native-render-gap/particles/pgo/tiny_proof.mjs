import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import os from 'node:os';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../../..'),label=process.argv[2]??'tiny-a';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh proof label required');
const stage=path.join(project,'.cache/native-render-gap/particles/pgo',label);
if(fs.existsSync(stage))throw Error('Retain prior proof evidence');fs.mkdirSync(stage,{recursive:true});
os.setPriority(0,os.constants.priority.PRIORITY_BELOW_NORMAL);
const compiler=path.join(project,'.cache/native-text-build/compiler/w64devkit/bin/x86_64-w64-mingw32-g++.exe'),bin=path.dirname(compiler),ar=path.join(bin,'x86_64-w64-mingw32-ar.exe'),nm=path.join(bin,'x86_64-w64-mingw32-nm.exe'),dump=path.join(bin,'x86_64-w64-mingw32-gcov-dump.exe');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),portable=file=>file.replaceAll('\\','/'),steps=[];
if(hash(compiler)!=='03e15580dda29518716dc6f6840d5ea055f526ddc8f59f14192b8d3e3eeea622')throw Error('Pinned compiler drift');
const source=path.join(stage,'source');fs.mkdirSync(source);for(const name of ['probe_core.cpp','probe_main.cpp'])fs.copyFileSync(path.join(here,name),path.join(source,name));
const pins=['probe_core.cpp','probe_main.cpp'].map(name=>({file:path.join(source,name),sha256:hash(path.join(source,name))}));
function run(name,tool,args,expected=0){
 const started=Date.now(),result=spawnSync(tool,args,{cwd:stage,windowsHide:true,encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024});
 fs.writeFileSync(path.join(stage,name+'.stdout.log'),result.stdout??'');fs.writeFileSync(path.join(stage,name+'.stderr.log'),result.stderr??'');
 const row={name,tool,args,exit:result.status,signal:result.signal,wallMs:Date.now()-started,expected};steps.push(row);
 if(result.status!==expected)throw Error('Unexpected result at '+name+': '+result.status+' '+(result.stderr??'').slice(0,500));
 return result;
}
function directory(name){const result=path.join(stage,name);fs.mkdirSync(result,{recursive:true});return result;}
const strict=['-O3','-std=c++17','-ffp-contract=off','-fno-fast-math'],scratch=directory('scratch'),scratchObject=path.join(scratch,'probe_core.o'),mainObject=path.join(stage,'probe_main.o');
let summary;
try{
 const lib=run('runtime-path',compiler,['-print-file-name=libgcov.a']).stdout.trim();if(!fs.existsSync(lib))throw Error('libgcov is not present');
 const version=run('version',compiler,['-v']);
 run('main',compiler,[...strict,'-c',portable(path.join(source,'probe_main.cpp')),'-o',portable(mainObject)]);
 const controlRoot=directory('control'),controlObject=path.join(directory('control/objects'),'probe_core.o');
 run('control-compile',compiler,[...strict,'-c',portable(path.join(source,'probe_core.cpp')),'-o',portable(controlObject)]);
 function archive(name,root,object){const archive=path.join(root,'libprobe.a');run(name+'-archive',ar,['rcsD',portable(archive),portable(object)]);const bytes=fs.readFileSync(archive);if(bytes.subarray(0,8).toString()!=='!<arch>\n')throw Error('Archive is not normal');let member=null;for(let at=8;at+60<=bytes.length;){const header=bytes.toString('ascii',at,at+60),length=Number(header.slice(48,58).trim()),memberName=header.slice(0,16).trim().replace(/\/$/,'');if(memberName==='probe_core.o')member=bytes.subarray(at+60,at+60+length);at+=60+length+(length&1);}if(!member||crypto.createHash('sha256').update(member).digest('hex')!==hash(object))throw Error('Raw archive member differs');return archive;}
 function link(name,root,archive,extra=[]){const exe=path.join(root,'probe.exe');run(name+'-link',compiler,[...strict,portable(mainObject),portable(archive),...extra,'-static','-o',portable(exe)]);return exe;}
 const controlArchive=archive('control',controlRoot,controlObject),control=link('control',controlRoot,controlArchive);
 const generateRoot=directory('generate'),generateObjects=directory('generate/objects'),generateObject=path.join(generateObjects,'probe_core.o');
 const generateFlags=['-fprofile-generate','-fprofile-update=atomic'];
 run('generate-compile',compiler,[...strict,...generateFlags,'-c',portable(path.join(source,'probe_core.cpp')),'-o',portable(scratchObject)]);fs.copyFileSync(scratchObject,generateObject);
 const generateArchive=archive('generate',generateRoot,generateObject),generate=link('generate',generateRoot,generateArchive,['-fprofile-generate']);
 const workloads=[['0','200000','12345'],['1','50000','76543']];const outputs=[];
 for(let n=0;n<workloads.length;++n){const baseline=run('train-'+n+'-control',control,workloads[n]),instrumented=run('train-'+n+'-generate',generate,workloads[n]);if(baseline.stdout!==instrumented.stdout||instrumented.stderr)throw Error('Instrumented integer output/log differs');outputs.push({args:workloads[n],stdout:baseline.stdout.trim()});}
 const profiles=fs.readdirSync(scratch).filter(name=>name.endsWith('.gcda')).map(name=>({file:path.join(scratch,name),bytes:fs.statSync(path.join(scratch,name)).size,sha256:hash(path.join(scratch,name))}));if(profiles.length!==1||!profiles[0].bytes)throw Error('Expected one nonempty actual profile');
 run('gcda-dump',dump,['-l',profiles[0].file]);
 const useRoot=directory('use'),useObjects=directory('use/objects'),useObject=path.join(useObjects,'probe_core.o');
 const useFlags=['-fprofile-use','-fprofile-partial-training','-Werror=missing-profile','-Werror=coverage-mismatch'];
 run('use-compile',compiler,[...strict,...useFlags,'-c',portable(path.join(source,'probe_core.cpp')),'-o',portable(scratchObject)]);fs.copyFileSync(scratchObject,useObject);
 const useArchive=archive('use',useRoot,useObject),use=link('use',useRoot,useArchive);
 for(const args of [...workloads,['0','1','0'],['1','10000','4294967295'],['9','3000','13579']]){const baseline=run('verify-'+outputs.length+'-control',control,args),optimized=run('verify-'+outputs.length+'-use',use,args);if(baseline.stdout!==optimized.stdout||optimized.stderr)throw Error('Profile-use integer output/log differs');outputs.push({args,stdout:baseline.stdout.trim()});}
 const wrongObjects=directory('wrong-name/objects');const missing=run('missing-profile-negative',compiler,[...strict,'-fprofile-use','-Werror=missing-profile','-Werror=coverage-mismatch','-c',portable(path.join(source,'probe_core.cpp')),'-o',portable(path.join(wrongObjects,'wrong_core.o'))],1);if(!/missing-profile/.test(missing.stderr))throw Error('Wrong-object test did not reject missing profile');
 const mismatch=run('coverage-mismatch-negative',compiler,[...strict,'-DPROOF_EXTRA_BRANCH=1','-fprofile-use','-Werror=missing-profile','-Werror=coverage-mismatch','-c',portable(path.join(source,'probe_core.cpp')),'-o',portable(scratchObject)],1);if(!/coverage-mismatch/.test(mismatch.stderr))throw Error('Changed-CFG test did not reject profile checksum');
 const afterRoot=directory('control-after'),afterArchive=archive('control-after',afterRoot,controlObject),after=link('control-after',afterRoot,afterArchive);
 if(hash(control)!==hash(after)||hash(controlArchive)!==hash(afterArchive))throw Error('Whole normal-archive control proof differs');
 const undef=run('use-symbols',nm,['-u',useObject]).stdout;if(/gcov/.test(undef))throw Error('Profile-use object still references instrumentation runtime');
 for(const entry of profiles)if(hash(entry.file)!==entry.sha256)throw Error('Use/negative checks mutated frozen profile data');for(const pin of pins)if(hash(pin.file)!==pin.sha256)throw Error('Pinned probe source changed');
 const controlOptions=run('control-options',compiler,[...strict,'-Q','--help=optimizers']).stdout,useOptions=run('use-options',compiler,[...strict,'-fprofile-use','-fprofile-partial-training','-Q','--help=optimizers']).stdout;
 const selected=text=>text.split(/\r?\n/).filter(line=>/-f(?:unsafe-math|associative-math|finite-math|reciprocal-math|signed-zeros|trapping-math|fp-contract)/.test(line));
 if(JSON.stringify(selected(controlOptions))!==JSON.stringify(selected(useOptions)))throw Error('Strict floating-point option state changed');
 summary={success:true,compiler,compilerSha256:hash(compiler),libgcov:lib,libgcovSha256:hash(lib),libgcovBytes:fs.statSync(lib).size,configuredDisableLto:version.stderr.includes('--disable-lto'),profiles,outputs,sourcePins:pins,steps,normalArchiveControlSha256:hash(controlArchive),wholeControlExeSha256:hash(control),wholeControlBeforeAfterIdentical:true,generatedExeSha256:hash(generate),useExeSha256:hash(use),useCoreObjectSha256:hash(useObject),controlCoreObjectSha256:hash(controlObject),strictFpOptions:selected(useOptions),missingProfileRejected:true,coverageMismatchRejected:true,profilePathRelocationProven:false,fixedPrivateObjectPathProven:true,profileDataUnchangedByUse:true,instrumentedScope:'One integer-only archive member; generation/use share one mutable PRIVATE scratch object path, with separate immutable copied objects/normal archives; common main and all engine files uninstrumented/untouched',scope:'Capability/correctness witness only, no engine/GPU/FPS performance claim'};
}catch(error){summary={success:false,error:error.stack,sourcePins:pins,steps,scope:'Private tiny proof failure retained; no engine files modified'};}
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(summary,null,2)+'\n');console.log(JSON.stringify({stage,success:summary.success,error:summary.error,profiles:summary.profiles,steps:steps.length,scope:summary.scope},null,2));if(!summary.success)process.exitCode=1;
