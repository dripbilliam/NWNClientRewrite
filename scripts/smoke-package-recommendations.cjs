// Isolated creator UI using already-downloaded data. No login, upload or fetch.
const {app,BrowserWindow,ipcMain,session}=require('electron'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const version=process.argv[2]??'v1';if(!/^v\d+$/.test(version))throw Error('Invalid package fixture version');
const root=path.resolve(__dirname,'..'),profile=require('node:fs').mkdtempSync(path.join(os.tmpdir(),'nwn-package-ui-'));
for(const key of ['userData','logs','crashDumps'])app.setPath(key,profile);
app.on('window-all-closed',()=>{}); // Finish report/cleanup before app.exit.
app.whenReady().then(async()=>{
 const report={version,scope:'Actual CharacterFrontend UI with cached custom rules and enabled Workshop mods; no server join, upload, vault write or downloads',httpAttempts:0,joins:0,uploads:0,errors:[]};let resources,window;
 try{
  session.defaultSession.webRequest.onBeforeRequest((details,callback)=>callback({cancel:/^https?:/.test(details.url)}));
  const {installedNetworkResources}=await import('../electron/installed_network_resources.mjs'),{defaultModsDirectory}=await import('../electron/client_settings.mjs'),{resolveServerResources}=await import('../src/network_resources.js'),{availableCreationPortraits}=await import('../src/creation_portraits.js');
  const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),download=JSON.parse(await fs.readFile(path.join(root,'backups/animations/arelith-fresh-download-v2.json'),'utf8')),ad=JSON.parse(await fs.readFile(path.join(root,'backups/animations/arelith-authenticated-advertisement-v1.json'),'utf8'));
  resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,modsDirectory:await defaultModsDirectory(install),reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline package fixture may not fetch');}}});
  const resolved=await resolveServerResources(ad.requirements,{...resources,language:0});assert.equal(resolved.ready,true);const resolver=await resources.openModule(null,resolved.resolved);
  const envelope=fn=>async(_event,...args)=>{try{return{ok:true,value:await fn(...args)};}catch(error){return{ok:false,message:error.message,code:error.code};}};
  ipcMain.handle('creation-fixture:resource',envelope((name,type)=>resolver.getResource(name,type)));
  ipcMain.handle('creation-fixture:texture',envelope(name=>resolver.getTextureResource(name)));
  ipcMain.handle('creation-fixture:models',()=>resolver.resourceNames(2002));ipcMain.handle('creation-fixture:portraits',()=>resolver.portraitNames());ipcMain.handle('creation-fixture:portrait-availability',(_event,refs)=>availableCreationPortraits(resolver,refs));
  ipcMain.handle('creation-fixture:talk',async()=>({base:await resources.talkTableData(false,resolved.resolved),custom:await resources.talkTableData(true,resolved.resolved)}));
  window=new BrowserWindow({show:false,width:1260,height:900,webPreferences:{preload:path.join(root,'scripts/server-creation-fixture-preload.cjs'),contextIsolation:true,nodeIntegration:false,offscreen:true,backgroundThrottling:false}});
  window.webContents.on('console-message',(_event,level,message)=>{if(level>=3)report.errors.push(message);});
  const js=code=>window.webContents.executeJavaScript(code),wait=async(code,label)=>{const until=Date.now()+30000;while(!await js(code)){if(Date.now()>until)throw Error(label+' timed out');await new Promise(r=>setTimeout(r,30));}};
  await window.loadFile(path.join(root,'scripts/server-creation-fixture.html'));await wait('window.creationUi?.mode==="create"','Creator');
  report.initial=await js(`({classId:creationUi.draft.classId,packageId:creationUi.draft.packageId,valid:creationUi.rules.packages.orderedRows[creationUi.draft.packageId]?.PlayerClass==='1'})`);assert.equal(report.initial.valid,true);
  const classId=await js(`creationUi.rules.classes.orderedRows.findIndex(r=>r.Label?.toLowerCase()==='druid')`);assert.ok(classId>=0);
  await js(`creationUi.step=3;creationUi.render();document.querySelector('.character-choices [data-choice-id="${classId}"]').click();creationUi.step=5;creationUi.render()`);
  report.before=await js(`({classId:creationUi.draft.classId,packageId:creationUi.draft.packageId,configured:Number(creationUi.rules.classes.orderedRows[creationUi.draft.classId].Package),selected:[...document.querySelectorAll('.character-choices button[aria-pressed="true"]')].map(b=>Number(b.dataset.choiceId))})`);
  assert.equal(report.before.classId,classId);assert.notEqual(report.before.packageId,report.before.configured);assert.deepEqual(report.before.selected,[report.before.packageId]);
  await js(`window.packageWork=creationUi.recommend()`);await js('packageWork');assert.equal(await js('creationUi.error'),'');
  report.recommended=await js(`({packageId:creationUi.draft.packageId,abilities:creationUi.draft.abilities,skills:Object.keys(creationUi.draft.skills).length,feats:creationUi.draft.feats.length,memorized:Object.fromEntries(Object.entries(creationUi.draft.memorized).filter(([,v])=>v.length))})`);assert.equal(report.recommended.packageId,report.before.packageId);
  await js(`creationUi.draft.firstName='Package';creationUi.draft.lastName='Fixture'`);report.bic=await js('verifyCreation()');assert.equal(report.bic.classId,classId);assert.equal(report.bic.packageId,report.before.packageId);assert.equal(report.bic.legacyPackage,0);assert.equal(report.bic.hasWorldId,false);
  // A deliberate eligible alternative remains selected; a stale hidden default
  // is repaired before recommendation tables are requested.
  const alternate=await js(`Number([...document.querySelectorAll('.character-choices button')].find(b=>b.getAttribute('aria-pressed')!=='true').dataset.choiceId)`);
  await js(`document.querySelector('.character-choices [data-choice-id="${alternate}"]').click();window.packageWork=creationUi.recommend()`);await js('packageWork');assert.equal(await js('creationUi.error'),'');assert.equal(await js('creationUi.draft.packageId'),alternate);report.explicitSelectionRetained=true;
  await js(`creationUi.draft.packageId=Number(creationUi.rules.classes.orderedRows[creationUi.draft.classId].Package);window.packageWork=creationUi.recommend()`);await js('packageWork');assert.equal(await js('creationUi.error'),'');assert.equal(await js('creationUi.draft.packageId'),report.before.packageId);report.hiddenDefaultRepaired=true;
  report.availableClasses=await js(`(async()=>{const {initialCreationDraft,creationClassRequirement,creationDefaultPackage,creationPackageOptions}=await import('../src/character_creation.js');const r=creationUi.rules,rows=[];for(let id=0;id<r.classes.orderedRows.length;id++){const d=initialCreationDraft(r);if(creationClassRequirement(d,r,id))continue;const selected=creationDefaultPackage(r,id);rows.push({id,selected,selectable:creationPackageOptions(r,id).some(p=>p.id===selected)});}return rows;})()`);assert.ok(report.availableClasses.length>1);assert.ok(report.availableClasses.every(c=>c.selectable));
  await fs.writeFile(path.join(root,'backups/animations/creation-experience-package-ui-'+version+'.png'),(await window.webContents.capturePage()).toPNG());assert.deepEqual(report.errors,[]);assert.equal(report.httpAttempts,0);report.success=true;
 }catch(error){report.failure=error.stack;report.success=false;}
 finally{resources?.close();report.temporaryProfile=path.basename(profile);report.cleanup='Chromium profile cleanup deferred until process exit because open Network files can be locked on Windows';await fs.writeFile(path.join(root,'backups/animations/creation-experience-package-ui-'+version+'.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));window?.destroy();app.exit(report.success?0:1);}
});
