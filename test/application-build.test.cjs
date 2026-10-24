const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {resolveApplicationBuild}=require('../electron/application_build.cjs');
test('normal launch retains the original dist document and URL',()=>{
 const result=resolveApplicationBuild('C:/fixture',[]);assert.equal(result.directory,path.resolve('C:/fixture/dist'));assert.equal(result.experimental,false);assert.ok(result.applicationUrl.endsWith('/dist/index.html'));
});
test('explicit test build must be one owned, existing performance entry document',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'nwn-application-build-test-'));
 try{
  const selected=path.join(root,'backups/animations/performance-queue/run/diagnostic-build');fs.mkdirSync(selected,{recursive:true});fs.writeFileSync(path.join(selected,'index.html'),'<!doctype html>');
  const result=resolveApplicationBuild(root,['--client-build='+selected]);assert.equal(result.experimental,true);assert.equal(result.directory,fs.realpathSync(selected));
  for(const args of [['--client-build='+root],['--client-build=missing'],['--client-build='+selected,'--client-build='+selected]])assert.throws(()=>resolveApplicationBuild(root,args));
 }finally{const target=fs.realpathSync(root),parent=fs.realpathSync(os.tmpdir());assert.equal(path.dirname(target).toLowerCase(),parent.toLowerCase());assert.ok(path.basename(target).startsWith('nwn-application-build-test-'));fs.rmSync(target,{recursive:true,force:true});}
});
