import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {ClientSettings,defaultModsDirectory} from '../electron/client_settings.mjs';
const fixtureKey=Array.from({length:7},()=>String.fromCharCode(65).repeat(5)).join('-');
const encryption={isEncryptionAvailable:()=>true,encryptString:value=>Buffer.from(value).map(b=>b^91),decryptString:bytes=>Buffer.from(bytes).map(b=>b^91).toString()};
async function cleanup(directory){assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));assert.match(path.basename(directory),/^nwn-(client-settings|workshop-default)-/);await fs.rm(directory,{recursive:true,force:true});}
test('saved key and mods folder survive store recreation without metadata or plaintext readback',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-client-settings-')),mods=path.join(directory,'mods');await fs.mkdir(mods);try{const store=new ClientSettings({directory,encryption,modsDirectory:mods});assert.equal((await store.status()).modsDirectory,mods);const status=await store.update({cdKey:fixtureKey});assert.equal(status.hasSavedCdKey,true);assert.ok(!JSON.stringify(status).includes(fixtureKey));assert.ok(!(await fs.readFile(path.join(directory,'client-settings.json'),'utf8')).includes(fixtureKey));
  const reopened=new ClientSettings({directory,encryption,modsDirectory:'other'});assert.equal(await reopened.cdKey(),fixtureKey);assert.equal((await reopened.status()).modsDirectory,mods);await reopened.update({disabledMods:['22']});assert.deepEqual((await new ClientSettings({directory,encryption}).status()).disabledMods,['22']);await reopened.update({removeCdKey:true});assert.equal((await reopened.status()).hasSavedCdKey,false);await assert.rejects(reopened.cdKey(),/Save or enter/);
 }finally{await cleanup(directory);}
});
test('unavailable OS protection and rejected changes preserve the existing saved key',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-client-settings-'));try{const store=new ClientSettings({directory,encryption});await store.update({cdKey:fixtureKey});const before=await fs.readFile(path.join(directory,'client-settings.json'),'utf8'),locked=new ClientSettings({directory,encryption:{...encryption,isEncryptionAvailable:()=>false}});await assert.rejects(locked.update({cdKey:fixtureKey}),/protected key storage/);await assert.rejects(locked.cdKey(),/protected key storage/);await assert.rejects(store.update({modsDirectory:'relative'}),/valid mods folder/);await assert.rejects(store.update({cdKey:'invalid'}),/seven groups/);assert.equal(await fs.readFile(path.join(directory,'client-settings.json'),'utf8'),before);
  await Promise.all([store.update({modsDirectory:directory}),store.update({cdKey:fixtureKey})]);const reopened=new ClientSettings({directory,encryption});assert.equal((await reopened.status()).modsDirectory,directory);assert.equal(await reopened.cdKey(),fixtureKey);
 }finally{await cleanup(directory);}
});
test('default Workshop content discovery follows the installed Steam libraries',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-workshop-default-')),steam=path.join(directory,'Steam'),library=path.join(directory,'Library'),mods=path.join(library,'steamapps/workshop/content/704450');try{await fs.mkdir(mods,{recursive:true});await fs.mkdir(path.join(steam,'steamapps'),{recursive:true});await fs.writeFile(path.join(steam,'steamapps/libraryfolders.vdf'),'"path" "'+library.replaceAll('\\','\\\\')+'"');assert.equal(await defaultModsDirectory(path.join(directory,'install'),{steamDirectory:steam}),mods);}finally{await cleanup(directory);}
});

test('login profiles persist protected name/key pairs and migrate an existing saved key explicitly',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-client-settings-')),secondKey=fixtureKey.replaceAll('A','B');
 try{const store=new ClientSettings({directory,encryption});await store.update({cdKey:fixtureKey});
  let status=await store.saveProfile({label:'Main',playerName:'Main Player'});const main=status.activeProfileId;
  assert.equal(status.loginProfiles[0].playerName,'Main Player');assert.equal(await store.cdKey(),fixtureKey);
  status=await store.saveProfile({label:'Alt',playerName:'Alt Player',cdKey:secondKey});const alt=status.activeProfileId;assert.notEqual(main,alt);assert.equal(await store.cdKey(),secondKey);
  const disk=await fs.readFile(path.join(directory,'client-settings.json'),'utf8');assert.ok(!disk.includes(fixtureKey)&&!disk.includes(secondKey));assert.equal(JSON.parse(disk).version,2);
  assert.ok(!JSON.stringify(status).includes('protectedCdKey')&&!JSON.stringify(status).includes(secondKey));
  const reopened=new ClientSettings({directory,encryption});assert.equal((await reopened.status()).activeProfileId,alt);assert.equal(await reopened.cdKey(),secondKey);
  await reopened.selectProfile(main);assert.equal(await reopened.cdKey(),fixtureKey);await reopened.saveProfile({id:main,label:'Main renamed',playerName:'Updated Player'});assert.equal(await reopened.cdKey(),fixtureKey);
  assert.equal((await new ClientSettings({directory,encryption}).status()).loginProfiles.find(p=>p.id===main).playerName,'Updated Player');
 }finally{await cleanup(directory);}
});

test('profile validation and protection failures leave saved pairs intact',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-client-settings-'));
 try{const store=new ClientSettings({directory,encryption});let status=await store.saveProfile({label:'Main',playerName:'Player',cdKey:fixtureKey});const id=status.activeProfileId,before=await fs.readFile(path.join(directory,'client-settings.json'),'utf8');
  for(const request of [{label:'main',playerName:'Other',cdKey:fixtureKey},{id:'missing',label:'X',playerName:'P'},{label:'New',playerName:'P'},{label:'Bad\nName',playerName:'P',cdKey:fixtureKey},{label:'Name',playerName:'P',cdKey:'invalid'}])await assert.rejects(store.saveProfile(request));
  assert.equal(await fs.readFile(path.join(directory,'client-settings.json'),'utf8'),before);
  const unavailable=new ClientSettings({directory,encryption:{...encryption,isEncryptionAvailable:()=>false}});await assert.rejects(unavailable.saveProfile({id,label:'Main',playerName:'P',cdKey:fixtureKey}),/Windows-protected/);await assert.rejects(unavailable.cdKey(),/Windows-protected/);assert.equal(await fs.readFile(path.join(directory,'client-settings.json'),'utf8'),before);
  await store.update({removeCdKey:true});assert.equal((await store.status()).loginProfiles[0].hasSavedCdKey,false);await assert.rejects(store.cdKey(),/Save or enter/);
 }finally{await cleanup(directory);}
});

test('profile deletion and selection are exact and do not delete another protected login',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-client-settings-')),secondKey=fixtureKey.replaceAll('A','B');
 try{const store=new ClientSettings({directory,encryption});let status=await store.saveProfile({label:'Main',playerName:'P1',cdKey:fixtureKey});const main=status.activeProfileId;status=await store.saveProfile({label:'Alt',playerName:'P2',cdKey:secondKey});const alt=status.activeProfileId;
  await assert.rejects(store.selectProfile('unknown'));await store.deleteProfile(main);assert.equal(await store.cdKey(),secondKey);assert.equal((await store.status()).loginProfiles.length,1);
  await store.deleteProfile(alt);assert.equal((await store.status()).activeProfileId,null);assert.equal((await store.status()).hasSavedCdKey,false);await assert.rejects(store.cdKey());
 }finally{await cleanup(directory);}
});
