// Explicit authorized pregame-only diagnostic. No BrowserWindow, Play, character
// creation, chat, add-on execution or changes to the saved active login profile.
const {app,safeStorage}=require('electron');
const fs=require('node:fs/promises'),path=require('node:path'),{createHash}=require('node:crypto');
app.setName('nwn-model-viewer-research');app.disableHardwareAcceleration();
const arg=name=>process.argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
let session,output,report={success:false,publicConnections:0,worldEntered:false,chatSent:false,profileChanged:false,stages:{},selections:[],resources:[]};
const wait=async(predicate,timeout=90000)=>{const end=performance.now()+timeout;while(!predicate()){if(performance.now()>end)throw Error('Pregame diagnostic timed out');await new Promise(resolve=>setTimeout(resolve,10));}};
app.whenReady().then(async()=>{
 const run=arg('run');if(!/^[a-z0-9-]{3,80}$/.test(run??''))throw Error('Explicit unique diagnostic run required');
 const project=path.resolve(__dirname,'..'),workspace=path.dirname(project),directory=path.join(project,'reports',run);output=path.join(project,'reports',run+'.json');
 await fs.mkdir(directory);const bicDirectory=path.join(directory,'bic'),resourceDirectory=path.join(directory,'resources');await fs.mkdir(bicDirectory);await fs.mkdir(resourceDirectory);
 const settingsBytes=await fs.readFile(path.join(app.getPath('userData'),'client-settings.json'));const settings=JSON.parse(settingsBytes);settingsBytes.fill(0);
 const profile=settings.loginProfiles.find(p=>p.label.toLowerCase()===(arg('profile')??'main').toLowerCase());if(!profile?.protectedCdKey||!safeStorage.isEncryptionAvailable())throw Error('Protected diagnostic profile is unavailable');
 let key=safeStorage.decryptString(Buffer.from(profile.protectedCdKey,'base64'));for(const p of settings.loginProfiles)p.protectedCdKey='';settings.protectedCdKey='';
 const install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');let userDirectory;for(const name of ['Neverwinter Nights.0','Neverwinter Nights']){const candidate=path.join(app.getPath('documents'),name);try{await fs.access(path.join(candidate,'nwsync/nwsyncmeta.sqlite3'));userDirectory=candidate;break;}catch{}}
 userDirectory??=path.join(app.getPath('documents'),'Neverwinter Nights');
 const endpoint={host:'game.nwnarelith.com',port:5124};report.endpoint=endpoint.host+':'+endpoint.port;
 const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');let began=performance.now();
 const created=await createInstalledNetworkSession({install,userDirectory,cacheDirectory:path.join(app.getPath('userData'),'server-content'),modsDirectory:settings.modsDirectory,disabledMods:settings.disabledMods??[],...endpoint,name:profile.playerName,credentials:{cdKey:key}});key='';session=created.session;session.deferNuiResources=true;report.stages.create_session_ms=performance.now()-began;
 let reply=null;session.characterPreviewEncoder=async bytes=>{const sha256=createHash('sha256').update(bytes).digest('hex'),file=path.join(bicDirectory,sha256+'.bic');await fs.writeFile(file,bytes);return{format:'native-bic-file-v1',path:file,sha256,bytes:bytes.length};};
 session.on('state',state=>{if(['playing','area-loading','character'].includes(state.phase)){report.worldEntered=true;void session.disconnect();}});
 session.on('message',({message})=>{if(message.kind==='server-character-preview')reply=message;});
 began=performance.now();report.publicConnections++;await session.connect({...endpoint,metadata:created.metadata,timeout:45000});await wait(()=>session.phase==='character-selection'&&session.resourceResult?.ready&&!session.serverCharacterListPending);report.stages.connect_roster_ms=performance.now()-began;
 report.characterCount=session.serverCharacters.length;if(report.characterCount<2)throw Error('Protected profile has fewer than two pregame characters; creation deliberately not attempted by this diagnostic');
 const choices=session.serverCharacters.slice(0,3);for(const row of [...choices,...choices]){
  if(session.closed||session.phase!=='character-selection'||session.characterSubmitted)throw Error('Pregame ownership changed');reply=null;began=performance.now();await session.previewServerCharacter({source:row.source,resref:row.resref,generation:session.characterListGeneration});const sent=performance.now();await wait(()=>reply&&reply.resref===row.resref,30000);report.selections.push({source:row.source,generation:session.characterListGeneration,send_ms:sent-began,reply_ms:performance.now()-began,bytes:reply.preview?.bytes??0,sha256:reply.preview?.sha256??null});
 }
 // Capture exact resolved table bytes for native CPU-only replay. The active
 // server resolver remains authoritative; no rule interpretation is added here.
 const {parse2da}=await import('../../src/area.js'),names=new Set(['classes','racialtypes','skills','ruleset','exptable','spells']);let classes;
 for(const name of names){const started=performance.now();const bytes=new Uint8Array(await session.resolver.getResource(name,2017));await fs.writeFile(path.join(resourceDirectory,name+'.2da'),bytes);report.resources.push({name,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,read_ms:performance.now()-started});if(name==='classes')classes=parse2da(Buffer.from(bytes).toString('latin1'));}
 const rows=classes.orderedRows??classes.rows??[];for(const row of rows)for(const field of ['SkillsTable','StatGainTable','AttackBonusTable','SpellGainTable']){const name=String(row[field]??row[field.toLowerCase()]??'').toLowerCase();if(!/^[a-z0-9_]{1,64}$/.test(name)||names.has(name)||name==='****')continue;names.add(name);try{const started=performance.now(),bytes=new Uint8Array(await session.resolver.getResource(name,2017));await fs.writeFile(path.join(resourceDirectory,name+'.2da'),bytes);report.resources.push({name,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,read_ms:performance.now()-started});}catch{report.resources.push({name,absent:true});}}
 report.success=!report.worldEntered&&report.selections.length===choices.length*2;report.fixture={bicDirectory,resourceDirectory};
}).catch(error=>{report.failure=error.message;}).finally(async()=>{await session?.disconnect().catch(()=>{});if(output)await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,characterCount:report.characterCount,failure:report.failure,report:output}));app.exit(report.success?0:1);});
