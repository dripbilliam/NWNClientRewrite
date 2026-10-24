const {app,BrowserWindow}=require('electron'),fs=require('node:fs/promises'),path=require('node:path');
const workspace=path.resolve(__dirname,'..'),profile=path.join(workspace,'backups','model-preparation-fixture-'+process.pid);require('node:fs').mkdirSync(profile,{recursive:true});app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
const version=process.argv[2]??'v1';if(!/^v\d+$/.test(version))throw Error('Invalid fixture result version');
app.whenReady().then(async()=>{try{
 const window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});await window.loadFile(path.join(__dirname,'renderer-model-preparation-fixture.html'));
 const deadline=Date.now()+10000;while(!await window.webContents.executeJavaScript('typeof runPreparationFixture==="function"')){const failure=await window.webContents.executeJavaScript('window.fixtureFailure');if(failure)throw Error(failure);if(Date.now()>deadline)throw Error('Fixture initialization timed out');await new Promise(r=>setTimeout(r,25));}
 const polling=process.argv.includes('--poll-regression'),result=await window.webContents.executeJavaScript(polling?'runAreaPollingFixture()':'runPreparationFixture()'),png=Buffer.from(result.screenshot.split(',')[1],'base64');delete result.screenshot;
 const prefix=polling?'creation-performance-area-poll-gpu-':'renderer-model-preparation-gpu-';await fs.writeFile(path.join(workspace,'backups/animations/'+prefix+version+'.png'),png);await fs.writeFile(path.join(workspace,'backups/animations/'+prefix+version+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));app.exit(0);
}catch(error){console.error(error.stack);app.exit(1);}});
