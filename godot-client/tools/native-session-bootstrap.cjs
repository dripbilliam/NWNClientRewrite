// Temporary protected-settings broker. There is no BrowserWindow, renderer,
// scene preparation or game asset decoding in this process.
const {app,safeStorage}=require('electron'),path=require('node:path'),fs=require('node:fs/promises'),{spawn}=require('node:child_process');
app.setName('nwn-model-viewer-research');
app.whenReady().then(async()=>{
 const {ClientSettings,defaultModsDirectory}=await import('../../electron/client_settings.mjs');
 const project=path.resolve(__dirname,'..'),root=path.dirname(project),settingsDirectory=app.getPath('userData'),install=path.resolve(root,'../FullDecomp/NwnRootInstall');
 const settings=new ClientSettings({directory:settingsDirectory,encryption:safeStorage,modsDirectory:await defaultModsDirectory(install)});
 const loginPipe=process.argv.find(value=>value.startsWith('--private-login-pipe='))?.slice(21);
 let privateTestKey='';
 if(loginPipe){
  const privateLogin=require('./private-login.cjs'),input=privateLogin.connectPrivatePipe(loginPipe);
  if(['--action-check','--local-check','--creation-check','--script-floating-check','--script-floating-visual','--direct-handoff-check'].some(flag=>process.argv.includes(flag)))privateTestKey=await privateLogin.readPrivateKey(input);
  else await privateLogin.savePrivateLogin(input,settings);
 }
 const partnerPipe=process.argv.find(value=>value.startsWith('--barter-peer-key-pipe='))?.slice('--barter-peer-key-pipe='.length);
 let barterPeerCdKey='';
 if(partnerPipe){
  if(!process.argv.includes('--action-check')||!process.argv.includes('--action-barter-check')&&!process.argv.includes('--action-lobby-pages-check'))throw Error('Participant credentials require an owned two-participant test');
  const privateLogin=require('./private-login.cjs');barterPeerCdKey=await privateLogin.readPrivateKey(privateLogin.connectPrivatePipe(partnerPipe));
 }
 const status=await settings.status();
 let userDirectory;for(const name of ['Neverwinter Nights.0','Neverwinter Nights']){const candidate=path.join(app.getPath('documents'),name);try{await fs.access(path.join(candidate,'nwsync/nwsyncmeta.sqlite3'));userDirectory=candidate;break;}catch{}}
 userDirectory??=path.join(app.getPath('documents'),'Neverwinter Nights');
 const args=process.argv.slice(2);let cdKey=privateTestKey;privateTestKey='';
 const child=spawn('node',[path.join(__dirname,'native-session-host.cjs'),...args],{cwd:root,windowsHide:true,stdio:['pipe','inherit','inherit','ipc']});
 const removeBroker=require('./settings-broker.cjs').installSettingsBroker(child,settings);child.once('exit',removeBroker);
 child.once('error',()=>app.exit(1));child.once('exit',code=>app.exit(code??1));
 const bytes=Buffer.from(JSON.stringify({settingsDirectory,userDirectory,settings:status,cdKey,barterPeerCdKey}));cdKey='';barterPeerCdKey='';child.stdin.end(bytes,()=>bytes.fill(0));
}).catch(()=>app.exit(1));
