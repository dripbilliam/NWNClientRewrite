// Launch selection and file verification only. No model, texture, particle,
// world decoding or render staging is allowed in this protocol-side helper.
const fs=require('node:fs/promises'),{createReadStream}=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
async function digest(file){const hash=crypto.createHash('sha256');for await(const chunk of createReadStream(file))hash.update(chunk);return hash.digest('hex');}
async function selectInstalledNativeRuntime(project){
 const recipe=await fs.readFile(path.join(project,'client-runtime-lock.json'),'utf8');
 const recipeSha256=crypto.createHash('sha256').update(recipe.replace(/\r\n/g,'\n')).digest('hex');
 const directory=path.join(project,'.tools','client-runtime',recipeSha256);
 const executable=path.join(directory,'Godot_client_win64.exe'),buildReceipt=path.join(directory,'runtime.json');
 let build;
 try{build=JSON.parse(await fs.readFile(buildReceipt,'utf8'));}
 catch(error){
  if(error.code==='ENOENT')throw Error('The standard client engine is missing. Run godot-client/tools/setup.ps1.');
  throw error;
 }
 if(build.kind!=='native-client-runtime'||build.recipeSha256!==recipeSha256||!/^[a-f0-9]{64}$/.test(build.executableSha256)||
  await digest(executable)!==build.executableSha256)throw Error('Installed client engine does not match its build receipt.');
 return {kind:'client',executable,directory:path.dirname(project),executableSha256:build.executableSha256,requiresProjectPath:true,buildReceipt,recipeSha256};
}
async function selectCxReviewRuntime(project){
 const stage=path.join(project,'.cache/native-font-atlas/cx-font-preflight-v1');
 const buildReceipt=path.join(stage,'build.json'),buildReceiptSha256='7b76dc7bd9c449a42ae1be5a25ae357dd74e93b48329d863df3b3ef2905c2754';
 const executable=path.join(stage,'source/bin/godot.windows.template_release.x86_64.exe'),executableSha256='29fd276a6dc7cd8a647ac89b31614625e820e02a62747e41b52fe2e7c14c1766';
 const bytes=await fs.readFile(buildReceipt);
 if(crypto.createHash('sha256').update(bytes).digest('hex')!==buildReceiptSha256)throw Error('CX review engine build receipt changed');
 const build=JSON.parse(bytes);
 if(build.success!==true||build.exitCode!==0||build.executableSha256!==executableSha256||path.resolve(build.executable)!==path.resolve(executable)||await digest(executable)!==executableSha256)throw Error('CX review engine differs from the verified build');
 return{kind:'review-cx',executable,directory:path.dirname(project),executableSha256,requiresProjectPath:true,buildReceipt,buildReceiptSha256};
}
async function selectRigApplyReviewRuntime(project){
 const stage=path.join(project,'.cache/native-140fps/render-agent/engine-rd-nwn-rig-apply-release-b');
 const buildReceipt=path.join(stage,'patched.receipt.json');
 const buildReceiptSha256='d2f949263d9249af9654f5e4bda62e529a36f810d785e3d697d9e1629649dd70';
 const executable=path.join(stage,'Godot_rig_apply_patched.exe');
 const executableSha256='e18349d0080c4d95df135d5401cfa01ad2d3d280b59f260a809fff3ddc2643b6';
 const bytes=await fs.readFile(buildReceipt);
 if(crypto.createHash('sha256').update(bytes).digest('hex')!==buildReceiptSha256)throw Error('Rig review build receipt changed');
 const build=JSON.parse(bytes);
 if(build.buildExitCode!==0||build.sourceState!=='patched'||path.resolve(build.executable)!==path.resolve(executable)||
  build.executableSha256!==executableSha256||await digest(executable)!==executableSha256)throw Error('Rig review engine differs from the verified build');
 return{kind:'review-rig-apply',executable,directory:path.dirname(project),executableSha256,requiresProjectPath:true,buildReceipt,buildReceiptSha256};
}
async function selectNativeRuntime(project,kind='editor',selection,useInstalledClient=false){
 if(!['editor','release','review-cx','review-rig-apply'].includes(kind))throw Error('Invalid native engine runtime');
 if(kind==='review-rig-apply'){
  if(selection)throw Error('Rig review runtime uses its fixed build receipt');
  return selectRigApplyReviewRuntime(project);
 }
 if(kind==='review-cx'){
  if(selection)throw Error('CX review runtime uses its fixed build receipt');
  return selectCxReviewRuntime(project);
 }
 if(kind==='editor'){
  if(selection)throw Error('Editor runtime does not take a release package');
  if(useInstalledClient)return selectInstalledNativeRuntime(project);
  const executable=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
  return{kind,executable,directory:path.dirname(project),executableSha256:await digest(executable)};
 }
 if(!selection)throw Error('Release runtime requires a prepared package');
 const info=JSON.parse(await fs.readFile(selection,'utf8'));
 if(info.kind!=='native-release-package'||!/^[a-f0-9]{64}$/.test(info.sourceSignature)||!/^[a-f0-9]{64}$/.test(info.packSha256)||info.originalGameAssetsPacked!==false)throw Error('Invalid prepared release runtime receipt');
 const directory=path.join(project,'.cache/release-tests',info.sourceSignature.slice(0,16),'project');
 const executable=path.join(directory,'NwnReleaseTest.exe'),pack=path.join(directory,'NwnReleaseTest.pck');
 for(const [actual,expected]of [[info.directory,directory],[info.executable,executable],[info.pack,pack],[selection,path.join(directory,'runtime.json')]])if(path.resolve(actual).toLowerCase()!==path.resolve(expected).toLowerCase())throw Error('Release package escaped its authored cache stage');
 const executableSha256=await digest(executable);
 const installed=await selectInstalledNativeRuntime(project);
 if(executableSha256!==installed.executableSha256||await digest(pack)!==info.packSha256)throw Error('Prepared release executable or pack changed');
 return{kind,executable,directory,executableSha256,pack,packSha256:info.packSha256,sourceSignature:info.sourceSignature,receipt:info.receipt,buildReceipt:installed.buildReceipt,recipeSha256:installed.recipeSha256};
}
module.exports={selectNativeRuntime};
