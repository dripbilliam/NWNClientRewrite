// Isolated real Windows protection + inherited IPC round trip. No game launch,
// user settings mutation, real licence key, or server connection.
const {app,safeStorage}=require('electron'),fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process');
app.setName('nwn-login-profile-fixture');app.disableHardwareAcceleration();
app.whenReady().then(async()=>{
 const project=path.resolve(__dirname,'..'),run=process.argv.find(a=>a.startsWith('--run='))?.slice(6);if(!/^[a-z0-9-]+$/.test(run??''))throw Error('Invalid fixture run');
 const output=path.join(project,'reports',run+'.json'),directory=path.join(project,'reports',run+'.store');
 try{await fs.access(output);throw Error('Fixture output already exists');}catch(error){if(error.code!=='ENOENT')throw error;}
 await fs.mkdir(directory);const {ClientSettings}=await import('../../electron/client_settings.mjs'),store=new ClientSettings({directory,encryption:safeStorage});
 const sources={};for(const file of ['tools/check-login-profiles.cjs','tools/check-login-profiles-child.cjs','tools/settings-broker.cjs','tools/settings-client.cjs','../electron/client_settings.mjs'])sources[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex');
 let childResult;const child=spawn('node',[path.join(__dirname,'check-login-profiles-child.cjs')],{cwd:path.dirname(project),windowsHide:true,stdio:['ignore','ignore','ignore','ipc']});
 const remove=require('./settings-broker.cjs').installSettingsBroker(child,store);child.on('message',m=>{if(m?.kind==='login-profile-check')childResult=m;});
 const code=await new Promise((resolve,reject)=>{child.once('error',()=>reject(Error('Fixture child failed')));child.once('exit',resolve);});remove();
 const reopened=new ClientSettings({directory,encryption:safeStorage}),status=await reopened.status(),key=Array(7).fill('AAAAA').join('-'),disk=await fs.readFile(path.join(directory,'client-settings.json'),'utf8');
 const selected=status.loginProfiles.find(p=>p.id===status.activeProfileId);const success=code===0&&childResult?.success===true&&status.protectedStorageAvailable&&status.loginProfiles.length===2&&selected?.playerName==='Main Test Player'&&await reopened.cdKey()===key&&!disk.includes(key)&&!disk.includes(key.replaceAll('A','B'));
 let unchanged=true;for(const [file,hash]of Object.entries(sources))if(crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex')!==hash)unchanged=false;
 await fs.writeFile(output,JSON.stringify({success:success&&unchanged,protectedStorageAvailable:status.protectedStorageAvailable,profiles:status.loginProfiles.length,persistentPairMatched:success,inheritedIpc:true,publicConnections:0,realCredentialsUsed:false,userSettingsChanged:false,sourceUnchanged:unchanged,sourceSha256:sources},null,2)+'\n',{flag:'wx'});app.exit(success&&unchanged?0:1);
}).catch(()=>app.exit(1));
