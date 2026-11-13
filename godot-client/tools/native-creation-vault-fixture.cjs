'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'..'),workspace=path.dirname(project),prefix=path.join(project,'.cache/creation-full-vault-tests');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const SERVER='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6';
function owned(directory){const value=path.resolve(directory);if(!value.startsWith(prefix+path.sep)||path.basename(value)!=='server')throw Error('Creation vault fixture must use a new explicit owned server directory');return value;}
async function prepare(directory){
 const home=owned(directory),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall'),server=path.join(install,'bin/win32/nwserver.exe'),module=path.join(install,'data/nwm/Prelude.nwm');
 if(digest(await fs.readFile(server))!==SERVER)throw Error('Unexpected original server');
 await fs.mkdir(path.dirname(home),{recursive:true});await fs.mkdir(home);
 const settings='[ruleset]\nenforce-legal-characters = true\n[server.identity]\nname = "Owned Native Creation Vault"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n';
 await fs.writeFile(path.join(home,'settings.tml'),settings,{flag:'wx'});
 const value={version:1,kind:'owned-native-first-level-vault',nonce:crypto.randomUUID(),directory:home,port:5129,module:'Prelude',modulePath:module,moduleSha256:digest(await fs.readFile(module)),serverPath:server,serverSha256:SERVER,serverVault:true,public:false,maxClients:1,enforceLegal:true,createdAtUtc:new Date().toISOString()};
 const bytes=JSON.stringify(value,null,2)+'\n';await fs.writeFile(path.join(home,'fixture.json'),bytes,{flag:'wx'});return {...value,descriptorSha256:digest(bytes)};
}
async function read(directory){
 const home=owned(directory),bytes=await fs.readFile(path.join(home,'fixture.json'));if(bytes.length>16384)throw Error('Creation fixture descriptor exceeds bound');const value=JSON.parse(bytes);
 if(value.version!==1||value.kind!=='owned-native-first-level-vault'||value.directory!==home||value.port!==5129||value.module!=='Prelude'||value.serverVault!==true||value.public!==false||value.maxClients!==1||value.enforceLegal!==true||value.serverSha256!==SERVER||value.serverPath!==path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe')||value.modulePath!==path.resolve(workspace,'../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'))throw Error('Creation fixture ownership/endpoint differs');
 if(digest(await fs.readFile(value.serverPath))!==SERVER||digest(await fs.readFile(value.modulePath))!==value.moduleSha256)throw Error('Original fixture inputs changed');return {...value,descriptorSha256:digest(bytes)};
}
async function pin(directory){const fixture=await read(directory),sourcePath=path.join(fixture.directory,'logs/nwengineLog.txt'),bytes=await fs.readFile(sourcePath);if(bytes.length>16*1024*1024)throw Error('Owned server log exceeds bound');const value=bytes.toString().match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!value)throw Error('Owned server identity is not ready');return {pin:value,sourcePath,fileSha256:digest(bytes),identitySha256:digest(value),descriptorSha256:fixture.descriptorSha256};}
module.exports={prepare,read,pin};
if(require.main===module){const directory=process.argv[2];prepare(directory).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exitCode=1;});}
