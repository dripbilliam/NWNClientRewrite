import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {EventEmitter} from 'node:events';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {NativeLobby} from './native-lobby.mjs';
import * as localFiles from './native-local-character-files.mjs';
import {discoverLocalCharacterFiles} from './native-local-character-discovery.mjs';
import {NetworkCharacterVault} from '../../electron/network_character_vault.mjs';
import {parseGff} from '../../src/gff.js';
import {writeGff,gffRecord,gffField} from '../../src/gff_writer.js';

const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const character=name=>writeGff('BIC ',gffRecord({FirstName:gffField(12,name),LastName:gffField(12,'Fixture'),Int:gffField(0,12)}));
const hostUrl=new URL('./native-session-host.cjs',import.meta.url);
const hostSource=await fs.readFile(hostUrl,'utf8');
// Execute the actual Host callback with all diagnostic fixture modes off.
// No Host startup, credential reads, sockets or game processes are invoked.
const body=hostSource.match(/readLocal:async (\(key,expectedFile\))=>\{([\s\S]*?)\},resolveName:async value=>/);
assert.ok(body,'Normal Host local-character reader remains identifiable');
const hostReader=vm.compileFunction('return async '+body[1]+'=>{'+body[2]+'};',
 ['localCatalog','vault','fs','path','directHandoffCheck','scriptFloatingOwned','levelSourceCheck','actionNpcCombatCheck','actionCheck','readCatalogCharacter'],{filename:fileURLToPath(hostUrl)});

async function fixture(t){
 const base=fileURLToPath(new URL('../reports/',import.meta.url));
 const directory=await fs.mkdtemp(path.join(base,'character-admission-'));
 t.after(async()=>{assert.equal(path.dirname(directory),path.resolve(base));await fs.rm(directory,{recursive:true,force:true});});
 const install=path.join(directory,'install'),profileDirectory=path.join(directory,'profile'),modsDirectory=path.join(directory,'workshop/content/704450');
 const vault=new NetworkCharacterVault(path.join(directory,'vault')),catalog=new Map(),previews=[],uploads=[],buffers=[],sessions=[];
 const read=hostReader(catalog,vault,fs,path,false,false,false,false,false,localFiles.readCatalogCharacter);
 let lobby;
 const scan=async()=>{
  const {rows}=await discoverLocalCharacterFiles({install,profileDirectory,modsDirectory});
  for(const entry of await vault.list())rows.push({key:'vault:'+entry.id,source:'vault',label:entry.name,vaultId:entry.id,file:path.join(vault.directory,'blobs',entry.sha256+'.bic')});
  catalog.clear();for(const row of rows){row.nativeFile=await localFiles.localCharacterFile(row.file);catalog.set(row.key,row);}
  return rows;
 };
 lobby=new NativeLobby({listLocal:scan,readLocal:async(key,expectedFile)=>{const bytes=await read(key,expectedFile);buffers.push(bytes);return bytes;},publish:()=>{},
  connect:async connection=>{
   const session=new EventEmitter();Object.assign(session,{closed:false,phase:'character-selection',localVaultAllowed:true,
    async previewLocalCharacter(bytes){const root=parseGff(bytes,'BIC ').root;const value={sha256:hash(bytes),name:root.FirstName.entries[0].text};previews.push(value);return value;},
    async selectCharacter(bytes){parseGff(bytes,'BIC ');uploads.push(hash(bytes));this.characterSubmitted=true;this.phase='character';},
   });sessions.push(session);lobby.attach(session,connection);
  },disconnect:async({targetSession})=>{targetSession.closed=true;targetSession.emit('state',{phase:'closed',closed:true});},
 });
 async function write(relative,bytes){const file=path.join(directory,relative);await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,bytes);return file;}
 return{directory,install,profileDirectory,modsDirectory,vault,catalog,lobby,previews,uploads,buffers,sessions,write,
  join:()=>lobby.join({connection:lobby.connection}),choose:key=>lobby.choose({connection:lobby.connection,key}),play:key=>lobby.play({connection:lobby.connection,key})};
}

