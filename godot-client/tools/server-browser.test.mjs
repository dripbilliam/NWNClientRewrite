import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {EventEmitter} from 'node:events';
import {serverEndpoint,serverKey,parseAllowedServer,ServerEndpointPolicy} from './server-endpoint.mjs';
import {ServerBrowserStore,browserRow} from './server-browser-store.mjs';
import {ServerBrowserService} from './server-browser-service.mjs';
import {NativeLobby} from './native-lobby.mjs';
import {NativeCommandPump} from './native-command-pump.mjs';
import {matchesBrowserFilters} from './server-browser-filters.mjs';
import {selectBrowserColumn,stepBrowserSelection} from './server-browser-sort.mjs';
import protocol from './local-protocol.cjs';
const local={host:'127.0.0.1',port:5121},other={host:'unapproved.invalid',port:5121};
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};

test('240 unchanged original list-key instruction observations match one-row selection and nonwrapping boundaries',async()=>{
 const oracle=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-server-list-key-observations-v1.json',import.meta.url),'utf8'));assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,240);
 for(const row of oracle.rows){
  const handled=Boolean(row.pressed&&!row.disabled&&[0x2b,0x2c,0x2d,0x2e].includes(row.key)),direction=[0x2b,0x2d].includes(row.key)?-1:1;
  assert.equal(row.result,handled?1:0);assert.equal(handled?stepBrowserSelection(row.selected,row.count,direction):row.selected,row.after);
 }
});

test('4608 original sort-header/priority observations match direction and priority transitions',async()=>{
 const oracle=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-browser-sort-observations-v1.json',import.meta.url),'utf8'));assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,4608);
 for(const row of oracle.rows){const value=selectBrowserColumn(row,row.column);assert.deepEqual(value.order,row.resultOrder);assert.deepEqual(value.ascending,row.resultAscending);assert.equal(row.guiSortCalls,row.pending?0:1);}
});

test('original source sorting uses packed player counts, retains per-page state and preserves selected server identity',async t=>{
 const f=await fixture(t);f.service.internetRows=[
  {...local,port:5131,serverName:'Alpha',moduleName:'Prelude',playerCount:1,maximumPlayers:20},
  {...local,port:5132,serverName:'Bravo',moduleName:'Prelude',playerCount:1,maximumPlayers:99},
  {...local,port:5133,serverName:'Charlie',moduleName:'Prelude',playerCount:3,maximumPlayers:20}
 ].map(browserRow);
 await f.command('tab',{tab:'Internet',sourcePage:true});assert.equal(f.view().sourcePage,true);assert.deepEqual(f.view().rows.map(r=>r.serverName),['Charlie','Bravo','Alpha']);
 await f.command('select',{entryId:1});await f.command('sort-column',{column:2});assert.deepEqual(f.view().rows.map(r=>r.serverName),['Alpha','Bravo','Charlie']);assert.equal(f.view().rows.find(r=>r.selected).port,5132);
 await f.command('sort-column',{column:0});assert.deepEqual(f.view().sourceSort.order,[0,2,1,3,4,5]);
 await f.command('tab',{tab:'Favorites',sourcePage:true});assert.deepEqual(f.view().sourceSort.order,[0,1,2,3,4,5]);
 await f.command('tab',{tab:'Internet',sourcePage:true});assert.deepEqual(f.view().sourceSort.order,[0,2,1,3,4,5]);assert.equal(f.view().sourceSort.ascending[2],true);
 const handle=f.view().viewId;await f.command('sort-column',{column:0});assert.deepEqual(f.view().rows.map(r=>r.serverName),['Charlie','Bravo','Alpha']);await assert.rejects(f.command('select',{viewId:handle,entryId:1}),/stale/);
 await f.command('tab',{tab:'History',sourcePage:true});await assert.rejects(f.command('sort-column',{column:0}),/sort/);assert.equal(f.calls.length,0);
});

test('original Favorites Add and Remove are explicit, while legacy favorite input retains its toggle contract',async t=>{
 const f=await fixture(t);await f.store.favorite(local,true);await f.command('open');await f.command('tab',{tab:'Favorites',sourcePage:true});
 await f.command('favorite',{direct:false,entryId:0,on:true});assert.equal((await f.store.load()).favorites.length,1);
 await f.command('favorite',{direct:false,entryId:0,on:false});assert.equal((await f.store.load()).favorites.length,0);
 await f.command('favorite',{direct:true,values:{...local}});assert.equal((await f.store.load()).favorites.length,1);
 const base={kind:'browser-input',connection:0,viewId:f.view().viewId};for(const message of [{operation:'sort-column',column:6},{operation:'sort-column',column:-1},{operation:'tab',tab:'Internet',sourcePage:'yes'},{operation:'select',entryId:0,on:true},{operation:'favorite',direct:false,entryId:0,on:1}])assert.throws(()=>protocol.validateCommand({...base,...message},f.lobby));
});

test('all 4480 unchanged original modern row-filter instruction observations match the browser predicate',async()=>{
 const oracle=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-server-filter-observations-v1.json',import.meta.url),'utf8'));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,4480);
 for(const row of oracle.rows){
  const metadata={moduleName:row.module,playerCount:row.players,maximumPlayers:row.maximum,passwordRequired:row.password,allowLocalVaultCharacters:row.localVault};
  const advanced={hideEmpty:Boolean(row.flags&8),hideFull:Boolean(row.flags&16),module:row.flags&1024?row.needle:''},visibility={local:!(row.flags&4),server:!(row.flags&2),password:!(row.flags&1)};
  assert.equal(matchesBrowserFilters(metadata,advanced,visibility),row.admitted,JSON.stringify(row));
 }
});

