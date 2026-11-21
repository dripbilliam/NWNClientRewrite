const {app,BrowserWindow}=require('electron'),path=require('node:path'),fs=require('node:fs/promises');
const root=path.resolve(__dirname,'..'),version=process.argv[2]??'v1';if(!/^v\d+$/.test(version))throw Error('Invalid result version');
app.whenReady().then(async()=>{try{
 const window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});
 await window.loadFile(path.join(__dirname,'renderer-shadow-traversal-fixture.html'));const deadline=Date.now()+10000;
 while(!await window.webContents.executeJavaScript('typeof runShadowTraversalFixture==="function"')){const error=await window.webContents.executeJavaScript('window.fixtureFailure');if(error)throw Error(error);if(Date.now()>deadline)throw Error('Shadow fixture timed out');await new Promise(r=>setTimeout(r,30));}
 const result=await window.webContents.executeJavaScript('runShadowTraversalFixture()');await fs.writeFile(path.join(root,'backups/animations/renderer-shadow-traversal-gpu-'+version+'.png'),Buffer.from(result.screenshot.split(',')[1],'base64'));delete result.screenshot;
 await fs.writeFile(path.join(root,'backups/animations/renderer-shadow-traversal-gpu-'+version+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({passed:result.passed,comparisons:result.comparisons.length,times:result.times,rotation:result.rotation,gpu:result.gpu}));app.exit(0);
 }catch(error){console.error(error.stack);app.exit(1);}});
