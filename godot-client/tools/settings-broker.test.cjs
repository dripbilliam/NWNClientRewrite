const test=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');const {installSettingsBroker}=require('./settings-broker.cjs'),{createSettingsClient}=require('./settings-client.cjs');
function pair(){const a=new EventEmitter(),b=new EventEmitter();for(const [left,right]of[[a,b],[b,a]]){left.connected=true;left.send=(value,callback)=>{const copy=structuredClone(value);queueMicrotask(()=>right.emit('message',copy));callback?.(null);};}return[a,b];}
test('inherited IPC dynamically reads selected credentials and publishes metadata separately',async()=>{
 const [parent,child]=pair(),key=Array(7).fill('AAAAA').join('-'),alt=key.replaceAll('A','B');let selected='main';const statuses=[];
 const store={status:async()=>({activeProfileId:selected,loginProfiles:[]}),selectProfile:async id=>{selected=id;return store.status();},cdKey:async()=>selected==='main'?key:alt};const remove=installSettingsBroker(parent,store),client=createSettingsClient({transport:child,onStatus:s=>statuses.push(s)});
 assert.equal(await client.cdKey(),key);await client.selectProfile('alt');assert.equal(await client.cdKey(),alt);assert.ok(!JSON.stringify(statuses).includes(key)&&!JSON.stringify(statuses).includes(alt));
 client.close();remove();assert.equal(child.listenerCount('message'),0);assert.equal(parent.listenerCount('message'),0);
});
test('broker failures and disconnects reject pending requests without credential-bearing errors',async()=>{
 const [parent,child]=pair();let release;const remove=installSettingsBroker(parent,{status:()=>new Promise(r=>release=r)}),client=createSettingsClient({transport:child});const waiting=client.status();await new Promise(r=>setImmediate(r));child.connected=false;child.emit('disconnect');await assert.rejects(waiting,/broker closed/);release({});remove();
});

test('owned test keys remain ephemeral and fixed local resource settings cannot mutate an active saved profile',async()=>{
 const {credentialSettings}=require('./settings-client.cjs');const client={status:async()=>({modsDirectory:'user-mods',hasSavedCdKey:true}),cdKey:async()=>'saved-fixture-key'};
 const local=credentialSettings(client,()=>({modsDirectory:'owned-fixture-mods',hasSavedCdKey:true}),()=>'private-fixture-key',{fixedResources:true});
 assert.equal(await local.cdKey(),'private-fixture-key');assert.equal((await local.status()).modsDirectory,'owned-fixture-mods');
 const defaultFixture=credentialSettings(client,()=>({modsDirectory:'owned-fixture-mods',hasSavedCdKey:true}),()=>'',{fixedResources:true});assert.equal(await defaultFixture.cdKey(),'saved-fixture-key');
 assert.equal(credentialSettings(client,()=>({}),()=>''),client);
});