test('original advanced filters persist and combine module/occupancy with the existing vault/password filters',async t=>{
 const f=await fixture(t),rows=[
  {...local,serverName:'Open',moduleName:'Prelude',playerCount:2,maximumPlayers:6,allowLocalVaultCharacters:true},
  {...local,port:5122,serverName:'Empty',moduleName:'Prelude',playerCount:0,maximumPlayers:6},
  {...local,port:5123,serverName:'Full',moduleName:'Prelude',playerCount:6,maximumPlayers:6},
  {...local,port:5124,serverName:'Wrong module',moduleName:'Chapter 1',playerCount:2,maximumPlayers:6},
  {...local,port:5125,serverName:'Server vault',moduleName:'Prelude',playerCount:2,maximumPlayers:6,allowLocalVaultCharacters:false},
  {...local,port:5126,serverName:'Locked',moduleName:'Prelude',playerCount:2,maximumPlayers:6,passwordRequired:true}
 ];for(const row of rows)await f.store.favorite(row,true);await f.command('open');await f.command('tab',{tab:'Favorites'});
 await f.command('filter',{filter:'',sort:'Name',filters:{local:true,server:false,password:false}});
 const original=f.view().filters,values={hideEmpty:true,hideFull:true,module:'Pre'};protocol.validateCommand({kind:'browser-input',connection:0,viewId:f.view().viewId,operation:'advanced-filter',values},f.lobby);
 await f.command('advanced-filter',{values:{...values}});assert.deepEqual(f.view().rows.map(r=>r.serverName),['Open']);assert.deepEqual(f.view().filters,original);assert.deepEqual(f.view().advancedFilters,values);
 assert.deepEqual((await new ServerBrowserStore(f.file).load()).browserFilters,values);await f.command('close');await f.command('open');assert.deepEqual(f.view().advancedFilters,values);assert.equal(f.calls.length,0);
});

test('modern original module filtering is literal and full means equal counts, including zero/zero',async t=>{
 const f=await fixture(t);for(const [i,row] of [
  {serverName:'Unknown counts',moduleName:'Prelude'}, {serverName:'Overfull',moduleName:'Prelude',playerCount:7,maximumPlayers:6},
  {serverName:'Zero',moduleName:'Prelude',playerCount:0,maximumPlayers:0}, {serverName:'Other case',moduleName:'prelude',playerCount:1,maximumPlayers:6}
 ].entries())await f.store.favorite({...local,port:5130+i,...row},true);
 await f.command('open');await f.command('tab',{tab:'Favorites'});await f.command('advanced-filter',{values:{hideEmpty:false,hideFull:true,module:'Prelude'}});
 assert.deepEqual(f.view().rows.map(r=>r.serverName).sort(),['Overfull','Unknown counts']);
 await f.command('advanced-filter',{values:{hideEmpty:false,hideFull:false,module:''}});assert.equal(f.view().rows.length,4);
});

test('filter storage refusal preserves committed choices and restores a usable authoritative error view',async t=>{
 const f=await fixture(t),before=f.view().advancedFilters;f.store.filters=async()=>{throw Error('Filter storage refused');};
 await f.command('advanced-filter',{values:{hideEmpty:true,hideFull:true,module:'Rejected'}});
 assert.deepEqual(f.view().advancedFilters,before);assert.equal(f.view().busy,false);assert.equal(f.view().status,'Filter storage refused');assert.deepEqual((await f.store.load()).browserFilters,before);
});

test('retired filter storage cannot revive an owner; the completed atomic preference is available on a later open',async t=>{
 const gate=deferred(),f=await fixture(t),save=f.store.filters.bind(f.store);f.store.filters=async v=>{await gate.promise;return save(v);};
 const work=f.command('advanced-filter',{values:{hideEmpty:true,hideFull:false,module:'Saved'}});await new Promise(r=>setImmediate(r));await f.command('close');const count=f.sent.length;gate.resolve();await work;
 assert.equal(f.service.opened,false);assert.equal(f.sent.length,count);await f.command('open');assert.deepEqual(f.view().advancedFilters,{hideEmpty:true,hideFull:false,module:'Saved'});
});

test('advanced filter malformed/stale input cannot alter settings and invalid saved filters are preserved for repair',async t=>{
 const f=await fixture(t),values={hideEmpty:false,hideFull:false,module:''},current=f.view();
 for(const invalid of [{...values,hideEmpty:1},{...values,module:'x'.repeat(1025)},{...values,module:'bad\nvalue'},{...values,extra:true},[]]){
  assert.throws(()=>protocol.validateCommand({kind:'browser-input',connection:0,viewId:current.viewId,operation:'advanced-filter',values:invalid},f.lobby));
  await assert.rejects(f.command('advanced-filter',{values:invalid}));
 }
 const before=await f.store.load();await assert.rejects(f.command('advanced-filter',{viewId:current.viewId,values:{...values,hideEmpty:true}}),/stale/);assert.deepEqual(await f.store.load(),before);
 const file=await temporary(t),raw=JSON.stringify({...before,browserFilters:{...values,hideFull:'yes'}});await fs.writeFile(file,raw);await assert.rejects(new ServerBrowserStore(file).load(),/advanced/);assert.equal(await fs.readFile(file,'utf8'),raw);
});

for(const operation of ['inspect','refresh','automatic-discovery'])test(`browser Back cancels pending ${operation} through the command pump and rejects retired completion`,async t=>{
 const gate=deferred();let signal;const f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),query:args=>{signal=args.signal;return gate.promise;},discover:args=>{signal=args.signal;return gate.promise;}});
 await f.command('profile',{values:{name:'Accepted identity',saveDefault:false}});
 if(operation==='refresh'){f.service.internetLoaded=true;await f.command('tab',{tab:'Internet'});}
 const before=f.view(),errors=[],pump=new NativeCommandPump(m=>f.service.command(m),e=>errors.push(e));
 const input=(op,extra={})=>({kind:'browser-input',connection:f.lobby.connection,viewId:before.viewId,operation:op,...extra});
 const pending=pump.push(input(operation==='automatic-discovery'?'tab':operation,operation==='inspect'?{direct:true,values:{...local}}:operation==='automatic-discovery'?{tab:'Internet'}:{}));
 await new Promise(r=>setImmediate(r));assert.equal(f.view().busy,true);assert.equal(signal.aborted,false);
 const cancel=input('return-menu');protocol.validateCommand(cancel,{connection:f.lobby.connection});await pump.push(cancel);
 const returned=f.view();assert.equal(signal.aborted,true);assert.equal(returned.busy,false);assert.equal(returned.tab,'Direct');assert.equal(returned.hasSessionProfile,true);assert.equal(returned.direct.name,'Accepted identity');assert.equal(returned.details,null);assert.ok(returned.viewId>before.viewId);
 await assert.rejects(f.service.command(cancel),/stale/);assert.equal(f.view(),returned);
 gate.resolve(operation==='inspect'?{serverName:'Retired query'}:[{...local,serverName:'Retired discovery'}]);await pending;
 assert.deepEqual(errors,[]);assert.equal(f.view(),returned);assert.deepEqual(f.service.internetRows,[]);assert.equal(f.calls.length,0);
});

