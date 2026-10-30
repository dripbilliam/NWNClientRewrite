import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {EventEmitter} from 'node:events';
import {ClientSettings} from '../../electron/client_settings.mjs';import {LoginProfileService} from './login-profile-service.mjs';import {ServerBrowserService} from './server-browser-service.mjs';import {ServerBrowserStore} from './server-browser-store.mjs';import {ServerEndpointPolicy} from './server-endpoint.mjs';import {NativeLobby} from './native-lobby.mjs';import protocol from './local-protocol.cjs';
const key=Array(7).fill('AAAAA').join('-'),altKey=key.replaceAll('A','B'),encryption={isEncryptionAvailable:()=>true,encryptString:s=>Buffer.from(s).map(b=>b^91),decryptString:b=>Buffer.from(b).map(v=>v^91).toString()};
async function fixture(t){const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-login-profile-test-'));t.after(async()=>{assert.equal(path.dirname(directory),os.tmpdir());assert.ok(path.basename(directory).startsWith('nwn-login-profile-test-'));await fs.rm(directory,{recursive:true,force:true});});return{directory,store:new ClientSettings({directory,encryption})};}
test('profile switching updates the next local login name and dynamically selects its protected key',async t=>{
 const {store,directory}=await fixture(t);let s=await store.saveProfile({label:'Main',playerName:'Main Player',cdKey:key});const main=s.activeProfileId;s=await store.saveProfile({label:'Alt',playerName:'Alt Player',cdKey:altKey});const alt=s.activeProfileId,wire=[],logins=[];
 let lobby;lobby=new NativeLobby({listLocal:async()=>[],publish:()=>{},connect:async(connection,details)=>{logins.push({name:details.name,key:await store.cdKey()});const session=new EventEmitter();session.closed=false;session.phase='character-selection';lobby.attach(session,connection);},disconnect:async()=>{lobby.session.closed=true;},save:async()=>{}});
 const browser=new ServerBrowserService({lobby,policy:new ServerEndpointPolicy(),store:new ServerBrowserStore(path.join(directory,'servers.json')),settings:()=>store.status(),query:async()=>({}),discover:async()=>[],send:m=>wire.push(m)});
 await browser.command({connection:0,operation:'open'});assert.equal(wire.at(-1).direct.name,'Alt Player');
 const service=new LoginProfileService({store,connection:()=>lobby.connection,locked:()=>!lobby.snapshot().canJoin||browser.busy,send:m=>wire.push(m),onChange:s=>browser.adoptLoginProfile(s)});
 const command=(operation,fields={})=>service.command({kind:'login-profile-input',connection:lobby.connection,requestId:1,viewId:service.view?.id,operation,...fields});
 await command('open');await command('select',{profileId:main});const view=wire.findLast(m=>m.kind==='browser-view');assert.equal(view.direct.name,'Main Player');assert.equal(view.activeLoginProfile.label,'Main');
 assert.ok(!JSON.stringify(wire).includes(key)&&!JSON.stringify(wire).includes(altKey)&&!JSON.stringify(wire).includes('protectedCdKey'));
 await browser.command({connection:0,viewId:browser.view.id,operation:'join',direct:true,entryId:-1,values:{host:'127.0.0.1',port:5121,name:view.direct.name,password:'',cdKey:''}});
 assert.deepEqual(logins,[{name:'Main Player',key}]);await command('open');await command('select',{profileId:alt});assert.equal((await store.status()).activeProfileId,main);assert.match(wire.at(-1).text,/Disconnect/);
 await service.retire();await browser.retire();
});
test('profile views reject stale edits and scrub submitted keys even on failure',async t=>{
 const {store}=await fixture(t);let connection=1;const wire=[],service=new LoginProfileService({store,connection:()=>connection,locked:()=>false,send:m=>wire.push(m)});
 await service.command({connection,requestId:1,operation:'open'});const old=service.view.id;
 const values={label:'Main',playerName:'Player',cdKey:key};await service.command({connection,requestId:2,viewId:old,operation:'save',values});assert.equal(values.cdKey,'');assert.equal(wire.at(-1).profiles[0].label,'Main');
 const bad={label:'Old',playerName:'P',cdKey:altKey};await service.command({connection,requestId:3,viewId:old,operation:'save',values:bad});assert.equal(bad.cdKey,'');assert.match(wire.at(-1).text,/current/);assert.equal((await store.status()).loginProfiles.length,1);
 connection++;const stale={label:'Stale',playerName:'P',cdKey:key};await service.command({connection:1,requestId:4,viewId:service.view.id,operation:'save',values:stale});assert.equal(stale.cdKey,'');assert.equal((await store.status()).loginProfiles.length,1);
 await service.retire();
});
test('a slow metadata reply cannot reopen a dismissed profile manager',async()=>{
 let release;const wire=[],service=new LoginProfileService({store:{status:()=>new Promise(r=>release=r)},connection:()=>0,locked:()=>false,send:m=>wire.push(m)});
 const opening=service.command({connection:0,requestId:1,operation:'open'});await Promise.resolve();await service.command({connection:0,requestId:2,operation:'close'});release({loginProfiles:[]});await opening;assert.equal(wire.length,0);await service.retire();
});
test('profile protocol bounds identities and keeps mutation handles scoped',()=>{
 const current={connection:2},base={kind:'login-profile-input',connection:2,requestId:1,viewId:1,operation:'save',values:{label:'Main',playerName:'Player',cdKey:key}};assert.doesNotThrow(()=>protocol.validateCommand(base,current));
 for(const patch of [{connection:1},{viewId:-1},{values:{label:'L',playerName:'P',cdKey:'x'.repeat(42)}},{values:{label:'L',playerName:'P',path:'injected'}},{values:{label:'L\nX',playerName:'P'}}])assert.throws(()=>protocol.validateCommand({...base,...patch},current));
 assert.doesNotThrow(()=>protocol.validateCommand({...base,operation:'select',profileId:null},current));assert.throws(()=>protocol.validateCommand({...base,operation:'delete',profileId:null},current));
});
