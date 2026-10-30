// Read-only credential comparison; never emit credentials or their identifiers.
const {app,safeStorage}=require('electron');
const {createHash}=require('node:crypto');
app.setName('nwn-model-viewer-research');app.disableHardwareAcceleration();
app.whenReady().then(async()=>{
 let key='';
 try{
  const expected=process.argv.find(v=>v.startsWith('--expected-sha256='))?.slice(18);
  if(!/^[a-f0-9]{64}$/.test(expected??''))throw Error();
  const {ClientSettings}=await import('../../electron/client_settings.mjs');
  const settings=new ClientSettings({directory:app.getPath('userData'),encryption:safeStorage});
  key=await settings.cdKey();
  console.log(JSON.stringify({savedKeyMatchesSupplied:createHash('sha256').update(key).digest('hex')===expected}));app.exit(0);
 }catch{console.log(JSON.stringify({failure:'Protected login comparison failed'}));app.exit(1);}
 finally{key='';}
});
