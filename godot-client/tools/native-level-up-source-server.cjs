'use strict';
// File-only preparation/validation. This module never starts a process, acquires
// a key or logs a server's cryptographic identity/secret.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'..'),workspace=path.dirname(project),prefix=path.join(project,'.cache/level-up-source-authority');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const SERVER='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6';
function owned(directory){const home=path.resolve(directory);if(!home.startsWith(prefix+path.sep)||path.basename(home)!=='server'||!/^native-level-up-source-[a-z0-9-]+$/.test(path.basename(path.dirname(home))))throw Error('Explicit unused level-up source fixture directory required');return home;}
async function prepare(directory){
 const home=owned(directory),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall'),serverPath=path.join(install,'bin/win32/nwserver.exe'),modulePath=path.join(install,'data/nwm/Prelude.nwm');
 if(digest(await fs.readFile(serverPath))!==SERVER)throw Error('Unexpected original server');
 await fs.mkdir(path.dirname(home),{recursive:true});await fs.mkdir(home);
 await fs.writeFile(path.join(home,'settings.tml'),'[ruleset]\nenforce-legal-characters = true\n[server.identity]\nname = "Owned Native Source Level Up"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n',{flag:'wx'});
 const value={version:1,kind:'owned-native-source-level-up',nonce:crypto.randomUUID(),directory:home,port:5129,module:'Prelude',modulePath,moduleSha256:digest(await fs.readFile(modulePath)),serverPath,serverSha256:SERVER,serverVault:false,public:false,maxClients:1,enforceLegal:true,baseResourcePolicy:true,createdAtUtc:new Date().toISOString()};
 const bytes=JSON.stringify(value,null,2)+'\n';await fs.writeFile(path.join(home,'fixture.json'),bytes,{flag:'wx'});return {...value,descriptorSha256:digest(bytes)};
}
async function read(directory){
 const home=owned(directory),bytes=await fs.readFile(path.join(home,'fixture.json'));if(bytes.length>16384)throw Error('Level-up fixture descriptor exceeds bound');const value=JSON.parse(bytes),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
 if(value.version!==1||value.kind!=='owned-native-source-level-up'||value.directory!==home||value.port!==5129||value.module!=='Prelude'||value.serverVault!==false||value.public!==false||value.maxClients!==1||value.enforceLegal!==true||value.baseResourcePolicy!==true||value.serverSha256!==SERVER||value.serverPath!==path.join(install,'bin/win32/nwserver.exe')||value.modulePath!==path.join(install,'data/nwm/Prelude.nwm'))throw Error('Owned level-up fixture identity/rules differ');
 if(digest(await fs.readFile(value.serverPath))!==SERVER||digest(await fs.readFile(value.modulePath))!==value.moduleSha256)throw Error('Original level-up fixture inputs changed');return {...value,descriptorSha256:digest(bytes)};
}
async function pin(directory){
 const fixture=await read(directory),sourcePath=path.join(fixture.directory,'logs/nwengineLog.txt'),handle=await fs.open(sourcePath,'r');let bytes;
 try{const buffer=Buffer.alloc(16*1024*1024+1);let used=0;while(used<buffer.length){const next=await handle.read(buffer,used,Math.min(65536,buffer.length-used),null);if(!next.bytesRead)break;used+=next.bytesRead;}if(used>16*1024*1024)throw Error('Owned level-up log exceeds16MiB');bytes=buffer.subarray(0,used);}finally{await handle.close();}
 const value=[...bytes.toString().matchAll(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/g)].at(-1)?.[1];if(!value)throw Error('Fresh owned level-up server identity is unavailable');return {pin:value,sourcePath,fileSha256:digest(bytes),identitySha256:digest(value),descriptorSha256:fixture.descriptorSha256};
}
module.exports={owned,prepare,read,pin};
if(require.main===module)prepare(process.argv[2]).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exitCode=1;});