test('return to Multiplayer refuses missing, future and earlier-opening handles without retiring the current provider',async t=>{
 const gate=deferred();let signal;const f=await fixture(t,{query:args=>{signal=args.signal;return gate.promise;}}),old=f.view().viewId;
 await f.command('close');await f.command('open');const work=f.command('inspect',{direct:true,values:{...local}});await new Promise(r=>setImmediate(r));const current=f.view();
 for(const viewId of [undefined,old,current.viewId+1])await assert.rejects(f.command('return-menu',{viewId}),/stale/);
 assert.equal(signal.aborted,false);assert.equal(f.view(),current);assert.throws(()=>protocol.validateCommand({kind:'browser-input',connection:0,operation:'return-menu'},{connection:0}),/view/);
 await f.command('return-menu');gate.resolve({});await work;assert.equal(f.view().busy,false);
});

test('an aborted discovery rejection cannot emit an error into the replacement Multiplayer presentation',async t=>{
 let aborted=false;const errors=[],f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),discover:({signal})=>new Promise((resolve,reject)=>signal.addEventListener('abort',()=>{aborted=true;reject(signal.reason);},{once:true}))});
 f.service.internetLoaded=true;await f.command('tab',{tab:'Internet'});const pump=new NativeCommandPump(m=>f.service.command(m),e=>errors.push(e));
 const message={kind:'browser-input',connection:f.lobby.connection,viewId:f.view().viewId,operation:'refresh'};
 const pending=pump.push(message);await new Promise(r=>setImmediate(r));await pump.push({...message,operation:'return-menu'});await pending;
 assert.equal(aborted,true);assert.deepEqual(errors,[]);assert.equal(f.view().busy,false);assert.equal(f.view().status,'');
});
async function temporary(t){const dir=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-browser-test-'));t.after(()=>fs.rm(dir,{recursive:true,force:true}));return path.join(dir,'browser.json');}
async function fixture(t,options={}){
 const calls=[],sent=[],events=[],file=await temporary(t);let lobby;
 lobby=new NativeLobby({listLocal:async()=>[],publish:()=>{},connect:async(connection,details)=>{calls.push({connection,details});if(options.connect)await options.connect(connection,details);const session=new EventEmitter();session.closed=false;session.phase='character-selection';lobby.attach(session,connection);},disconnect:async()=>{if(lobby.session)lobby.session.closed=true;},save:async()=>{}});
 const store=new ServerBrowserStore(file),policy=options.policy??new ServerEndpointPolicy();
 const service=new ServerBrowserService({lobby,store,policy,query:options.query??(async()=>({serverName:'Owned local',allowLocalVaultCharacters:true})),discover:options.discover??(async()=>[]),settings:options.settings??(async()=>({hasSavedCdKey:true})),send:m=>sent.push(m),onEvent:m=>events.push(m),...(options.now?{now:options.now}:{})});
 const command=(operation,extra={})=>service.command({kind:'browser-input',connection:lobby.connection,viewId:service.view?.id,operation,...extra});
 await command('open');return{service,lobby,store,file,calls,sent,events,command,view:()=>sent.findLast(m=>m.kind==='browser-view')};
}

test('Details queries extended metadata, keeps canonical endpoints and bounds the complete description frame',async t=>{
 let args;const description='\u0001'.repeat(65535),f=await fixture(t,{query:async input=>{args=input;return{...other,description,serverVersion:'8193.37',gameType:0,extendedReceived:true,pauseAndPlay:1,onePartyOnly:0};}});
 f.service.internetRows=[browserRow({...local,serverName:'Owned'})];await f.command('tab',{tab:'Internet'});await f.command('select',{entryId:0});await f.command('inspect',{entryId:0});
 assert.equal(args.extended,true);assert.equal(f.view().details.host,local.host);assert.equal(f.view().details.port,local.port);assert.equal(f.view().details.description,description);assert.equal(f.view().details.pauseAndPlay,true);assert.equal(f.view().details.onePartyOnly,false);assert.equal(f.view().details.extendedReceived,true);
 assert.ok(f.view().rows.every(row=>!Object.hasOwn(row,'description')&&!Object.hasOwn(row,'serverVersion')));assert.ok(Buffer.byteLength(JSON.stringify(f.view()))<protocol.MAX_FRAME);assert.equal(f.calls.length,0);
});

test('closing Details aborts its own lookup and cannot revive the dismissed presentation',async t=>{
 const gate=deferred();let signal;const f=await fixture(t,{query:input=>{signal=input.signal;return gate.promise;}}),request=f.view().viewId;
 const work=f.command('inspect',{direct:true,values:{...local}});await new Promise(r=>setImmediate(r));assert.equal(f.view().busy,true);
 await f.command('cancel-inspect',{viewId:request});assert.equal(signal.aborted,true);const idle=f.view();assert.equal(idle.busy,false);assert.equal(idle.inspecting,false);
 gate.resolve({serverName:'Late old server'});await work;assert.equal(f.view(),idle);assert.notEqual(f.view().details.serverName,'Late old server');
});

test('completion-before-Close acknowledges idle ownership, while an older Close cannot abort a newer Details lookup',async t=>{
 const gate=deferred();let count=0,signal;const f=await fixture(t,{query:input=>{count++;signal=input.signal;return count===1?{}:gate.promise;}}),old=f.view().viewId;
 await f.command('inspect',{direct:true,values:{...local}});const completed=f.view().viewId;await f.command('cancel-inspect',{viewId:old});assert.ok(f.view().viewId>completed);assert.equal(f.view().busy,false);
 const work=f.command('inspect',{direct:true,values:{...local}});await new Promise(r=>setImmediate(r));await assert.rejects(f.command('cancel-inspect',{viewId:old}),/stale/);assert.equal(signal.aborted,false);
 await f.command('cancel-inspect');gate.resolve({});await work;
});

test('Details Next traverses the full catalog across page boundaries and never queries blocked neighbors',async t=>{
 const calls=[],f=await fixture(t,{policy:new ServerEndpointPolicy({allowed:Array.from({length:130},(_,i)=>({...local,port:5200+i}))}),query:async value=>{calls.push(value);return{serverVersion:'8193.37'};}});
 f.service.internetRows=Array.from({length:130},(_,i)=>browserRow({...local,port:5200+i,serverName:`Server ${String(i).padStart(3,'0')}`}));
 await f.command('tab',{tab:'Internet'});await f.command('filter',{filter:'',sort:'Name',filters:{local:true,server:true,password:true}});await f.command('select',{entryId:127});
 await f.command('details-step',{direction:1});assert.equal(f.view().page,1);assert.equal(f.view().details.port,5328);assert.equal(f.view().detailsPosition.index,128);assert.equal(f.view().rows.find(row=>row.selected).entryId,0);assert.equal(calls.length,1);
 await f.command('details-step',{direction:1});assert.equal(f.view().detailsPosition.canNext,false);await assert.rejects(f.command('details-step',{direction:1}),/adjacent/);
 f.service.internetRows.push(browserRow({...other,serverName:'Z blocked'}));await f.command('details-step',{direction:1});assert.equal(f.view().details.allowed,false);assert.equal(calls.length,2);
 const base={kind:'browser-input',connection:f.lobby.connection,viewId:f.view().viewId};assert.doesNotThrow(()=>protocol.validateCommand({...base,operation:'cancel-inspect'},f.lobby));for(const direction of [0,2,'1'])assert.throws(()=>protocol.validateCommand({...base,operation:'details-step',direction},f.lobby));
});

test('source list arrow navigation follows original one-row nonwrapping policy across transport pages without networking',async t=>{
 let queries=0;const f=await fixture(t,{query:async()=>{queries++;return{};}});f.service.internetRows=Array.from({length:130},(_,i)=>browserRow({...local,port:5200+i,serverName:`Server ${String(i).padStart(3,'0')}`}));
 await f.command('tab',{tab:'Internet',sourcePage:true});await f.command('sort-column',{column:0});
 await f.command('selection-step',{direction:-1});assert.equal(f.view().detailsPosition.index,-1);
 await f.command('selection-step',{direction:1});assert.equal(f.view().detailsPosition.index,0);
 await f.command('selection-step',{direction:-1});assert.equal(f.view().detailsPosition.index,0);
 await f.command('select',{entryId:127});const stale=f.view().viewId;await f.command('selection-step',{direction:1});assert.equal(f.view().detailsPosition.index,128);assert.equal(f.view().page,1);assert.equal(f.view().rows[0].selected,true);
 await f.command('selection-step',{direction:1});assert.equal(f.view().detailsPosition.index,129);await f.command('selection-step',{direction:1});assert.equal(f.view().detailsPosition.index,129);
 await f.command('selection-step',{direction:-1});await f.command('selection-step',{direction:-1});assert.equal(f.view().detailsPosition.index,127);assert.equal(f.view().page,0);
 await assert.rejects(f.command('selection-step',{viewId:stale,direction:1}),/stale/);assert.equal(queries,0);assert.equal(f.calls.length,0);
 const base={kind:'browser-input',connection:f.lobby.connection,viewId:f.view().viewId,operation:'selection-step'};assert.doesNotThrow(()=>protocol.validateCommand({...base,direction:1},f.lobby));for(const direction of [0,2,'1',null])assert.throws(()=>protocol.validateCommand({...base,direction},f.lobby));
 await f.command('tab',{tab:'Direct'});await assert.rejects(f.command('selection-step',{direction:1}),/direction/);
});

test('selection acknowledgments bind their initiating view to the canonical endpoint and never leak into other responses',async t=>{
 const f=await fixture(t);f.service.internetRows=[browserRow({...local,serverName:'Owned'})];await f.command('tab',{tab:'Internet',sourcePage:true});
 const first=f.view().viewId;await f.command('select',{entryId:0});assert.deepEqual(f.view().selectionAck,{requestViewId:first,...local});assert.equal(f.view().rows[0].selected,true);
 await f.command('sort-column',{column:0});assert.equal(f.view().selectionAck,null);
 const step=f.view().viewId;await f.command('selection-step',{direction:1});assert.deepEqual(f.view().selectionAck,{requestViewId:step,...local});
 await assert.rejects(f.command('select',{entryId:100}),/Select/);assert.equal(f.view().selectionAck,null);assert.equal(f.calls.length,0);
 await f.command('tab',{tab:'History',sourcePage:true});assert.equal(f.view().selectionAck,null);assert.equal(f.view().rows.length,0);
 await f.command('selection-step',{direction:1});assert.equal(f.view().selectionAck,null);
});
test('canonical endpoint keys reject URLs, ambiguous numeric IPs, IPv6 and invalid UDP ports',()=>{
 assert.deepEqual(serverEndpoint({host:' LocalHost. ',port:5121}),local);assert.equal(serverKey({host:'EXAMPLE.Invalid.',port:42}),'example.invalid:42');
 for(const host of ['https://example.invalid','x:5121','::1','127.1','127.000.0.1','a..b','-x.invalid','x-.invalid','x_y',''])assert.throws(()=>serverEndpoint({host,port:5121}));
 for(const port of [0,-1,65536,5121.5,'5121'])assert.throws(()=>serverEndpoint({host:'localhost',port}));
 assert.deepEqual(parseAllowedServer('LOCALHOST:5121'),local);assert.throws(()=>parseAllowedServer('x:4:5'));
});
test('default endpoint policy blocks non-local destinations before any discovery or login work',()=>{const policy=new ServerEndpointPolicy();assert.ok(policy.permits(local));assert.ok(policy.localOnly);assert.throws(()=>policy.require(other),/No connection was sent/);const explicit=new ServerEndpointPolicy({allowed:[other]});assert.ok(explicit.permits(other));assert.equal(explicit.localOnly,false);});
test('catalog normalization strips credentials, paths, arbitrary objects and invalid count metadata',()=>{const row=browserRow({...local,password:'SECRET',cdKey:'SECRET',file:'private',playerCount:2.5,maximumPlayers:50,passwordRequired:0,allowLocalVaultCharacters:'false',advertisement:{hash:'manifest',url:'private'}});assert.equal(row.passwordRequired,false);assert.equal(row.sync,true);assert.equal(row.maximumPlayers,50);assert.equal(row.playerCount,undefined);assert.equal(row.allowLocalVaultCharacters,undefined);assert.equal(JSON.stringify(row).includes('SECRET'),false);assert.equal(row.advertisement,undefined);});
test('history and favorites persist across store recreation and legacy import happens only without a file',async t=>{
 const file=await temporary(t);let imports=0;const importer=async()=>{imports++;return{favorites:[{...local,cdKey:'SECRET'},local,{host:'bad/url',port:1}],history:[other]};};
 const store=new ServerBrowserStore(file,{importLegacy:importer});assert.equal((await store.load()).favorites.length,1);await Promise.all([store.favorite(other,true),store.remember({...local,password:'SECRET'},'Tester')]);
 const saved=await new ServerBrowserStore(file,{importLegacy:importer}).load();assert.equal(imports,1);assert.equal(saved.favorites.length,2);assert.equal(saved.history[0].host,local.host);assert.equal(saved.last.name,'Tester');assert.equal((await fs.readFile(file,'utf8')).includes('SECRET'),false);
 saved.favorites.length=0;assert.equal((await store.load()).favorites.length,2);
});
test('invalid existing browser file is preserved rather than overwritten by defaults',async t=>{const file=await temporary(t);await fs.writeFile(file,'{"version":9}');const store=new ServerBrowserStore(file);await assert.rejects(store.favorite(local,true),/invalid/);assert.equal(await fs.readFile(file,'utf8'),'{"version":9}');});
test('failed atomic commit leaves memory unchanged and a later operation can retry',async t=>{const file=await temporary(t),store=new ServerBrowserStore(file);await store.load();await fs.mkdir(file);await assert.rejects(store.favorite(local,true));assert.equal((await store.load()).favorites.length,0);await fs.rmdir(file);await store.favorite(local,true);assert.equal((await store.load()).favorites.length,1);assert.deepEqual(await fs.readdir(path.dirname(file)),['browser.json']);});
test('query policy is enforced before calling the injected network provider',async t=>{let queries=0;const f=await fixture(t,{query:async()=>{queries++;return{};}});await assert.rejects(f.command('inspect',{direct:true,values:other}),/No connection was sent/);assert.equal(queries,0);await f.command('inspect',{direct:true,values:local});assert.equal(queries,1);});
test('retired query completion cannot reopen or mutate a newer browser view',async t=>{const gate=deferred(),f=await fixture(t,{query:()=>gate.promise});const work=f.command('inspect',{direct:true,values:local});await Promise.resolve();await f.command('close');await f.command('open');const view=f.view();gate.resolve({serverName:'Retired'});await work;assert.equal(f.view(),view);assert.equal(f.view().details,null);});
test('opening permitted Internet discovery loads and paginates private row handles without a refresh click',async t=>{let fetches=0;const rows=Array.from({length:260},(_,i)=>({host:`server${i}.invalid`,port:5121,serverName:`Server ${i}`,playerCount:i}));const f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),discover:async()=>{fetches++;return[...rows,rows[0],{host:'bad/url',port:1}];}});await f.command('tab',{tab:'Internet'});assert.equal(fetches,1);assert.equal(f.view().rows.length,128);assert.equal(f.view().total,260);assert.equal(f.view().pages,3);assert.ok(f.view().rows.every(r=>!r.allowed));await f.command('page',{page:2});assert.equal(f.view().rows.length,4);const stale=f.service.view.id;await f.command('tab',{tab:'Favorites'});await assert.rejects(f.command('select',{viewId:stale,entryId:0}),/stale/);});
test('disabled Internet discovery performs no provider call',async t=>{let calls=0;const f=await fixture(t,{discover:async()=>{calls++;return[];}});await f.command('tab',{tab:'Internet'});await assert.rejects(f.command('refresh'),/not enabled/);assert.equal(calls,0);});
test('filter and sort apply to saved rows and selection cannot inject another endpoint',async t=>{const f=await fixture(t);await f.store.favorite({...local,serverName:'Owned',allowLocalVaultCharacters:true},true);await f.store.favorite({...other,serverName:'Other',allowLocalVaultCharacters:false,passwordRequired:true},true);await f.command('open');await f.command('tab',{tab:'Favorites'});assert.equal(f.view().rows.length,2);await f.command('filter',{filter:'',sort:'Name',filters:{local:true,server:false,password:true}});assert.equal(f.view().rows.length,1);assert.equal(f.view().rows[0].host,local.host);await f.command('select',{entryId:0,host:other.host});assert.equal(f.view().details.host,local.host);await assert.rejects(f.command('select',{entryId:99}),/current list/);});
test('direct login forwards transient credentials once, remembers only safe endpoint/name, and closes browser',async t=>{
 let observed,credentials;const f=await fixture(t,{connect:async(c,d)=>{observed={...d,credentials:{...d.credentials}};credentials=d.credentials;}});const values={...local,name:' Tester ',password:'test-password',cdKey:'test-key'};await f.command('join',{direct:true,values});
 assert.equal(observed.name,'Tester');assert.equal(observed.credentials.password,'test-password');assert.equal(f.lobby.connection,1);assert.equal(f.service.opened,false);assert.equal(f.sent.at(-1).kind,'browser-closed');assert.deepEqual(credentials,{password:'',cdKey:''});assert.equal(values.password,'');assert.equal(values.cdKey,'');assert.equal((await f.store.load()).history.length,1);assert.equal(JSON.stringify(f.sent).includes('test-password'),false);assert.equal((await fs.readFile(f.file,'utf8')).includes('test-password'),false);
});
test('login errors return to safe draft without saving history or retaining keys',async t=>{const f=await fixture(t,{connect:async()=>{throw Error('Auth rejected');}}),values={...local,name:'Tester',password:'SECRET',cdKey:''};await f.command('join',{direct:true,values});assert.equal(f.view().status,'Auth rejected');assert.equal(f.view().connection,f.lobby.connection);assert.equal(f.view().direct.name,'Tester');assert.equal(f.view().busy,false);assert.equal((await f.store.load()).history.length,0);assert.equal(values.password,'');assert.equal(JSON.stringify(f.sent).includes('SECRET'),false);});
test('no saved key leaves the browser open and never starts a connection',async t=>{const f=await fixture(t,{settings:async()=>({hasSavedCdKey:false})});await f.command('join',{direct:true,values:{...local,name:'Tester',password:'',cdKey:''}});assert.equal(f.calls.length,0);assert.match(f.view().status,/CD key/);assert.equal(f.view().busy,false);});
test('invalid or disallowed login clears submitted secrets without calling settings or login',async t=>{let reads=0;const f=await fixture(t,{settings:async()=>{reads++;return{hasSavedCdKey:true};}});const values={...other,name:'Tester',password:'SECRET',cdKey:'SECRET'};await assert.rejects(f.command('join',{direct:true,values}),/No connection was sent/);assert.equal(reads,1);assert.equal(f.calls.length,0);assert.equal(values.password,'');assert.equal(values.cdKey,'');});
test('Back cancels blocked preparation immediately and reopens with fresh ownership', {timeout:1000},async t=>{
 const gate=deferred(),f=await fixture(t,{connect:()=>gate.promise});const work=f.command('join',{direct:true,values:{...local,name:'Tester',password:'',cdKey:''}});while(!f.calls.length)await new Promise(r=>setImmediate(r));const old=f.lobby.connection;const cancel=f.command('close');await Promise.resolve();assert.ok(f.lobby.connection>old);assert.equal(f.lobby.snapshot().canJoin,false);await assert.rejects(f.lobby.join({connection:f.lobby.connection}),/Disconnect/);await cancel;await work;assert.equal(f.lobby.session,null);assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.service.opened,false);await f.command('open');assert.equal(f.view().connection,f.lobby.connection);assert.equal(f.view().canJoin,true);gate.resolve();await new Promise(r=>setImmediate(r));assert.equal(f.lobby.session,null);assert.equal((await f.store.load()).history.length,0);
});
test('protocol accepts connection-only browser controls and rejects malformed fields before area dispatch',()=>{
 const owner={connection:0},base={kind:'browser-input',connection:0,viewId:1};for(const operation of ['open','close','refresh'])assert.doesNotThrow(()=>protocol.validateCommand({...base,operation},owner));
 const join={...base,operation:'join',direct:true,values:{...local,name:'Tester',password:'',cdKey:''}};assert.doesNotThrow(()=>protocol.validateCommand(join,owner));for(const patch of [{connection:1},{viewId:-1},{direct:'yes'},{values:{...join.values,serverPublicKey:'injected'}},{values:{...join.values,password:'x'.repeat(256)}}])assert.throws(()=>protocol.validateCommand({...join,...patch},owner));
});
test('direct favorites use only the normalized endpoint and persist without contacting a server',async t=>{let queries=0;const f=await fixture(t,{query:async()=>{queries++;return{};}});await f.command('favorite',{direct:true,values:{host:'LOCALHOST',port:5121,password:'discard'}});assert.equal(queries,0);assert.equal((await f.store.load()).favorites.length,1);await f.command('tab',{tab:'Favorites'});assert.equal(f.view().rows[0].host,'127.0.0.1');await f.command('favorite',{entryId:0});assert.equal(f.view().rows.length,0);});
test('full bounded catalog descriptions cannot overflow the native transport; selected details remain complete',async t=>{const data=Array.from({length:128},(_,i)=>({...local,port:5121+i,description:'x'.repeat(8192),serverName:'s'.repeat(256),moduleName:'m'.repeat(256)}));const f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),discover:async()=>data});await f.command('tab',{tab:'Internet'});assert.equal(f.view().rows.length,128);assert.ok(Buffer.byteLength(JSON.stringify(f.view()))<protocol.MAX_FRAME);assert.ok(f.view().rows.every(r=>!Object.hasOwn(r,'description')));await f.command('select',{entryId:0});assert.equal(f.view().details.description.length,8192);});
test('retiring a service cancels and drains login preparation instead of leaving an unowned session',async t=>{const gate=deferred(),f=await fixture(t,{connect:()=>gate.promise});const work=f.command('join',{direct:true,values:{...local,name:'Tester',password:'',cdKey:''}});while(!f.calls.length)await new Promise(r=>setImmediate(r));const retiring=f.service.retire();await Promise.resolve();gate.resolve();await work;assert.deepEqual(await retiring,{closed:true,pending:0});assert.equal(f.lobby.session,null);assert.equal(f.lobby.snapshot().canJoin,true);});
test('stale connection and closed-service requests still erase their transient credentials',async t=>{const f=await fixture(t),values={...local,name:'Tester',password:'SECRET',cdKey:'SECRET'};await assert.rejects(f.service.command({connection:999,operation:'join',values}),/old connection/);assert.equal(values.password,'');assert.equal(values.cdKey,'');await f.service.retire();values.password='SECRET';await assert.rejects(f.service.command({connection:0,operation:'join',values}),/old connection/);assert.equal(values.password,'');});

