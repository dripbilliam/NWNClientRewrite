const {app,BrowserWindow}=require('electron'),fs=require('node:fs/promises'),path=require('node:path');
const root=path.resolve(__dirname,'..'),version=process.argv[2]??'v1';if(!/^v\d+$/.test(version))throw Error('Invalid result version');
const profile=path.join(root,'backups','light-capacity-fixture-'+process.pid);require('node:fs').mkdirSync(profile,{recursive:true});for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.whenReady().then(async()=>{try{
 const window=new BrowserWindow({show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});await window.loadFile(path.join(__dirname,'renderer-light-capacity-fixture.html'));
 const deadline=Date.now()+10000;while(!await window.webContents.executeJavaScript('typeof runLightCapacityFixture==="function"')){const error=await window.webContents.executeJavaScript('window.fixtureFailure');if(error)throw Error(error);if(Date.now()>deadline)throw Error('Fixture initialization timed out');await new Promise(r=>setTimeout(r,25));}
 const moving=process.argv.includes('--moving-shadows');
 const result=await window.webContents.executeJavaScript(`runLightCapacityFixture(${moving?'{shadowSize:512,movingShadows:true}':'{}'})`);const png=Buffer.from(result.screenshot.split(',')[1],'base64');delete result.screenshot;
 await fs.writeFile(path.join(root,'backups/animations/creation-performance-light-capacity-'+version+'.png'),png);await fs.writeFile(path.join(root,'backups/animations/creation-performance-light-capacity-'+version+'.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({success:true,phases:result.phases.map(p=>({capacity:p.capacity,frames:p.completedFrameMs})),changedBytes:result.changedBytes}));app.exit(0);
 }catch(error){console.error(error.stack);app.exit(1);}});
