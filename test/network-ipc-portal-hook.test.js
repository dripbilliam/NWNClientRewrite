import test from 'node:test';import assert from 'node:assert/strict';import {EventEmitter} from 'node:events';import {pathToFileURL,fileURLToPath} from 'node:url';import {registerNetworkIpc} from '../electron/network_ipc.cjs';
const url=pathToFileURL(fileURLToPath(new URL('../dist/index.html',import.meta.url))).href,tick=()=>new Promise(r=>setImmediate(r));
const gate=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};
function session(){const s=new EventEmitter();s.closed=false;s.logins=0;s.disposals=0;s.connect=async()=>{s.logins++;s.emit('state',{phase:'connecting'});};s.state=()=>({phase:'resources'});s.disconnect=async()=>{if(s.closed)return;s.closed=true;s.disposals++;s.emit('state',{phase:'closed',closed:true});s.emit('closed');};return s;}
function setup(options){
 const old=session(),handlers=new Map(),sender=new EventEmitter();sender.id=1;sender.mainFrame={};sender.isDestroyed=()=>false;sender.getURL=()=>url;sender.events=[];sender.send=(_c,e)=>sender.events.push(e);
 const window=new EventEmitter();window.webContents=sender;
 let created=0;const controller=registerNetworkIpc({handle:(k,v)=>handlers.set(k,v)},{defaultInstall:'/install',chooseInstall:async()=>null,createSession:async()=>({session:created++===0?old:session(),metadata:{}}),...options});controller.attach(window);
 return{old,sender,controller,connect:()=>controller.connect(sender,{host:'127.0.0.1',port:5121,name:'Authored',credentials:{}}),release(next){old.closed=true;old.portalHandoffReady=true;old.emit('state',{phase:'closed',closed:true});old.emit('closed');old.emit('portal-ready',{session:next,host:'127.0.0.1',port:5122,metadata:{}});}};
}
test('native hook finishes before destination login, and default frame events rotate to the new owner',async()=>{
 const wait=gate(),calls=[],next=session(),f=setup({onPortalSession:async({previous,next:n})=>{calls.push([previous,n.session]);await wait.promise;}});await f.connect();f.release(next);await tick();assert.equal(next.logins,0);assert.deepEqual(calls,[[f.old,next]]);wait.resolve();await tick();assert.equal(next.logins,1);const id=f.sender.events.at(-1).sessionId;f.old.emit('message',{message:{kind:'old'}});assert.equal(f.sender.events.at(-1).sessionId,id);await f.controller.disconnect(f.sender,{saveCharacter:false});assert.equal(next.closed,true);
});
test('cancellation immediately disposes a prepared destination while its native hook is still waiting',async()=>{
 const wait=gate(),next=session(),f=setup({onPortalSession:()=>wait.promise});await f.connect();f.release(next);await tick();await f.controller.disconnect(f.sender,{saveCharacter:false});assert.equal(next.closed,true);assert.equal(next.disposals,1);assert.equal(next.logins,0);wait.resolve();await tick();assert.equal(next.logins,0);
});
test('a late rejected hook cannot remove a replacement login after cancellation',async()=>{
 const wait=gate(),next=session(),f=setup({onPortalSession:()=>wait.promise});await f.connect();f.release(next);await tick();await f.controller.disconnect(f.sender,{saveCharacter:false});const replacement=await f.connect();wait.reject(Error('late hook'));await tick();assert.equal(f.sender.events.some(e=>e.kind==='diagnostic'&&e.sessionId===replacement.sessionId),false);await assert.rejects(f.connect(),/Disconnect/);await f.controller.disconnect(f.sender,{saveCharacter:false});
});
test('hook failure disposes destination and notifies native failure owner without a login',async()=>{
 const failures=[],next=session(),f=setup({onPortalSession:async()=>{throw Error('native cleanup failed');},onPortalFailure:async v=>failures.push(v)});await f.connect();f.release(next);await tick();assert.equal(next.closed,true);assert.equal(next.logins,0);assert.equal(failures.length,1);assert.equal(failures[0].previous,f.old);assert.match(failures[0].error.message,/cleanup/);assert.ok(f.sender.events.some(e=>e.diagnostic?.code==='network.portal-connect-failed'));await f.connect();await f.controller.disconnect(f.sender,{saveCharacter:false});
});
test('destination connect rejection still notifies failure after its normal close callback',async()=>{
 const failures=[],next=session(),f=setup({onPortalSession:async()=>{},onPortalFailure:async v=>failures.push(v)});next.connect=async()=>{next.logins++;await next.disconnect();throw Error('destination rejected');};await f.connect();f.release(next);await tick();assert.equal(next.closed,true);assert.equal(failures.length,1);assert.equal(failures[0].next.session,next);await f.connect();await f.controller.disconnect(f.sender,{saveCharacter:false});
});
test('destroying the owning frame cancels a pending native hook and cannot restart it later',async()=>{
 const wait=gate(),next=session(),f=setup({onPortalSession:()=>wait.promise});await f.connect();f.release(next);await tick();f.sender.emit('destroyed');await tick();assert.equal(next.closed,true);wait.resolve();await tick();assert.equal(next.logins,0);
});

test('overlapping handoff completion cannot clear another destination connection latch',async()=>{
 const first=gate(),second=gate(),failures=[],b=session(),c=session(),f=setup({onPortalSession:async()=>{},onPortalFailure:async v=>failures.push(v)});
 b.connect=async()=>{b.logins++;await first.promise;};c.connect=async()=>{c.logins++;await second.promise;await c.disconnect();throw Error('second destination rejected');};
 await f.connect();f.release(b);await tick();assert.equal(b.logins,1);
 b.closed=true;b.portalHandoffReady=true;b.emit('state',{phase:'closed',closed:true});b.emit('closed');b.emit('portal-ready',{session:c,host:'127.0.0.1',port:5123,metadata:{}});await tick();assert.equal(c.logins,1);
 first.resolve();await tick();second.resolve();await tick();assert.equal(failures.length,1);assert.equal(failures[0].previous,b);assert.equal(failures[0].next.session,c);await f.connect();await f.controller.disconnect(f.sender,{saveCharacter:false});
});
test('native connect acknowledgement runs after peer completion and is fenced against cancellation',async()=>{
 for(const cancel of [false,true]){const wait=gate(),connected=[],next=session(),f=setup({onPortalSession:async()=>{},onPortalConnected:async v=>connected.push(v)});next.connect=async()=>{next.logins++;await wait.promise;};await f.connect();f.release(next);await tick();assert.equal(connected.length,0);if(cancel)await f.controller.disconnect(f.sender,{saveCharacter:false});wait.resolve();await tick();assert.equal(connected.length,cancel?0:1);if(!cancel){assert.equal(connected[0].previous,f.old);assert.equal(connected[0].next.session,next);await f.controller.disconnect(f.sender,{saveCharacter:false});}}
});
test('a connect that resolves after self-closing is treated as failure and releases its IPC owner',async()=>{
 const connected=[],failed=[],next=session(),f=setup({onPortalSession:async()=>{},onPortalConnected:async v=>connected.push(v),onPortalFailure:async v=>failed.push(v)});next.connect=async()=>next.disconnect();await f.connect();f.release(next);await tick();assert.equal(connected.length,0);assert.equal(failed.length,1);await f.connect();await f.controller.disconnect(f.sender,{saveCharacter:false});
});
