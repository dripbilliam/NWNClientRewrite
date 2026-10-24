// Independent GPU fixture: read installed shaders in memory, no live session.
const {app,BrowserWindow}=require('electron');const path=require('node:path');const fs=require('node:fs/promises');
const fixtureProfile=path.resolve(__dirname,'../backups/keyhole-fixture-'+process.pid);require('node:fs').mkdirSync(fixtureProfile,{recursive:true});for(const key of ['userData','logs','crashDumps'])app.setPath(key,fixtureProfile);
app.whenReady().then(async()=>{let window;try{
 const {openLocalModule}=await import('./local-module.mjs');const {loadKeyholeShader}=await import('../src/camera_keyhole_shader.js');
 const resolver=await openLocalModule(process.argv[2],process.argv[3]);const shader=await loadKeyholeShader(resolver);
 window=new BrowserWindow({show:false,width:300,height:300,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true}});
 await window.loadFile(path.join(__dirname,'camera-keyhole-fixture.html'));const deadline=Date.now()+15000;while(!await window.webContents.executeJavaScript('typeof runKeyholeFixture === "function"')){if(Date.now()>deadline)throw new Error('Fixture import timed out');await new Promise(r=>setTimeout(r,50));}
 const result=await window.webContents.executeJavaScript(`(()=>{try{return runKeyholeFixture(${JSON.stringify(shader)})}catch(error){return {error:error.message,stack:error.stack}}})()`);
 if(result.error)throw new Error(result.error+'\n'+result.stack);
 if(process.argv[4])await fs.writeFile(process.argv[4],Buffer.from(result.canvasImage.split(',')[1],'base64'));delete result.canvasImage;console.log(JSON.stringify(result));app.exit(0);
 }catch(error){console.error(error.stack);app.exit(1);}});