test('explicit launcher account overrides persisted name without changing the endpoint',async t=>{
 const f=await fixture(t);await f.store.remember(local,'Old account');f.service.playerName='Scary Bill';await f.command('open');assert.equal(f.view().direct.name,'Scary Bill');assert.equal(f.view().direct.host,local.host);
 f.service.lastAttempt={...local,name:'Manual account'};await f.command('open');assert.equal(f.view().direct.name,'Manual account');
});

test('invalid current direct address restores a fresh enabled retry view without login or credentials',async t=>{
 const f=await fixture(t),old=f.view().viewId,values={host:'bad/url',port:5121,name:'Tester',password:'discard-password',cdKey:'discard-key'};
 await assert.rejects(f.command('join',{direct:true,values}),/IPv4/);
 assert.ok(f.view().viewId>old);assert.equal(f.view().busy,false);assert.equal(f.view().canJoin,true);assert.match(f.view().status,/IPv4/);assert.equal(f.calls.length,0);
 assert.equal(values.password,'');assert.equal(values.cdKey,'');assert.ok(!JSON.stringify(f.sent).includes('discard-'));
 await f.command('join',{direct:true,values:{...local,name:'Tester',password:'',cdKey:''}});assert.equal(f.calls.length,1);
});

test('stale or conflicting browser input cannot unlock an in-flight query',async t=>{
 const gate=deferred(),f=await fixture(t,{query:()=>gate.promise}),old=f.view().viewId;
 const query=f.command('inspect',{direct:true,values:local});await new Promise(r=>setImmediate(r));const pending=f.view();assert.equal(pending.busy,true);
 await assert.rejects(f.command('join',{direct:true,viewId:pending.viewId,values:{...local,name:'Tester',password:'',cdKey:''}}),/stale/);
 assert.equal(f.view(),pending);await assert.rejects(f.command('select',{viewId:old,entryId:0}),/stale/);assert.equal(f.view(),pending);
 gate.resolve({serverName:'Owned'});await query;assert.equal(f.view().busy,false);assert.equal(f.calls.length,0);
});

