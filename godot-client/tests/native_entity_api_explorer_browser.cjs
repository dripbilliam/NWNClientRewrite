// Test-only external Chromium client. Nothing here is loaded by the game.
const {app,BrowserWindow}=require('electron');
const fs=require('node:fs/promises');
const syncFs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const args=Object.fromEntries(process.argv.filter(x=>x.startsWith('--')).map(x=>x.slice(2).split(/=(.*)/s).slice(0,2)));
const directory=args['fixture-directory'];
const reportPath=args.report;
if(!directory||!reportPath)process.exit(2);
const profile=path.join(directory,'isolated-browser-profile');
syncFs.mkdirSync(profile,{recursive:true});app.setPath('userData',profile);
app.disableHardwareAcceleration();
app.commandLine.appendSwitch('disable-background-networking');
app.commandLine.appendSwitch('disable-component-update');
app.commandLine.appendSwitch('disable-sync');
app.commandLine.appendSwitch('no-first-run');
app.commandLine.appendSwitch('host-resolver-rules','MAP localhost 127.0.0.1');
app.commandLine.appendSwitch('disable-features','MediaRouter,OptimizationHints,AutofillServerCommunication');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const checks=[];
const runtimeErrors=[];
const requests=[];
const blocked=[];
const networkEvents=[];
const privateFiles=[];
let window,allowedOrigin='',serial=0,expectedHttpErrors=0;
let probeToken='',nativeProbeStatus=null,lastView=null;
function networkEvent(value){if(networkEvents.length<160)networkEvents.push(value);}
function check(value,label){checks.push({passed:Boolean(value),label});if(!value)throw Error(label);}
async function json(file){return JSON.parse(await fs.readFile(file,'utf8'));}
async function waitFor(label,predicate,timeout=12000){const until=Date.now()+timeout;while(Date.now()<until){if(await predicate())return;await sleep(50);}throw Error('Timed out: '+label);}
async function evaluate(fn,...values){return window.webContents.executeJavaScript('('+fn.toString()+')(...'+JSON.stringify(values)+')');}
async function text(id){return evaluate(id=>document.getElementById(id)?.textContent||'',id);}
async function click(id){await evaluate(id=>document.getElementById(id).click(),id);}
async function painted(){await evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(true)))));}
async function idle(){await waitFor('authenticated idle',async()=>await text('auth-status')==='Connected');}
async function choose(file){const {root}=await window.webContents.debugger.sendCommand('DOM.getDocument');const {nodeId}=await window.webContents.debugger.sendCommand('DOM.querySelector',{nodeId:root.nodeId,selector:'#discovery-file'});await window.webContents.debugger.sendCommand('DOM.setFileInputFiles',{nodeId,files:[file]});}
async function command(action){serial++;const file=path.join(directory,'control-'+serial+'.json');await fs.writeFile(file+'.tmp',JSON.stringify({serial,action}));await fs.rename(file+'.tmp',file);await waitFor('fixture '+action,async()=>{try{return(await json(path.join(directory,'ack.json'))).serial===serial;}catch{return false;}});}
async function nativeGet(url,token){return new Promise(resolve=>{const request=http.get(url,{headers:{Authorization:'Bearer '+token}},response=>{response.resume();response.on('end',()=>resolve(response.statusCode));});request.on('error',()=>resolve(0));request.setTimeout(2000,()=>{request.destroy();resolve(0);});});}
async function waitLocked(){await waitFor('locked view',async()=>await text('auth-status')==='Locked');}
async function verifyNoSecret(secret,label){const dom=await evaluate(()=>document.documentElement.outerHTML);const storage=await evaluate(()=>({local:Object.entries(localStorage),session:Object.entries(sessionStorage),cookie:document.cookie,url:location.href}));check(!dom.includes(secret)&&!JSON.stringify(storage).includes(secret)&&storage.local.length===0&&storage.session.length===0&&storage.cookie===''&&!storage.url.includes('?')&&!storage.url.includes('#'),label);}
async function main(){
  const ready=await json(path.join(directory,'ready.json'));
  const discovery=await json(ready.discovery_path);
  const secret=discovery.bearer_token;
  probeToken=secret;
  allowedOrigin=new URL(ready.explorer_url).origin;
  const partition='entity-api-explorer-'+process.pid;
  window=new BrowserWindow({show:false,width:1440,height:1000,backgroundColor:'#101519',webPreferences:{partition,contextIsolation:true,sandbox:true,nodeIntegration:false,webSecurity:true,offscreen:true,backgroundThrottling:false}});
  window.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  window.webContents.session.webRequest.onBeforeRequest({urls:['*://*/*']},(details,callback)=>{let allowed=false;try{allowed=new URL(details.url).origin===allowedOrigin;}catch{}if(!allowed)blocked.push({type:details.resourceType});callback({cancel:!allowed});});
  window.webContents.session.webRequest.onCompleted({urls:['*://*/*']},details=>{const url=new URL(details.url);requests.push({origin:url.origin,path:url.pathname,status:details.statusCode});});
  window.webContents.session.webRequest.onBeforeSendHeaders({urls:['*://*/*']},(details,callback)=>{const fields={};let authorized=false;for(const[key,value]of Object.entries(details.requestHeaders)){const name=key.toLowerCase();if(name==='authorization')authorized=true;else if(['host','origin','sec-fetch-site','sec-fetch-mode','sec-fetch-dest'].includes(name))fields[name]=value;}networkEvent({stage:'request',path:new URL(details.url).pathname,authorized,fields});callback({requestHeaders:details.requestHeaders});});
  window.webContents.session.webRequest.onHeadersReceived({urls:['*://*/*']},(details,callback)=>{networkEvent({stage:'response',path:new URL(details.url).pathname,status:details.statusCode});callback({responseHeaders:details.responseHeaders});});
  window.webContents.session.webRequest.onErrorOccurred({urls:['*://*/*']},details=>networkEvent({stage:'error',path:new URL(details.url).pathname,error:details.error}));
  window.webContents.on('console-message',(_event,level,message)=>{if(level<2)return;if(/Failed to load resource: the server responded with a status of (401|410|429)/.test(message)){expectedHttpErrors++;return;}runtimeErrors.push(String(message).slice(0,200));});
  window.webContents.on('render-process-gone',(_event,details)=>runtimeErrors.push('renderer:'+details.reason));
  window.webContents.debugger.attach('1.3');
  await window.loadURL(ready.explorer_url);
  check(!window.isVisible(),'Owned browser remains hidden and never focuses a user window');
  check(await text('auth-status')==='Locked','Static explorer loads locked with no embedded token');
  check(await evaluate(()=>typeof process==='undefined'&&typeof require==='undefined'),'Browser page has no Node integration');
  check(requests.filter(r=>r.path.startsWith('/api/v1')).length===0,'No API data is fetched before explicit file authentication');
  await verifyNoSecret(secret,'Initial HTML, URL, cookies and storage contain no bearer');
  const malformed=path.join(directory,'malformed.private.json');privateFiles.push(malformed);await fs.writeFile(malformed,'{"bearer_token":"'+secret+'",broken');
  await choose(malformed);await waitLocked();await waitFor('malformed file notice',async()=>(await text('notice')).includes('not valid JSON'));
  await verifyNoSecret(secret,'Malformed discovery parsing never renders the token or stores it');
  const foreign=path.join(directory,'foreign.private.json');privateFiles.push(foreign);await fs.writeFile(foreign,JSON.stringify({...discovery,base_url:'http://127.0.0.1:'+(ready.port===65535?ready.port-1:ready.port+1)+'/api/v1'}));
  await choose(foreign);await waitFor('wrong port notice',async()=>(await text('notice')).includes('another address or port'));
  check(requests.filter(r=>r.path.startsWith('/api/v1')).length===0&&blocked.length===0,'Wrong-port discovery is refused without making any request');
  const wrong=path.join(directory,'wrong-token.private.json');privateFiles.push(wrong);await fs.writeFile(wrong,JSON.stringify({...discovery,bearer_token:'0'.repeat(64)}));
  await choose(wrong);await waitFor('rejected bearer',async()=>(await text('notice')).includes('token expired'));await waitLocked();
  check(await evaluate(()=>document.getElementById('refresh').disabled),'Unauthorized discovery leaves API controls locked');
  await choose(ready.discovery_path);await idle();
  check((await text('scope-primary'))==='Active client area','Valid chosen discovery authenticates to the native HTTP fixture');
  check((await text('controlled-primary')).includes('Scout <img')&&(await text('controlled-primary')).includes('Object 1'),'Identity card combines only received first/last raw text safely');
  check((await text('player-reason'))==='identity_not_received','Unavailable player-character identity is explicit');
  check(await evaluate(()=>document.querySelectorAll('#entity-list button').length===25),'First page is bounded to25 reference rows');
  check(await evaluate(()=>document.getElementById('discovery-file').value===''),'File control is cleared after token import');
  await evaluate(()=>document.querySelector('#entity-list button').click());await idle();
  check((await text('entity-title'))==='Scout <img src=x onerror=globalThis.__entityXss=1>','Selected structured name is rendered literally');
  check(await evaluate(()=>!document.querySelector('#entity-title img')&&!globalThis.__entityXss),'Hostile entity text cannot become DOM or execute');
  check((await text('entity-details')).includes('client_received_read_model')&&(await text('entity-details')).includes('client_initialized_ability_cache'),'Received/read-model and client cache provenance remain visible');
  await click('presentation-tab');
  check((await text('entity-details')).includes('client_simulated')&&(await text('entity-details')).includes('NWN')&&(await text('entity-details')).includes('9'),'Presentation is shown separately with native NWN values');
  await painted();await fs.writeFile(path.join(directory,'explorer-presentation.png'),(await window.webContents.capturePage()).toPNG());
  await click('received-tab');await painted();
  await fs.writeFile(path.join(directory,'explorer-authenticated.png'),(await window.webContents.capturePage()).toPNG());
  await verifyNoSecret(secret,'Authenticated DOM, URL, cookies and storage never contain the bearer');
  await click('next-page');await idle();check((await text('entity-count')).includes('page 2')&&(await evaluate(()=>document.querySelector('#entity-list button').textContent))==='Object 26','Next page follows the scoped cursor');
  await click('previous-page');await idle();check((await text('entity-count')).includes('page 1'),'Previous page returns through bounded cursor history');
  await evaluate(()=>{document.getElementById('object-type').value='9';document.getElementById('filters').requestSubmit();});await idle();
  check(await evaluate(()=>document.querySelectorAll('#entity-list button').length===20&&document.querySelector('#entity-list button').textContent==='Object 41'),'Type filtering changes the paginated known-entity view');
  await evaluate(()=>{document.getElementById('object-type').value='';document.getElementById('area-id').value='1.5';document.getElementById('filters').requestSubmit();});
  check((await text('notice')).includes('canonical unsigned decimal'),'Invalid area filtering is rejected locally without coercion');
  await evaluate(()=>{document.getElementById('area-id').value='';document.getElementById('filters').requestSubmit();});await idle();
  await evaluate(()=>document.querySelector('#entity-list button').click());await idle();await command('remove');
  await click('refresh-entity');await idle();check((await text('detail-state'))==='Stale reference'&&(await text('entity-details')).includes('old reference'),'Removed selected lifetime clears details on410');
  await command('reuse');await click('refresh');await idle();await evaluate(()=>document.querySelector('#entity-list button').click());await idle();
  check((await text('entity-title'))==='Replacement'&&!(await text('entity-title')).includes('999'),'Reused numeric ID is selected only through a fresh ref; unresolved name strRef is not invented');
  await click('next-page');await idle();await command('transition');await click('next-page');await idle();
  check((await text('entity-count'))==='Old page retired'&&(await text('notice')).includes('area scope changed'),'Old scoped cursor is cleared safely instead of being reused');
  await click('refresh');await idle();check((await text('scope-details')).includes('8')&&await evaluate(()=>document.querySelectorAll('#entity-list button').length===5),'Manual refresh recovers a new native area scope');
  const floodUntil=Date.now()+1200;const flood=(async()=>{while(Date.now()<floodUntil){await nativeGet(allowedOrigin+'/api/v1/scope',secret);await sleep(20);}})();
  await sleep(150);const before429=requests.filter(r=>r.status===429).length;await click('refresh');
  await waitFor('browser429 response',()=>requests.filter(r=>r.status===429).length>before429);await flood;await idle();
  check(requests.some(r=>r.status===429)&&(await text('notice')).includes('Authenticated'),'Actual native429 is retried conservatively by the browser request queue');
  check(!await evaluate(()=>document.hidden),'Owned offscreen test page is logically visible without showing a window');
  const beforePoll=requests.filter(r=>r.path==='/api/v1/scope').length;await click('poll');await sleep(6100);await idle();
  const pollCount=requests.filter(r=>r.path==='/api/v1/scope').length-beforePoll;
  check(pollCount===1,'Five-second polling performs exactly one serialized refresh in the measured interval');await click('poll');
  // Offscreen Chromium deliberately reports visible for painting. A separate
  // owned, never-shown window exercises the real hidden Page Visibility state.
  const paintedWindow=window;
  window=new BrowserWindow({show:false,paintWhenInitiallyHidden:false,width:800,height:600,webPreferences:{partition,contextIsolation:true,sandbox:true,nodeIntegration:false,webSecurity:true,backgroundThrottling:true}});
  window.webContents.setWindowOpenHandler(()=>({action:'deny'}));window.webContents.debugger.attach('1.3');
  await window.loadURL(ready.explorer_url);await waitLocked();
  check(!window.isVisible()&&await evaluate(()=>document.hidden),'Separate owned browser document has actual hidden visibility without showing a user window');
  await choose(ready.discovery_path);await idle();await click('poll');
  const beforeHidden=requests.filter(r=>r.path.startsWith('/api/v1')).length;await sleep(6100);
  check(requests.filter(r=>r.path.startsWith('/api/v1')).length===beforeHidden&&(await text('poll-status')).includes('paused while hidden'),'Hidden document polling makes zero API requests');
  window.destroy();window=paintedWindow;
  await click('refresh');await click('disconnect');await sleep(1200);
  check((await text('auth-status'))==='Locked'&&(await text('scope-primary'))==='Not connected'&&await evaluate(()=>document.querySelectorAll('#entity-list button').length===0),'Disconnect cancels queued/in-flight work and stale replies cannot restore a locked view');
  await choose(ready.discovery_path);await idle();const reloaded=new Promise(resolve=>window.webContents.once('did-finish-load',resolve));window.webContents.reload();await reloaded;await waitLocked();
  check((await text('scope-primary'))==='Not connected','Reload forgets token and data instead of restoring browser storage');
  allowedOrigin='http://localhost:'+ready.port;const beforeAlias=requests.length;await window.loadURL(allowedOrigin+'/explorer/');await waitLocked();await choose(ready.discovery_path);await idle();
  check(requests.slice(beforeAlias).filter(r=>r.path.startsWith('/api/v1')).every(r=>r.origin===allowedOrigin)&&(await text('scope-primary'))==='Active client area','Localhost page accepts127.0.0.1 discovery but sends only relative same-origin API requests');
  check(requests.filter(r=>r.path.startsWith('/explorer')).every(r=>r.status===200),'Rapid reload/alias navigation cannot rate-starve credential-free bootstrap assets');
  await verifyNoSecret(secret,'Alias-origin page also keeps credentials out of DOM, storage and URL');
  check(blocked.length===0,'Self-contained explorer made no foreign/CDN/browser-network requests');
  check(runtimeErrors.length===0,'No unexpected browser JavaScript/CSP/runtime errors');
}
app.whenReady().then(async()=>{
  let failure=null;
  try{await Promise.race([main(),new Promise((_resolve,reject)=>setTimeout(()=>reject(Error('Owned browser validation timeout')),70000))]);}
  catch(error){failure=String(error.message).slice(0,200);if(probeToken&&failure.includes(probeToken))failure='[redacted]';if(allowedOrigin&&probeToken)nativeProbeStatus=await nativeGet(allowedOrigin+'/api/v1/scope',probeToken);if(window&&!window.isDestroyed()){try{lastView={auth:await text('auth-status'),notice:await text('notice'),scope:await text('scope-primary')};if(probeToken&&JSON.stringify(lastView).includes(probeToken))lastView={redacted:true};}catch{}}}
  finally{
    if(window&&!window.isDestroyed()){try{await fs.writeFile(path.join(directory,'explorer-final.png'),(await window.webContents.capturePage()).toPNG());}catch{}window.destroy();}
    await fs.writeFile(path.join(directory,'stop.json'),'{}').catch(()=>{});
    for(const file of privateFiles)await fs.unlink(file).catch(()=>{});
    probeToken='';
    const result={success:!failure,checks:checks.length,failures:failure?[failure]:[],cases:checks,runtimeErrors,expectedHttpErrors,requests:requests.length,blockedRequests:blocked.length,networkEvents,nativeProbeStatus,lastView,hiddenWindow:true,nodeIntegration:false,contextIsolation:true,sandbox:true,gpuDisabled:true,gameServerConnections:0,publicConnections:0,scope:'Actual external Chromium explorer DOM/file authentication over the owned native Godot HTTP fixture; no user window or game renderer integration. Localhost DNS maps to IPv4 loopback inside this isolated test browser.'};
    await fs.writeFile(reportPath,JSON.stringify(result,null,2)+'\n');
    console.log('ENTITY_API_EXPLORER_BROWSER_RESULT '+JSON.stringify({success:result.success,checks:result.checks,failures:result.failures,runtimeErrors:result.runtimeErrors.length,blockedRequests:result.blockedRequests}));
    app.exit(result.success?0:1);
  }
});
app.on('window-all-closed',()=>{});
