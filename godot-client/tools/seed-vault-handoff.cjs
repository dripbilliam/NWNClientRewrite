// No game connection: seed the authored external vault before native server
// startup indexes base-vault files. Protected key remains main-process only.
const {app,safeStorage}=require('electron');const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
app.setName('nwn-model-viewer-research');
app.whenReady().then(async()=>{
 let identity,credentials={},exitCode=0;try{
  const fixtureName=process.argv.find(v=>v.startsWith('--fixture='))?.slice(10);if(!/^vault-handoff-fixtures-v[0-9]+\.json$/.test(fixtureName??''))throw Error('Invalid authored fixture name');
  const project=path.resolve(__dirname,'..'),root=path.dirname(project),report=path.join(project,'reports',fixtureName.replace(/\.json$/,'.seed.json'));
  try{await fs.access(report);throw Error('Seed report already exists');}catch(e){if(e.code!=='ENOENT')throw e;}
  const {ClientSettings}=await import('../../electron/client_settings.mjs'),{NetworkLoginIdentity}=await import('../../electron/network_login_identity.mjs'),{seedVaultHandoffFixture}=await import('./vault-handoff-fixture.mjs');
  const settingsFile=path.join(app.getPath('userData'),'client-settings.json'),digest=async()=>crypto.createHash('sha256').update(await fs.readFile(settingsFile)).digest('hex'),before=await digest();
  const settings=new ClientSettings({directory:app.getPath('userData'),encryption:safeStorage});credentials.cdKey=await settings.cdKey();identity=new NetworkLoginIdentity(credentials);credentials.cdKey='';
  const seed=await seedVaultHandoffFixture(JSON.parse(await fs.readFile(path.join(project,'reports',fixtureName),'utf8')),{identity,install:path.resolve(root,'../FullDecomp/NwnRootInstall')});
  seed.settingsUnchanged=before===await digest();if(!seed.settingsUnchanged)throw Error('Client settings changed during seed preparation');
  await fs.writeFile(report,JSON.stringify(seed,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({report,source:seed.source,bytes:seed.bytes,settingsUnchanged:seed.settingsUnchanged,networkConnections:0}));
 }catch{console.error('Owned vault seeding failed; inspect the authored fixture and protected settings availability');exitCode=1;}finally{credentials.cdKey='';identity?.dispose();}app.exit(exitCode);
});