test('native profile accepts session identity without saving a new default or contacting a server',async t=>{
 const f=await fixture(t),before=await f.store.load(),view=f.view().viewId;
 await f.command('profile',{values:{name:'Session Name',saveDefault:false}});
 const result=f.sent.findLast(m=>m.kind==='browser-profile-result');assert.equal(result.accepted,true);assert.equal(result.requestViewId,view);assert.equal(result.savedDefault,false);
 assert.equal(f.view().direct.name,'Session Name');assert.equal(f.calls.length,0);assert.equal((await f.store.load()).profileDefault,before.profileDefault);
 await f.command('close');await f.command('open');assert.equal(f.view().direct.name,'Session Name');
 await f.command('join',{direct:true,values:{...local,name:'Session Name',password:'',cdKey:''}});
 assert.equal(f.calls[0].details.name,'Session Name');assert.equal((await f.store.load()).profileDefault,before.profileDefault);
});

test('Save As Default persists only the accepted name and native trailing spaces survive admission',async t=>{
 const f=await fixture(t);await f.command('profile',{values:{name:'Native Name ',saveDefault:true}});
 assert.equal((await new ServerBrowserStore(f.file).load()).profileDefault,'Native Name ');
 assert.equal(f.sent.findLast(m=>m.kind==='browser-profile-result').savedDefault,true);assert.equal(f.calls.length,0);
 await f.command('join',{direct:true,values:{...local,name:'Native Name ',password:'',cdKey:''}});assert.equal(f.calls[0].details.name,'Native Name ');
 const saved=JSON.parse(await fs.readFile(f.file,'utf8'));assert.equal(saved.profileDefault,'Native Name ');assert.equal(saved.cdKey,undefined);assert.equal(saved.password,undefined);
});

