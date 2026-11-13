const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const {selectPerformanceRuntime,resolveRenderThread}=require('../tools/native-performance-runtime.cjs');
test('standard delegates without touching a project or release package',async()=>{assert.equal(await selectPerformanceRuntime('missing.invalid'),null);assert.equal(await selectPerformanceRuntime(null,'standard'),null);});
test('invalid runtime rejects without filesystem access',async()=>{for(const value of ['','editor','release','VERIFIED-NATIVE',false,null])await assert.rejects(selectPerformanceRuntime('missing.invalid',value),/Invalid/);});
test('default thread selection emits no engine arguments',()=>assert.deepEqual(resolveRenderThread().arguments,[]));
test('safe and separate are exact engine arguments, not user flags',()=>{for(const mode of ['safe','separate'])assert.deepEqual(resolveRenderThread(mode).arguments,['--render-thread',mode]);});
test('thread selection rejects unsupported and malformed values',()=>{for(const value of ['','unsafe','Separate','--safe',false,null])assert.throws(()=>resolveRenderThread(value),/Invalid/);});
test('thread configuration is detached across calls',()=>{const a=resolveRenderThread('separate');a.arguments.length=0;a.requested='changed';assert.deepEqual(resolveRenderThread('separate').arguments,['--render-thread','separate']);});
test('missing or changed executable rejects without fallback or package use',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-runtime-config-'));
 // The fixture is deliberately tiny, so wrong contents reject before hashing 90 MB.
 const file=path.join(root,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/build-1793998835313/binaries/godot.windows.template_release.x86_64.exe');
 await assert.rejects(selectPerformanceRuntime(root,'verified-native'),/ENOENT/);await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,'untrusted tiny fixture');
 await assert.rejects(selectPerformanceRuntime(root,'verified-native'),/size changed/);
 // Remove only exact files/directories this fixture created, never an arbitrary tree.
 await fs.unlink(file);let directory=path.dirname(file);while(directory!==root){await fs.rmdir(directory);directory=path.dirname(directory);}await fs.rmdir(root);
});
test('reviewed existing executable selects current scripts with explicit capabilities',async()=>{
 const project=path.resolve(__dirname,'..'),r=await selectPerformanceRuntime(project,'verified-native');
 assert.equal(r.kind,'verified-native');assert.equal(r.executableSha256,'62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc');assert.equal(r.requiresProjectPath,true);assert.equal(r.directory,path.dirname(project));assert.equal(r.pack,undefined);assert.equal(r.sourceSignature,undefined);
 assert.ok(r.expectedCapabilities.some(c=>c.class==='NwnBuiltinLightInputRegistry'&&c.operations.join(',')==='0,1,2,3,4,8'));assert.equal(r.selectionEvidence.pathOverridesEnabled,true);
 assert.deepEqual(r.requiredProjectFiles.map(row=>row.relative),['project.godot','.godot/global_script_class_cache.cfg']);assert.ok(r.requiredProjectFiles.every(row=>/^[a-f0-9]{64}$/.test(row.sha256)));
 r.expectedCapabilities[0].methods.length=0;r.selectionEvidence.engineVersion.major=0;
 const second=await selectPerformanceRuntime(project,'verified-native');assert.equal(second.expectedCapabilities[0].methods.length,1);assert.equal(second.selectionEvidence.engineVersion.major,4);
 // Selection remains separate from the existing ordinary/release package owner.
 const source=await fs.readFile(path.join(project,'tools/native-performance-runtime.cjs'),'utf8');assert.doesNotMatch(source,/spawn\(|exec\(|BrowserWindow|selectNativeRuntime\(/);
});
