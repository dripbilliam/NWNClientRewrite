'use strict';
// Exact accepted combined-b source closure plus two private, opt-in headers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const label=process.argv[2]||'source-pose-candidate-c';assert(/^source-pose-candidate-[a-z]$/.test(label));
const directory=path.join(root,'.cache/nwn64',label);
const overlaySource=path.join(root,'.cache/nwn64/source-pose-candidate-b');
const accepted=path.join(root,'.cache/native-render-gap/particles/combined-b/kernel-project');
const project=path.join(directory,'project');
const manifestFile=path.join(root,'.cache/native-kernel/build-manifest.json');
const manifest=JSON.parse(fs.readFileSync(manifestFile));
const changed=new Set(['native/particle_resident.hpp','native/particle_presentation.hpp']);
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function file(base,relative){assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(x=>!x||x==='.'||x==='..'));return path.join(base,relative);}
function main(){
 assert(!fs.existsSync(project),'Fresh private source project required');
 assert.equal(manifest.binarySha256,'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
 assert.equal(sha(file(root,'.cache/native-kernel/nwn-particle-kernel.dll')),manifest.binarySha256);
 const rows=[];fs.mkdirSync(project,{recursive:true});
 for(const [relative,expected] of Object.entries(manifest.sources)){
  if(!relative.startsWith('native/'))continue;
  const src=file(accepted,relative);assert.equal(sha(src),expected,'Accepted source changed '+relative);
  const overlay=file(overlaySource,relative),from=changed.has(relative)?overlay:src;
  assert(fs.existsSync(from),'Missing private overlay '+relative);
  const dest=file(project,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(from,dest,fs.constants.COPYFILE_EXCL);
  const actual=sha(dest);assert.equal(actual,sha(from));
  if(!changed.has(relative))assert.equal(actual,expected);
  else assert.notEqual(actual,expected,'Opt-in candidate did not change '+relative);
  rows.push({relative,beforeSha256:expected,afterSha256:actual,changed:changed.has(relative)});
 }
 assert.equal(rows.filter(x=>x.changed).length,2);
 const fixture='tests/nwn64_source_pose_reuse_test.gd';
 const output={version:1,issue:'NWN-64',private:true,accepted:false,production:false,acceptedManifest:{file:manifestFile,sha256:sha(manifestFile)},acceptedDll:{file:file(root,'.cache/native-kernel/nwn-particle-kernel.dll'),sha256:manifest.binarySha256},acceptedEngine:{file:file(root,'.tools/native-core/Godot_native_core_e_win64.exe'),sha256:'753b3e188068efaf865bda3abd6322ebE44e3a98ef2f5d199c8af1a78624c98b'.toLowerCase()},project,sourceRows:rows,changed:[...changed],fixture:{file:file(root,fixture),sha256:sha(file(root,fixture))},flag:'source_pose_reuse true in NwnParticlePresentation frame input; default absent/off',scope:'Exact accepted combined-b native source with two private header changes. No build, Godot test, accepted DLL/engine or production source mutation.'};
 const out=file(directory,'source-plan.json');fs.writeFileSync(out,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file:out,sha256:sha(out),sourceFiles:rows.length,changed:rows.filter(x=>x.changed),fixture:output.fixture,acceptedDll:output.acceptedDll.sha256}));
}
main();