test('profile storage refusal keeps the old accepted identity and returns a retryable failure',async t=>{
 const f=await fixture(t),name=f.view().direct.name;f.store.profile=async()=>{throw Error('Storage refusal');};
 await f.command('profile',{values:{name:'Not Saved',saveDefault:true}});
 const result=f.sent.findLast(m=>m.kind==='browser-profile-result');assert.equal(result.accepted,false);assert.equal(result.text,'Storage refusal');
 assert.equal(f.view().direct.name,name);assert.equal(f.view().busy,false);assert.equal(f.calls.length,0);
});

test('retired pending profile storage cannot reopen a closed browser or accept a stale identity',async t=>{
 const gate=deferred(),f=await fixture(t),before=f.view().direct.name;f.store.profile=()=>gate.promise;
 const work=f.command('profile',{values:{name:'Retired Name',saveDefault:true}});await new Promise(r=>setImmediate(r));await f.command('close');gate.resolve(await f.store.load());await work;
 assert.equal(f.service.opened,false);assert.equal(f.sent.filter(m=>m.kind==='browser-profile-result').length,0);assert.equal(f.service.profileName,undefined);
 await f.command('open');assert.equal(f.view().direct.name,before);
});

test('native profile protocol requires current ownership, bounded identity and a real save-default boolean',()=>{
 const owner={connection:0},profile={kind:'browser-input',connection:0,viewId:1,operation:'profile',values:{name:'Scary Bill',saveDefault:true}};
 assert.doesNotThrow(()=>protocol.validateCommand(profile,owner));
 for(const patch of [{connection:1},{viewId:-1},{values:{name:'',saveDefault:true}},{values:{name:'A'.repeat(33),saveDefault:true}},{values:{name:'A',saveDefault:'yes'}},{values:{name:'A',saveDefault:true,cdKey:'injected'}}])assert.throws(()=>protocol.validateCommand({...profile,...patch},owner));
});

