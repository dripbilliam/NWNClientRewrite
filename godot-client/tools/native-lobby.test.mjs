import {test} from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeLobby,lobbyChoice} from './native-lobby.mjs';
import protocol from './local-protocol.cjs';
test('last-seen appearance account scope is cleared before every new login',async()=>{
 const f=fixture({local:false});await f.join();assert.equal(f.lobby.snapshot().previewAccountScope,'');f.lobby.previewAccountScope='a'.repeat(64);f.lobby.emit();assert.equal(f.events.at(-1).state.previewAccountScope,'a'.repeat(64));await f.lobby.leave({connection:f.lobby.connection,saveCharacter:false});await f.join();assert.equal(f.lobby.snapshot().previewAccountScope,'');assert.equal(f.lobby.snapshot().selected,null);
});
const later=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};
class Session extends EventEmitter{
 constructor(local=true){super();this.localVaultAllowed=local;this.phase='character-selection';this.closed=false;this.characterListGeneration=1;this.calls=[];}
 state(phase){this.phase=phase;this.closed=phase==='closed';this.emit('state',{phase,closed:this.closed});}
 async previewLocalCharacter(bytes){this.calls.push(['preview-local',Array.from(bytes)]);return{firstName:{text:'Test'},abilities:{Str:12}};}
 async previewServerCharacter(request){this.calls.push(['preview-server',request]);}
 async selectCharacter(bytes){this.calls.push(['upload',Array.from(bytes)]);this.characterSubmitted=true;this.state('character');}
 async playServerCharacter(request){this.calls.push(['play-server',request]);this.characterSubmitted=true;this.state('character');}
}
function fixture({local=true,readLocal,disconnect,save,resolveName}={}){
 const events=[],reads=[],sessions=[],wiped=[];let lobby;
 lobby=new NativeLobby({listLocal:async()=>[{key:'installed:wizard.bic',label:'Wizard',source:'installed',file:'PRIVATE/PATH/wizard.bic'},{key:'vault:owned',label:'Saved',source:'vault',vaultId:'owned'}],readLocal:readLocal??(async key=>{reads.push(key);const bytes=Uint8Array.of(1,2,3);wiped.push(bytes);return bytes;}),connect:async connection=>{const session=new Session(local);sessions.push(session);lobby.attach(session,connection);session.state('character-selection');},disconnect:disconnect??(async()=>{sessions.at(-1).state('closed');}),save:save??(async()=>({id:'saved-id',name:'Saved test'})),publish:e=>events.push(e),resolveName});
 return{lobby,events,reads,sessions,wiped,join:()=>lobby.join({connection:lobby.connection}),choose:key=>lobby.choose({connection:lobby.connection,key}),play:key=>lobby.play({connection:lobby.connection,key})};
}
test('joining opens a character lobby and never uploads a hardwired character',async()=>{
 const f=fixture();await f.join();assert.equal(f.lobby.connection,1);assert.equal(f.lobby.snapshot().canSelect,true);assert.equal(f.sessions[0].calls.length,0);assert.equal(f.lobby.snapshot().choices.length,2);assert.equal(JSON.stringify(f.events).includes('PRIVATE/PATH'),false);
});
test('native local deletion refresh acknowledges exact ownership and makes no gameplay request',async()=>{
 const f=fixture();await f.join();const key='installed:wizard.bic',row=f.lobby.locals.get(key);row.nativeFile={sha256:'a'.repeat(64)};await f.choose(key);const before=f.sessions[0].calls.length;f.lobby.listLocal=async()=>[{key:'local:next',label:'Next',source:'local'}];await f.lobby.refreshLocal({connection:1,key,sha256:'a'.repeat(64),requestId:4});assert.deepEqual(f.lobby.snapshot().localRefreshAck,{connection:1,key,requestId:4});assert.deepEqual(f.lobby.snapshot().choices.map(v=>v.key),['local:next']);assert.equal(f.lobby.selected,null);assert.equal(f.lobby.preview,null);assert.equal(f.sessions[0].calls.length,before);assert.equal(f.lobby.busy,false);
});
test('local refresh rejects stale, mismatched and server identities before scanning',async()=>{
 const f=fixture();await f.join();const key='installed:wizard.bic';f.lobby.locals.get(key).nativeFile={sha256:'a'.repeat(64)};let scans=0;f.lobby.listLocal=async()=>{scans++;return[];};for(const message of [{connection:0,key,sha256:'a'.repeat(64),requestId:1},{connection:1,key,sha256:'b'.repeat(64),requestId:1},{connection:1,key,sha256:'a'.repeat(64),requestId:0}])await assert.rejects(f.lobby.refreshLocal(message));assert.equal(scans,0);
 const remote=fixture({local:false});await remote.join();const s=remote.sessions[0];await remote.lobby.serverList({generation:1,characters:[{source:17,resref:'pc',firstName:{text:'Server'},lastName:{text:'Only'}}]},s,1);await assert.rejects(remote.lobby.refreshLocal({connection:1,key:'server:17:pc',sha256:'a'.repeat(64),requestId:1}),/unavailable/);
});
test('local refresh failure releases ownership with an explicit negative acknowledgment',async()=>{
 const f=fixture();await f.join();const key='installed:wizard.bic';f.lobby.locals.get(key).nativeFile={sha256:'a'.repeat(64)};await f.choose(key);f.lobby.listLocal=async()=>{throw Error('Owned fixture scan failure');};await f.lobby.refreshLocal({connection:1,key,sha256:'a'.repeat(64),requestId:8});assert.equal(f.lobby.busy,false);assert.equal(f.lobby.snapshot().localRefreshAck.accepted,false);assert.equal(f.lobby.snapshot().localRefreshAck.requestId,8);assert.match(f.lobby.error,/could not be refreshed/);
});
test('a local rescan finishing after disconnect cannot publish into a new lobby',async()=>{
 const f=fixture(),gate=later();await f.join();const key='installed:wizard.bic';f.lobby.locals.get(key).nativeFile={sha256:'a'.repeat(64)};await f.choose(key);f.lobby.listLocal=()=>gate.promise;const work=f.lobby.refreshLocal({connection:1,key,sha256:'a'.repeat(64),requestId:9});assert.equal(f.lobby.busy,true);await f.lobby.leave({connection:1,saveCharacter:false});gate.resolve([{key:'local:stale',source:'local'}]);await work;assert.equal(f.lobby.connection,2);assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.snapshot().localRefreshAck,null);assert.equal(f.lobby.locals.has('local:stale'),false);
});
test('installed alias misses dismiss only that row for the current chooser session',async()=>{
 const f=fixture();await f.join();const key='installed:wizard.bic',row=f.lobby.locals.get(key);row.nativeFile={sha256:'a'.repeat(64),storageSource:'installed'};await f.choose(key);const rows=[...f.lobby.locals.values()];f.lobby.listLocal=async()=>rows;await f.lobby.refreshLocal({connection:1,key,sha256:'a'.repeat(64),requestId:10,dismissInstalled:true});assert.equal(f.lobby.locals.has(key),false);assert.equal(f.lobby.locals.has('vault:owned'),true);await f.lobby.leave({connection:1,saveCharacter:false});await f.join();assert.equal(f.lobby.locals.has(key),true);assert.equal(f.lobby.hiddenLocalRows.size,0);
});
test('profile files cannot masquerade as installed-only dismissal',async()=>{
 const f=fixture();await f.join();const key='installed:wizard.bic';f.lobby.locals.get(key).nativeFile={sha256:'a'.repeat(64),storageSource:'local'};await f.choose(key);await assert.rejects(f.lobby.refreshLocal({connection:1,key,sha256:'a'.repeat(64),requestId:11,dismissInstalled:true}),/storage role/);assert.equal(f.lobby.busy,false);
});
test('chooser forwards only public portrait/source/class metadata and respects server-vault admission',async()=>{
 const raw={key:'server:17:pc',label:'Named PC',source:'server',serverSource:17,portrait:65535,portraitRef:'po_clsbard_',classes:[{id:3,level:4}],file:'PRIVATE/pc.bic',credentials:{password:'PRIVATE'},vaultId:'PRIVATE'};
 assert.deepEqual(lobbyChoice(raw),{key:raw.key,label:raw.label,source:'server',classes:raw.classes,serverSource:17,portrait:65535,portraitRef:'po_clsbard_'});
 const f=fixture({local:false});await f.join();const s=f.sessions[0];await f.lobby.serverList({generation:1,characters:[{...raw,source:17,resref:'pc',firstName:{text:'Named'},lastName:{text:'PC'}}]},s,1);
 const rows=f.lobby.snapshot().choices;assert.equal(rows.length,1);assert.equal(rows[0].portraitRef,'po_clsbard_');assert.equal(rows[0].serverSource,17);assert.equal(JSON.stringify(rows).includes('PRIVATE'),false);
});
test('character selection acknowledges its validated nonce before preview work and cannot acknowledge invalid or stale requests',async()=>{
 const gate=later(),f=fixture({readLocal:async()=>{await gate.promise;return Uint8Array.of(1);}});await f.join();
 const choosing=f.lobby.choose({connection:1,key:'vault:owned',requestId:7});
 assert.deepEqual(f.lobby.snapshot().selectionAck,{connection:1,key:'vault:owned',requestId:7});assert.equal(f.lobby.preview,null);
 await assert.rejects(f.lobby.choose({connection:1,key:'vault:owned',requestId:0}),/identity/);
 await assert.rejects(f.lobby.choose({connection:0,key:'vault:owned',requestId:8}),/old connection/);
 assert.equal(f.lobby.snapshot().selectionAck.requestId,7);gate.resolve();await choosing;assert.equal(f.lobby.preview.abilities.Str,12);
});
test('native creation requires ready admitted resources and blocks unrelated vault selection until its draft closes',async()=>{const f=fixture();await f.join();assert.equal(f.lobby.snapshot().canCreate,false);f.sessions[0].resourceResult={ready:true};f.sessions[0].resolver={};assert.equal(f.lobby.snapshot().canCreate,true);f.lobby.creating=true;assert.equal(f.lobby.snapshot().canCreate,false);assert.equal(f.lobby.snapshot().canSelect,false);await assert.rejects(f.choose('installed:wizard.bic'),/unavailable/);f.lobby.creating=false;await f.choose('installed:wizard.bic');assert.equal(f.lobby.selected,'installed:wizard.bic');});
test('local preview and play wipe their independent character buffers',async()=>{
 const f=fixture();await f.join();await f.choose('vault:owned');assert.equal(f.lobby.preview.abilities.Str,12);await f.play('vault:owned');assert.equal(f.lobby.vaultId,'owned');assert.deepEqual(f.reads,['vault:owned','vault:owned']);assert.ok(f.wiped.every(b=>b.every(v=>v===0)));assert.equal(f.sessions[0].calls.filter(c=>c[0]==='upload').length,1);await assert.rejects(f.play('vault:owned'));
});
test('server-vault policy hides local choices and prevents local path injection',async()=>{
 const f=fixture({local:false});await f.join();assert.deepEqual(f.lobby.snapshot().choices,[]);await assert.rejects(f.choose('installed:wizard.bic'));await assert.rejects(f.choose('../../vault/file.bic'));assert.equal(f.reads.length,0);
});
test('late local preview cannot replace the newly selected character',async()=>{
 const f=fixture();await f.join();const waits=[later(),later()];let call=0;f.sessions[0].previewLocalCharacter=()=>waits[call++].promise;
 const a=f.choose('installed:wizard.bic');await Promise.resolve();const b=f.choose('vault:owned');await Promise.resolve();waits[1].resolve({name:'second'});await b;waits[0].resolve({name:'first'});await a;assert.equal(f.lobby.preview.name,'second');assert.ok(f.wiped.every(v=>v.every(n=>n===0)));
});

