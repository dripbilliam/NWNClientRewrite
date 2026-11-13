'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),out=path.join(project,'.cache/native-cache-directory/fix-a/checks-a');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
async function main(){
 assert(!fs.existsSync(out),'Keep prior checks');
 const runtime=await require('../native-performance-runtime.cjs').selectPerformanceRuntime(project,'verified-native');
 fs.mkdirSync(out);fs.copyFileSync(__filename,path.join(out,'executor.cjs'),fs.constants.COPYFILE_EXCL);
 const before=read(path.join(project,'.cache/native-cache-directory/fix-a/before-identity.json'));
 const identity=require('../native-feature-manifest.cjs').sourceIdentity(project);
 const pins=new Map(before.files.map(x=>[x.file,x.sha256]));
 const changed=identity.files.filter(x=>pins.get(x.file)!==x.sha256);assert.deepEqual(changed.map(x=>x.file),['systems/native_data/prepared_cache.gd']);
 assert.equal(sha(path.join(project,'systems/native_data/prepared_write_queue.gd')),sha(path.join(project,'.cache/native-cache-directory/fix-a/prepared_write_queue.before.gd')));
 const results=[];
 for(const script of ['native_cache_directory_reuse_test.gd','native_prepared_cache_test.gd','native_cache_publication_paths_test.gd','native_prepared_write_queue_test.gd']){
  const directory=path.join(out,script.replace('.gd',''));fs.mkdirSync(directory);
  for(const name of ['appdata','localappdata'])fs.mkdirSync(path.join(directory,name));
  const report=path.join(directory,'report.json');
  const args=['--headless','--path',project,'--log-file',path.join(directory,'engine.log'),'--script','res://tests/'+script,'--','--report='+report,'--entity-api-rest=false'];
  const r=spawnSync(runtime.executable,args,{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:16*1024*1024,env:{...process.env,APPDATA:path.join(directory,'appdata'),LOCALAPPDATA:path.join(directory,'localappdata')}});
  fs.writeFileSync(path.join(directory,'stdout.log'),r.stdout||'',{flag:'wx'});fs.writeFileSync(path.join(directory,'stderr.log'),r.stderr||'',{flag:'wx'});
  const native=fs.existsSync(report)?read(report):null,errors=/SCRIPT ERROR|ERROR:|FATAL:|leaked|still in use|crash handler/i.test((r.stdout||'')+'\n'+(r.stderr||''));
  const result={script,success:r.status===0&&!r.error&&!errors&&native?.success===true,exit:r.status,error:r.error?.message,errors,command:[runtime.executable,...args],testSha256:sha(path.join(project,'tests',script)),native};
  fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});results.push(result);
  console.log(JSON.stringify({script,success:result.success,exit:r.status,checks:native?.checks,failures:native?.failures}));
  if(!result.success)break;
 }
 assert.equal(require('../native-feature-manifest.cjs').sourceIdentity(project).sha256,identity.sha256);
 const receipt={version:1,success:results.length===4&&results.every(x=>x.success),createdUtc:new Date().toISOString(),beforeSource:before.sha256,afterSource:identity.sha256,engine:{file:runtime.executable,sha256:runtime.executableSha256},changed:changed.map(x=>({...x,beforeSha256:pins.get(x.file)})),results,scope:'Actual accepted normal engine, local headless cache filesystem/concurrency/corruption/queue checks. No native binary rebuild, GUI, public server or FPS test.'};
 fs.writeFileSync(path.join(out,'acceptance.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});assert(receipt.success,'Native cache acceptance failed; preserve outputs');
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