test('fresh profiles have no invented default and expose accepted session identity independently',async t=>{
 const f=await fixture(t);assert.equal(f.view().direct.name,'');assert.equal(f.view().hasSessionProfile,false);
 await f.command('profile',{values:{name:'Session Only',saveDefault:false}});assert.equal(f.view().hasSessionProfile,true);assert.equal((await f.store.load()).profileDefault,'');
 await f.command('close',{leaveMultiplayer:true});await f.command('open');assert.equal(f.view().hasSessionProfile,false);assert.equal(f.view().direct.name,'');assert.equal(f.calls.length,0);
});

test('multiplayer Cancel preserves a session name when a configured default exists',async t=>{
 const f=await fixture(t);await f.command('profile',{values:{name:'Default Name',saveDefault:true}});await f.command('profile',{values:{name:'Current Name',saveDefault:false}});
 await f.command('close',{leaveMultiplayer:true});await f.command('open');assert.equal(f.view().direct.name,'Current Name');assert.equal(f.view().hasSessionProfile,true);assert.equal((await new ServerBrowserStore(f.file).load()).profileDefault,'Default Name');
});

test('legacy name defaults migrate while an explicitly empty newer default stays empty',async t=>{
 const file=await temporary(t);await fs.writeFile(file,JSON.stringify({version:1,history:[],favorites:[],last:{...local,name:'Legacy Name'}}));assert.equal((await new ServerBrowserStore(file).load()).profileDefault,'Legacy Name');
 await fs.writeFile(file,JSON.stringify({version:1,history:[],favorites:[],profileDefault:'',last:{...local,name:'History Name'}}));assert.equal((await new ServerBrowserStore(file).load()).profileDefault,'');
});

