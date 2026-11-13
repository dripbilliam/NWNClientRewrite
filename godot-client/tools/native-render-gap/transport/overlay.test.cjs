'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {measuredFrames,HostWindow,readControlBounded}=require('./host-window.cjs'),{transformSources}=require('./prepare-overlay.cjs');
const project=path.resolve(__dirname,'../../..');let checks=0;
const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=a=>{assert(a);checks++;};
function run(wrapped,factory,body){const log=[],iterable=factory(log),error={value:null};try{for(const value of wrapped?measuredFrames(iterable,()=>{log.push('begin');return 1;},()=>log.push('end')):iterable){log.push('body:'+value);if(body)body(value,log);}}catch(e){error.value=e;}return{events:log.filter(s=>s!=='begin'&&s!=='end'),log,error:error.value};}
const failure=new Error('exact framing failure'),socketError=new Error('exact socket failure');
const factories=[
 log=>({*[Symbol.iterator](){try{log.push('encode-a');yield'a';log.push('encode-b');yield'b';}finally{log.push('generator-finally');}}}),
 log=>({*[Symbol.iterator](){try{log.push('encode-a');yield'a';log.push('throw');throw failure;}finally{log.push('generator-finally');}}}),
 log=>({[Symbol.iterator](){return{next(){log.push('next-error');throw failure;},return(){log.push('must-not-close');return{};}};}}),
 log=>({[Symbol.iterator](){return{next(){log.push('result');return{get done(){log.push('done-error');throw failure;}};},return(){log.push('must-not-close');return{};}};}}),
 log=>({[Symbol.iterator](){return{next(){log.push('result');return{done:false,get value(){log.push('value-error');throw failure;}};},return(){log.push('must-not-close');return{};}};}}),
 log=>({[Symbol.iterator](){return{next(){log.push('done');return{done:true,get value(){log.push('must-not-read-done-value');throw failure;}};}};}}),
 log=>({[Symbol.iterator](){let n=0;const i={get next(){log.push('next-get');return()=>{log.push('original-next');Object.defineProperty(i,'next',{value:()=>{throw Error('must-cache-next');},configurable:true});return{done:n++>0,value:'a'};};}};return i;}})
];
for(const f of factories)for(const body of [null,()=>{throw socketError;}]){const a=run(false,f,body),b=run(true,f,body);eq(b.events,a.events);eq(b.error,a.error);eq(b.log.filter(x=>x==='begin').length,b.log.filter(x=>x==='end').length);}
for(const close of [()=>{throw failure;},()=>null]){const f=log=>({[Symbol.iterator](){return{next(){log.push('next');return{done:false,value:'a'};},return(){log.push('return');return close();}};}});const a=run(false,f,()=>{throw socketError;}),b=run(true,f,()=>{throw socketError;});eq(b.events,a.events);eq(b.error,socketError);}
let read=0;const off=new HostWindow({project,enabled:false,readFile:()=>{read++;throw Error('No disabled IO');},send:()=>{throw Error('No disabled send');}});off.observe({});eq(off.abort(),null);eq(read,0);
let closed=0,requests=[];const bounded=readControlBounded('fixture',{openSync:()=>19,readSync:(_fd,b,offset,length)=>{requests.push(length);b.fill(1,offset,offset+length);return length;},closeSync:fd=>{assert.equal(fd,19);closed++;}});eq(bounded.length,16385);eq(requests,[16385]);eq(closed,1);
const readError=new Error('fixture read failed');assert.throws(()=>readControlBounded('fixture',{openSync:()=>19,readSync:()=>{throw readError;},closeSync:()=>closed++}),e=>e===readError);checks++;eq(closed,2);
const scope={connection:1,generation:2,nativePid:456},proof={version:1,command:'begin',connection:1,generation:2,window:'owned-window-a',host:{pid:123,createdFileTimeUtcExact:'134386338118207943',unwanted:'not retained'},native:{pid:456,createdFileTimeUtcExact:'134386338118207957'},unwanted:{row:'must not retain'}};let current=proof,sent=[];
const h=new HostWindow({project,enabled:true,pid:123,readFile:()=>Buffer.from(JSON.stringify(current)),send:m=>sent.push(m)});h.observe({...scope,nativePid:999});eq(sent.length,0);h.observe(scope);eq(sent.length,1);eq(h.active,false);
eq(h.proof.unwanted,undefined);eq(h.proof.host.unwanted,undefined);eq(sent[0].proof.unwanted,undefined);
const opened={kind:'transport-window-opened',connection:1,generation:2,window:proof.window,process_id:456,expected_created_filetime_exact:proof.native.createdFileTimeUtcExact,success:true};h.receive({...opened,process_id:999},scope);eq(h.active,false);h.receive(opened,scope);eq(h.active,true);eq(h.measure(0,1,2,()=>7),7);
current={...proof,command:'end'};h.observe(scope);eq(h.active,false);eq(sent.at(-1).kind,'transport-window-end');
const result={enabled:true,process_id:456,expected_created_filetime_exact:proof.native.createdFileTimeUtcExact,connection:1,generation:2,window:proof.window,dropped:0,unwanted:{row:'must not retain'},phases:['native_commit','native_snapshot','native_protocol_encode'].map(name=>({name,count:1,sum_usec:2,maximum_usec:2,unwanted:{row:1}}))};const completed=h.receive({...opened,kind:'transport-window-closed',result},scope);eq(completed.status,'closed');ok(completed.diagnosticOnly);eq(completed.performanceAccepted,false);eq(completed.native.unwanted,undefined);eq(completed.native.phases[0].unwanted,undefined);
const sources={host:fs.readFileSync(path.join(project,'tools/native-session-host.cjs'),'utf8'),live:fs.readFileSync(path.join(project,'native_live_world.gd'),'utf8'),session:fs.readFileSync(path.join(project,'native_session_world.gd'),'utf8')};const transformed=transformSources(sources);new vm.Script(transformed.host,{filename:'PRIVATE-hooked-native-session-host.cjs'});checks++;
ok(transformed.host.includes('transportHost.active?transportHost.frames(frames,lobby.connection,generation):frames'));ok(transformed.host.includes('else socket.write(frame);'));ok(!transformed.host.includes('[...transportHost.frames'));
const guards='if closing or int(snapshot.get("connection",session_connection))!=session_connection or session_connection==cancelled_connection:return';eq(transformed.session.split(guards).length,sources.session.split(guards).length);ok(transformed.session.indexOf(guards)<transformed.session.indexOf('var token:=transport_probe.begin(0,session_connection,epoch)'));
const originalAck=sources.session.match(/send\(\{"kind":"raw-world-accepted"[^\n]*/g)||[];for(const ack of originalAck)ok(transformed.session.includes(ack));
assert.throws(()=>transformSources({...sources,host:sources.host.replace('const changed=worldDeltas.plan','const edited=worldDeltas.plan')}));checks++;
console.log(JSON.stringify({success:true,checks,generatorAndSocketErrorOrder:true,zeroDisabledControlIO:read===0,hostSyntaxOnly:true,nativeParsed:false,nativeRuntime:false,publicTraffic:0}));
