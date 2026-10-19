const {app,BrowserWindow,ipcMain}=require('electron');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path');
const {registerRuntimeLog,observeWindow,flushOnClose}=require('../electron/runtime_log.cjs');
const workspace=path.resolve(__dirname,'..'),install=path.resolve('../FullDecomp/NwnRootInstall'),profile=path.join(workspace,`backups/player-movement-ui-profile-${process.pid}`);
app.setPath('userData',profile);app.setPath('logs',profile);app.setPath('crashDumps',profile);
app.whenReady().then(async()=>{
 const log=registerRuntimeLog(ipcMain,path.join(workspace,'runtime-logs')),win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(workspace,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,offscreen:true,backgroundThrottling:false}});flushOnClose(win,observeWindow(win,log));
 const errors=[],report={};win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)errors.push(message);});
 const evaluate=code=>win.webContents.executeJavaScript(code),delay=ms=>new Promise(r=>setTimeout(r,ms));
 const wait=async condition=>{const end=Date.now()+120000;while(!await evaluate(condition)){if(Date.now()>end)throw Error('Timeout: '+condition+'\n'+await evaluate('document.body.innerText.slice(-1500)'));await delay(100);}};
 const files=async(selector,files)=>{const {root}=await win.webContents.debugger.sendCommand('DOM.getDocument'),{nodeId}=await win.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector});await win.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files});};
 const state=()=>evaluate(`(()=>{const c=document.querySelector('canvas'),a=JSON.parse(c.dataset.creatureAnimations);return {actorId:Number(c.dataset.actorId),position:JSON.parse(c.dataset.actorPosition),animation:a.actors.find(a=>a.id===Number(c.dataset.actorId)),events:a.events,area:c.dataset.areaResRef,bounds:c.getBoundingClientRect().toJSON()};})()`);
 const moved=(a,b)=>Math.hypot(a.position[0]-b.position[0],a.position[2]-b.position[2])>.05;
 const click=async(x,y,modifiers=0)=>{for(const type of ['mousePressed','mouseReleased'])await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1,modifiers});};
 try{
  await win.loadFile(path.join(workspace,'dist/index.html'));win.webContents.debugger.attach('1.3');
  await files('#game-data-folder',[path.join(install,'data')]);await wait(`document.querySelector('#status-text').textContent.startsWith('GAME DATA READY')`);
  await files('#language-data-folder',[path.join(install,'lang/en/data')]);await wait(`document.querySelector('#status-text').textContent==='LANGUAGE DATA READY'`);
  await files('#area-file',[path.join(install,'data/nwm/Prelude.nwm')]);await wait(`document.querySelector('#character-frontend').dataset.mode==='select'`);
  await evaluate(`{[...document.querySelectorAll('.character-card')].find(b=>b.textContent.includes('wizard.bic')).click();document.querySelector('#run-module-startup').checked=true;[...document.querySelectorAll('#character-frontend button')].find(b=>b.textContent==='Play').click();}`);
  await wait(`document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);await delay(500);
  // Raise the ordinary orbit camera above the entry room's foreground wall.
  await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',x:1000,y:300,button:'left',clickCount:1});
  for(let y=320;y<=540;y+=20)await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',x:1000,y,button:'left',buttons:1});
  await win.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',x:1000,y:540,button:'left',clickCount:1});await delay(400);report.initial=await state();
  report.attempts=[];
  for(const [dx,dy] of [[25,25],[-25,25],[40,15],[-40,15],[0,45],[30,45],[-30,45]]){
   const before=await state(),p=before.animation.screen,b=before.bounds;await click(b.x+p.x+dx,b.y+p.y+dy,8);await delay(450);const after=await state();report.attempts.push({dx,dy,before,after});
   if(moved(before,after)){report.walk=after;break;}
  }
  assert.ok(report.walk,'A real floor click must move the character');assert.equal(report.walk.animation.base,2);assert.ok(report.walk.animation.time>0);assert.match(report.walk.animation.clip,/walk/i);
  await delay(2300);report.stopped=await state();assert.ok(![2,3,4].includes(report.stopped.animation.base));
  const beforeKey=await state();await win.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyDown',key:'w',code:'KeyW',windowsVirtualKeyCode:87});await delay(550);report.keyboard=await state();await win.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyUp',key:'w',code:'KeyW',windowsVirtualKeyCode:87});
  assert.ok(moved(beforeKey,report.keyboard),'WASD must use canonical movement');assert.equal(report.keyboard.animation.base,4);assert.ok(report.keyboard.animation.time>0);
  await delay(350);report.released=await state();await delay(350);report.releasedLater=await state();assert.ok(!moved(report.released,report.releasedLater),'Keyboard movement must stop on release');assert.ok(![2,3,4].includes(report.releasedLater.animation.base));
  assert.equal(report.initial.actorId,report.releasedLater.actorId);assert.deepEqual(errors,[]);console.log('PRELUDE WIZARD FLOOR CLICK/WALK, WASD/RUN AND RELEASE/IDLE PASS');
 }catch(error){report.error=error.stack;console.error(error.stack);process.exitCode=1;}
 finally{report.errors=errors;report.log=log.path;await fs.writeFile(path.join(workspace,'backups/animations/live-player-movement-ui.json'),JSON.stringify(report,null,2));await fs.writeFile(path.join(workspace,'backups/animations/live-player-movement-ui.png'),(await win.webContents.capturePage()).toPNG());win.destroy();app.exit(report.error?1:0);}
});