test('multiplayer dismissal flag cannot be injected into another operation or coerced',()=>{
 const owner={connection:0},message={kind:'browser-input',connection:0,viewId:1,operation:'close',leaveMultiplayer:true};assert.doesNotThrow(()=>protocol.validateCommand(message,owner));
 assert.throws(()=>protocol.validateCommand({...message,leaveMultiplayer:'yes'},owner));assert.throws(()=>protocol.validateCommand({...message,operation:'refresh'},owner));
});

test('returning from a character connection publishes the requested native list in its first view',async t=>{
 let discovered=0,queried=0;const f=await fixture(t,{discover:async()=>{discovered++;return[];},query:async()=>{queried++;return{};}});
 await f.store.remember({...local,serverName:'Previous local server'},'Tester');
 const old=f.view().viewId;
 // The lobby has retired the old character connection before requesting a list.
 f.lobby.connection++;const at=f.sent.length;
 await f.command('open',{listTab:'History'});
 const views=f.sent.slice(at).filter(row=>row.kind==='browser-view');
 assert.equal(views.length,1);assert.equal(views[0].tab,'History');assert.equal(views[0].sourcePage,true);assert.equal(views[0].connection,f.lobby.connection);assert.equal(views[0].rows[0].serverName,'Previous local server');assert.equal(views[0].canJoin,true);
 await assert.rejects(f.command('select',{viewId:old,entryId:0}),/stale/);
 assert.equal(f.calls.length,0);assert.equal(discovered,0);assert.equal(queried,0);
 await f.command('open',{listTab:'Internet'});assert.equal(f.view().tab,'Internet');assert.equal(f.view().sourcePage,true);assert.equal(discovered,0);
 await f.command('return-menu');assert.equal(f.view().tab,'Direct');assert.equal(f.view().sourcePage,false);
});

test('native browser return-page fields are bounded and confined to opening a presentation',async t=>{
 const owner={connection:0},message={kind:'browser-input',connection:0,operation:'open',listTab:'Favorites'};
 assert.doesNotThrow(()=>protocol.validateCommand(message,owner));
 for(const listTab of ['Direct','Characters','',true,null])assert.throws(()=>protocol.validateCommand({...message,listTab},owner));
 assert.throws(()=>protocol.validateCommand({...message,operation:'close'},owner));
 const f=await fixture(t);
 await assert.rejects(f.command('open',{listTab:'Characters'}),/return page/);
 await assert.rejects(f.command('close',{listTab:'Internet'}),/return page/);
 assert.equal(f.calls.length,0);
});

test('automatic first discovery and manual refresh share a persistent two-second deadline',async t=>{
 let clock=10000,fetches=0;const gate=deferred(),f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),now:()=>clock,discover:async()=>{fetches++;return fetches===1?gate.promise:[{...local,serverName:'Updated'}];}});
 assert.equal(fetches,0);const entering=f.command('tab',{tab:'Internet',sourcePage:true});await new Promise(r=>setImmediate(r));
 assert.equal(fetches,1);assert.equal(f.view().busy,true);assert.equal(f.view().refreshCooldownMs,2000);
 gate.resolve([{...local,serverName:'First'}]);await entering;
 assert.equal(f.view().rows[0].serverName,'First');assert.equal(f.view().busy,false);
 await assert.rejects(f.command('refresh'),/two seconds/);clock+=1999;await assert.rejects(f.command('refresh'),/two seconds/);assert.equal(fetches,1);
 clock++;await f.command('refresh');assert.equal(fetches,2);assert.equal(f.view().rows[0].serverName,'Updated');
 await f.command('tab',{tab:'History'});await f.command('tab',{tab:'Internet'});assert.equal(fetches,2);await assert.rejects(f.command('refresh'),/two seconds/);
 await f.command('close');f.lobby.connection++;await f.command('open',{listTab:'Internet'});assert.equal(f.view().rows[0].serverName,'Updated');assert.equal(fetches,2);await assert.rejects(f.command('refresh'),/two seconds/);
 clock+=2000;await f.command('refresh');assert.equal(fetches,3);assert.equal(f.calls.length,0);
});

test('opening directly into an uncached Internet list also discovers automatically',async t=>{
 let fetches=0;const f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),discover:async()=>{fetches++;return[{...local,serverName:'Discovered'}];}});
 await f.command('open',{listTab:'History'});assert.equal(fetches,0);
 await f.command('open',{listTab:'Internet'});assert.equal(fetches,1);assert.equal(f.view().tab,'Internet');assert.equal(f.view().sourcePage,true);assert.equal(f.view().rows[0].serverName,'Discovered');
 await f.command('open',{listTab:'Internet'});assert.equal(fetches,1);assert.equal(f.view().rows[0].serverName,'Discovered');assert.equal(f.calls.length,0);
});

test('a failed refresh releases busy state, preserves cached rows and retains the cooldown',async t=>{
 let clock=10000,fetches=0;const f=await fixture(t,{policy:new ServerEndpointPolicy({internet:true}),now:()=>clock,discover:async()=>{fetches++;if(fetches>1)throw Error('Discovery unavailable');return[{...local,serverName:'Cached'}];}});
 await f.command('tab',{tab:'Internet'});clock+=2000;await assert.rejects(f.command('refresh'),/Discovery unavailable/);
 assert.equal(f.view().busy,false);assert.equal(f.view().status,'Discovery unavailable');assert.equal(f.view().rows[0].serverName,'Cached');assert.equal(f.view().refreshCooldownMs,2000);
 await assert.rejects(f.command('refresh'),/two seconds/);assert.equal(fetches,2);assert.equal(f.calls.length,0);
});
