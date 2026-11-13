'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const label=process.argv[2];assert(/^[a-z0-9-]+$/.test(label||''));
const out=path.join(project,'.cache/native-render-gap/original/local-authority','protected-broker-smoke-'+label);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const entry=path.join(out,'mock-entry.cjs'),configFile=path.join(out,'config.json');
const config={version:1,out,run:'protected-broker-only-smoke',bootstrap:entry,host:path.join(project,'tools/native-session-host.cjs'),userdata:path.join(out,'working-settings'),userdir:path.join(out,'working-userdir'),appdata:path.join(out,'working-appdata'),localappdata:path.join(out,'working-localappdata')};
fs.writeFileSync(configFile,JSON.stringify(config,null,2)+'\n',{flag:'wx'});
const settingsUrl=require('node:url').pathToFileURL(path.join(project,'../electron/client_settings.mjs')).href;
const code=`'use strict';
const fs=require('node:fs'),path=require('node:path'),{app,safeStorage,BrowserWindow}=require('electron');
const config=JSON.parse(fs.readFileSync(process.env.NWN_NORMAL_FRONTEND_CONFIG));
app.whenReady().then(async()=>{
 const {ClientSettings}=await import(${JSON.stringify(settingsUrl)});
 const settings=new ClientSettings({directory:config.userdata,encryption:safeStorage});
 const status=await settings.status();let unlocked=false;
 if(status.hasSavedCdKey){let key=await settings.cdKey();unlocked=/^[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}$/.test(key);key='';}
 const value={version:1,success:unlocked&&BrowserWindow.getAllWindows().length===0,userDataPrivate:path.resolve(app.getPath('userData'))===path.resolve(config.userdata),sessionDataPrivate:path.resolve(app.getPath('sessionData'))===path.resolve(config.userdata),protectedKeyAvailable:status.hasSavedCdKey,protectedStorageAvailable:status.protectedStorageAvailable,protectedKeyUnlocked:unlocked,windows:BrowserWindow.getAllWindows().length,hostStarted:false,nativeStarted:false,serverStarted:false,network:false};
 value.success=value.success&&value.userDataPrivate&&value.sessionDataPrivate;
 fs.writeFileSync(path.join(config.out,'native.json'),JSON.stringify(value,null,2)+'\\n',{flag:'wx'});app.exit(value.success?0:1);
}).catch(()=>{fs.writeFileSync(path.join(config.out,'native.json'),JSON.stringify({version:1,success:false,error:'Protected broker unlock failed; no secret material recorded'})+'\\n',{flag:'wx'});app.exit(1);});
`;
fs.writeFileSync(entry,code,{flag:'wx'});
const executable=path.join(project,'../node_modules/electron/dist/electron.exe'),preload=path.join(__dirname,'bootstrap-preload.cjs');
const env={...process.env,NWN_NORMAL_FRONTEND_CONFIG:configFile,NODE_OPTIONS:'--require="'+preload.replaceAll('\\','/')+'"'};delete env.ELECTRON_RUN_AS_NODE;
const started=Date.now(),result=cp.spawnSync(executable,[entry],{cwd:path.dirname(project),encoding:'utf8',windowsHide:true,env,timeout:15000,maxBuffer:1024*1024});
fs.writeFileSync(path.join(out,'stdout.log'),result.stdout||'',{flag:'wx'});fs.writeFileSync(path.join(out,'stderr.log'),result.stderr||'',{flag:'wx'});
let native;try{native=JSON.parse(fs.readFileSync(path.join(out,'native.json')));}catch{}
const copies=JSON.parse(fs.readFileSync(path.join(out,'settings-copies.json'))).copies;
const originalSettingsUnchanged=copies.every(row=>sha(fs.readFileSync(row.source))===row.sha256);
const receipt={version:1,success:result.status===0&&native?.success&&originalSettingsUnchanged,exit:result.status,error:result.error?.message,wallMs:Date.now()-started,executableSha256:sha(fs.readFileSync(executable)),preloadSha256:sha(fs.readFileSync(preload)),entrySha256:sha(Buffer.from(code)),originalSettingsUnchanged,native,scope:'Windowless existing ClientSettings/safeStorage unlock in protected working copies, including Chromium Local State. No plaintext/encrypted credential or key context values recorded. No original bootstrap, host, game, server, BrowserWindow or network started.'};
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,...receipt}));if(!receipt.success)process.exitCode=1;
