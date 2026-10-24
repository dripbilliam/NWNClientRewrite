const {app,BrowserWindow}=require('electron'),path=require('node:path'),fs=require('node:fs/promises');
const root=path.resolve(__dirname,'..'),profile=path.join(root,'backups/light-selection-fixture-'+process.pid);
const version=process.argv[2]??'v1';if(!/^v\d+$/.test(version))throw Error('Invalid result version');
require('node:fs').mkdirSync(profile,{recursive:true});app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{try{
 const window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});
 await window.loadFile(path.join(__dirname,'renderer-light-slots-fixture.html'));
 const deadline=Date.now()+10000;while(!await window.webContents.executeJavaScript('typeof runLightSlotsFixture==="function"')){const error=await window.webContents.executeJavaScript('window.fixtureFailure');if(error)throw Error(error);if(Date.now()>deadline)throw Error('Light selection fixture timed out');await new Promise(r=>setTimeout(r,30));}
 const result=await window.webContents.executeJavaScript('runLightSlotsFixture({baseLights:230,transientLights:23,shadowCount:15,nativeLights:true})');
 if(result.screenshot){await fs.writeFile(path.join(root,'backups/animations/renderer-light-selection-gpu-'+version+'.png'),Buffer.from(result.screenshot.split(',')[1],'base64'));delete result.screenshot;}
 await fs.writeFile(path.join(root,'backups/animations/renderer-light-selection-gpu-'+version+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));app.exit(0);
}catch(error){console.error(error.stack);app.exit(1);}});