test('a local character read completing after admission cannot start a stale preview',async()=>{const wait=later(),bytes=Uint8Array.of(1,2,3),f=fixture({readLocal:()=>wait.promise});await f.join();const choice=f.choose('installed:wizard.bic');f.sessions[0].characterSubmitted=true;f.sessions[0].state('character');wait.resolve(bytes);await choice;assert.equal(f.sessions[0].calls.length,0);assert.deepEqual([...bytes],[0,0,0]);assert.equal(f.lobby.preview,null);});
test('advertised server references and source/generation reach the proven session API',async()=>{
 const f=fixture({local:false});await f.join();const session=f.sessions[0];await f.lobby.serverList({generation:1,characters:[{source:17,resref:'account_pc',firstName:{text:'Server'},lastName:{text:'Character'},classes:[{id:1,level:4}]}]},session,1);
 const key='server:17:account_pc';await f.choose(key);session.emit('message',{message:{kind:'server-character-preview',generation:1,source:17,resref:'wrong',preview:{wrong:true}}});assert.equal(f.lobby.preview,null);
 session.emit('message',{message:{kind:'server-character-preview',generation:1,source:17,resref:'account_pc',preview:{name:'correct'}}});assert.equal(f.lobby.preview.name,'correct');await f.play(key);assert.deepEqual(session.calls.at(-1),['play-server',{source:17,resref:'account_pc',generation:1}]);assert.equal(f.reads.length,0);
});
test('stale server lists and previews cannot mutate a replacement connection',async()=>{
 const f=fixture();await f.join();const old=f.sessions[0];await f.lobby.leave({connection:1,saveCharacter:false});await f.join();assert.equal(f.lobby.connection,3);
 await f.lobby.serverList({generation:1,characters:[{source:2,resref:'old',firstName:{text:'Stale'}}]},old,1);old.emit('message',{message:{kind:'server-character-preview',generation:1,source:2,resref:'old',preview:{name:'old'}}});assert.equal(f.lobby.servers.size,0);assert.equal(f.lobby.preview,null);await assert.rejects(f.lobby.choose({connection:1,key:'vault:owned'}));
});
test('save failure releases the connection and preserves the failure for the user',async()=>{
 const f=fixture({disconnect:async()=>{throw Error('Server export timed out');}});await f.join();f.sessions[0].state('playing');await f.lobby.leave({connection:1,saveCharacter:true});assert.equal(f.lobby.connection,2);assert.equal(f.lobby.snapshot().connected,false);assert.equal(f.lobby.busy,false);assert.equal(f.lobby.error,'Server export timed out');
});
test('closed callback does not admit a new login before disconnect cleanup completes',async()=>{
 const wait=later(),f=fixture({disconnect:async()=>{f.sessions[0].state('closed');await wait.promise;}});await f.join();const leave=f.lobby.leave({connection:1,saveCharacter:false});assert.equal(f.lobby.snapshot().canJoin,false);await assert.rejects(f.join());wait.resolve();await leave;assert.equal(f.lobby.snapshot().canJoin,true);
});
test('pending upload cannot be duplicated by Play double-click',async()=>{
 const gate=later(),f=fixture({readLocal:async()=>{await gate.promise;return Uint8Array.of(9);}});await f.join();f.lobby.selected='installed:wizard.bic';const first=f.play('installed:wizard.bic');await assert.rejects(f.play('installed:wizard.bic'));gate.resolve();await first;assert.equal(f.sessions[0].calls.filter(c=>c[0]==='upload').length,1);
});
test('object updates do not republish identical character UI and steal menu visibility',async()=>{
 const f=fixture();await f.join();const count=f.events.length;for(let i=0;i<30;i++)f.sessions[0].state('character-selection');assert.equal(f.events.length,count);
});
test('late server name resolution retains an actively selected allowed local character',async()=>{
 const f=fixture();await f.join();await f.choose('vault:owned');await f.lobby.serverList({generation:1,characters:[]},f.sessions[0],1);assert.equal(f.lobby.selected,'vault:owned');assert.equal(f.lobby.preview.abilities.Str,12);
});
test('export persists a character and normal disconnect passes the chosen save policy',async()=>{
 const options=[],f=fixture({disconnect:async value=>{options.push(value);f.sessions[0].state('closed');}});await f.join();f.sessions[0].state('playing');await f.lobby.export({connection:1});assert.equal(f.lobby.vaultId,'saved-id');assert.ok(f.events.some(e=>e.kind==='character-saved'));await f.lobby.leave({connection:1,saveCharacter:true});assert.equal(options.length,1);assert.equal(options[0].saveCharacter,true);assert.equal(options[0].targetSession,f.sessions[0]);
});
test('area generation alone cannot authorize input from a previous connection',()=>{
 const current={connection:3,areaId:2147483649,generation:1},message={...current,kind:'walk',position:[3,0,-5]};assert.doesNotThrow(()=>protocol.validateCommand(message,current));assert.throws(()=>protocol.validateCommand({...message,connection:1},current),/Stale/);
});

test('server rejection remains visible after the character list is cleared',async()=>{
 const f=fixture({local:false});await f.join();const s=f.sessions[0];s.closed=true;s.emit('state',{phase:'closed',closed:true,disconnectReason:{strRef:10452,text:'Test rejection'}});
 assert.equal(f.lobby.snapshot().error,'Test rejection');assert.equal(f.lobby.snapshot().choices.length,0);
 s.emit('state',{phase:'closed',closed:true,disconnectReason:{strRef:10452,text:''}});assert.match(f.lobby.error,/10452/);
});