test('normal Host preview and Play retain unusual filenames and resolved Workshop alias identity',async t=>{
 const f=await fixture(t),name='Éowyn #2 [alpha].BIC',installed=character('Local'),workshop=character('Shared');
 const installFile=await f.write('install/data/lcv/'+name,installed);
 await f.write('profile/localvault/'+name,character('Profile'));
 const workshopFile=await f.write('workshop/content/704450/11/localvault/'+name,workshop);
 await f.join();assert.equal(f.catalog.size,3);assert.ok([...f.catalog.values()].every(row=>row.file===workshopFile));
 for(const row of f.catalog.values())await f.choose(row.key);
 assert.ok(f.previews.every(value=>value.name==='Shared'&&value.sha256===hash(workshop)));
 const selected=f.lobby.selected;await f.play(selected);assert.deepEqual(f.uploads,[hash(workshop)]);
 assert.ok(f.buffers.every(bytes=>bytes.every(value=>value===0)));assert.equal(hash(await fs.readFile(installFile)),hash(installed));assert.equal(hash(await fs.readFile(workshopFile)),hash(workshop));
});

test('normal Host refuses a same-size file replacement before preview instead of selecting another character',async t=>{
 const f=await fixture(t),before=character('Alpha'),after=character('Bravo');assert.equal(before.length,after.length);
 const file=await f.write('profile/localvault/hero.bic',before);await f.join();await fs.writeFile(file,after);
 await assert.rejects(f.choose('local:hero.bic'),/character.*changed/i);assert.deepEqual(f.previews,[]);assert.deepEqual(f.uploads,[]);assert.equal(f.lobby.busy,false);assert.equal(hash(await fs.readFile(file)),hash(after));
});

test('normal Host refuses a changed Workshop alias between preview and Play and reconnect admits the refreshed identity',async t=>{
 const f=await fixture(t),before=character('Alpha'),after=character('Bravo');
 await f.write('install/data/lcv/shared.bic',character('Installed'));
 const file=await f.write('workshop/content/704450/11/localvault/shared.bic',before);await f.join();
 await f.choose('installed:shared.bic');assert.equal(f.lobby.preview.name,'Alpha');await fs.writeFile(file,after);
 await assert.rejects(f.play('installed:shared.bic'),/character.*changed/i);assert.deepEqual(f.uploads,[]);assert.equal(f.lobby.busy,false);
 await f.lobby.leave({connection:f.lobby.connection,saveCharacter:false});await f.join();await f.choose('installed:shared.bic');await f.play('installed:shared.bic');assert.equal(f.lobby.preview.name,'Bravo');assert.deepEqual(f.uploads,[hash(after)]);
});

test('normal Host refuses an application-vault revision that differs from the displayed immutable blob',async t=>{
 const f=await fixture(t),before=character('Alpha'),after=character('Bravo'),entry=await f.vault.save({data:before});
 await f.join();const key='vault:'+entry.id;await f.choose(key);assert.equal(f.lobby.preview.name,'Alpha');
 await f.vault.save({data:after},{id:entry.id});await assert.rejects(f.play(key),/character.*changed/i);assert.deepEqual(f.uploads,[]);assert.equal(f.lobby.busy,false);
 const current=await f.vault.entry(entry.id);assert.equal(current.sha256,hash(after));assert.equal(hash(await fs.readFile(f.catalog.get(key).file)),hash(before));
});

test('a catalog key rebound to another alias cannot replace the displayed row identity',async t=>{
 const f=await fixture(t),before=character('Alpha'),after=character('Bravo');
 await f.write('profile/localvault/hero.bic',before);await f.join();
 const replacement=await f.write('workshop/content/704450/11/localvault/hero.bic',after),key='local:hero.bic';
 f.catalog.set(key,{...f.catalog.get(key),file:replacement,nativeFile:await localFiles.localCharacterFile(replacement)});
 await assert.rejects(f.choose(key),/character.*(changed|identity)/i);assert.deepEqual(f.previews,[]);assert.deepEqual(f.uploads,[]);
});

test('a verified local read completing after disconnect cannot preview or upload into the next connection',async t=>{
 const f=await fixture(t),bytes=character('Alpha'),entry=await f.vault.save({data:bytes});await f.join();
 const savedRead=f.vault.read.bind(f.vault),pendingBytes=await savedRead(entry.id);let resolve;
 f.vault.read=()=>new Promise(accept=>resolve=accept);
 const pending=f.choose('vault:'+entry.id);await f.lobby.leave({connection:f.lobby.connection,saveCharacter:false});await f.join();resolve(pendingBytes);await pending;
 assert.deepEqual(f.previews,[]);assert.deepEqual(f.uploads,[]);assert.equal(f.lobby.preview,null);assert.equal(f.lobby.connection,3);assert.ok(pendingBytes.every(value=>value===0));
});
