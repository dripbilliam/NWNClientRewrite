// Launch selection and file verification only. No model, texture, particle,
// world decoding or render staging is allowed in this protocol-side helper.
const fs=require('node:fs/promises'),{createReadStream}=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
async function digest(file){const hash=crypto.createHash('sha256');for await(const chunk of createReadStream(file))hash.update(chunk);return hash.digest('hex');}
async function selectNativeRuntime(project,kind='editor',selection){
 if(!['editor','release'].includes(kind))throw Error('Invalid native engine runtime');
 if(kind==='editor'){
  if(selection)throw Error('Editor runtime does not take a release package');
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
 if(executableSha256!=='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'||await digest(pack)!==info.packSha256)throw Error('Prepared release executable or pack changed');
 return{kind,executable,directory,executableSha256,pack,packSha256:info.packSha256,sourceSignature:info.sourceSignature,receipt:info.receipt};
}
module.exports={selectNativeRuntime};
