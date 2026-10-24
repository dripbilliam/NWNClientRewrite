const {app,BrowserWindow}=require('electron'),path=require('node:path'),fs=require('node:fs/promises');
const profile=require('node:fs').mkdtempSync(path.join(require('node:os').tmpdir(),'nwn-menu-movement-'));for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.whenReady().then(async()=>{try{
 const win=new BrowserWindow({show:false,width:1000,height:800,webPreferences:{contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}}),errors=[];
 win.webContents.on('console-message',(_e,level,message)=>{if(level>=3&&!message.includes('fonts.googleapis'))errors.push(message);});
 await win.loadFile(path.join(__dirname,'keyboard-radial-fixture.html'));
 const deadline=Date.now()+10000;while(!await win.webContents.executeJavaScript('typeof runKeyboardRadialFixture==="function"')){if(Date.now()>deadline)throw Error('Fixture import timed out');await new Promise(r=>setTimeout(r,50));}
 const result=await win.webContents.executeJavaScript('runKeyboardRadialFixture()');if(errors.length)throw Error(errors.join('\n'));
 await fs.writeFile(path.join(__dirname,'../backups/animations/creation-experience-keyboard-radial-ui-v1.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));app.exit(0);
 }catch(e){console.error(e.stack);app.exit(1);}});
