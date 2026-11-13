const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{createRequire}=require('node:module');
const hostPath=path.resolve(__dirname,'../tools/native-session-host.cjs'),source=fs.readFileSync(hostPath,'utf8');
const start=source.indexOf("const scope={areaId:message.areaId,areaGeneration:message.generation};"),end=source.indexOf("  else if(message.kind==='walk')",start);
if(start<0||end<start||source.indexOf("const scope={areaId:message.areaId,areaGeneration:message.generation};",start+1)>=0)throw Error('Exact bounded Host dispatcher anchors changed');
const fragment=source.slice(start,end),hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
const dispatch=new AsyncFunction('message','session','send','require','lobby','levelSourceCheck','levelSourceHarness','report',"const actionQuickbarCheck=false,actionSpecialAttackCheck=false,actionFeatCheck=false,actionCheck=false,actionRadialCheck=false;\n"+fragment);
function command(operation='submit',token=8){return {kind:'native-level-up',operation,generation:7,areaId:0x80000001,actorId:0xffffffff,token,proposal:{},levelRequest:{version:1,owner:'authored-host-dispatch',entry:2,request:3,generation:7,areaId:0x80000001,actorId:0xffffffff,nativeLifetime:32,knownLifetime:33,operation,token}};}
function harness(run,observe=false){
 const calls=[],sent=[],observations=[];const session={phase:'playing',world:{localObjectId:0xffffffff},async levelUp(input){calls.push(structuredClone(input));return run(input);}};
 const observer={request(_session,_connection,input){const value={request:structuredClone(input.levelRequest)};observations.push(value);return value;},result(handle,_session,_connection,result,echo){handle.result=result;handle.echo=structuredClone(echo);},refused(handle,error,echo){handle.error=error.message;handle.echo=structuredClone(echo);}};
 return {calls,sent,observations,run:input=>dispatch(input,session,value=>sent.push(structuredClone(value)),createRequire(hostPath),{connection:1},observe,observer,{})};
}
test('exact bounded production Host branch echoes one captured metadata object on success and refusal',async t=>{
 for(const fail of [false,true]){const input=command(),expected=structuredClone(input.levelRequest),h=harness(()=>{if(fail)throw Error('Authored Session refusal');return {accepted:true};},true);await h.run(input);assert.equal(h.calls.length,1);assert.equal(h.sent.length,1);assert.deepEqual(h.sent[0].message.levelRequest,expected);assert.deepEqual(h.observations[0].echo,{levelRequest:expected});assert.deepEqual(h.observations[0].request,expected);assert.equal(h.sent[0].message.accepted,!fail);assert.equal(h.sent[0].message.kind,'native-action-result');assert.equal(h.sent[0].message.action,'native-level-up');}
 t.diagnostic(JSON.stringify({hostSha256:hash(source),fragmentSha256:hash(fragment),firstLine:source.slice(0,start).split('\n').length,lastLine:source.slice(0,end).split('\n').length,scope:'Exact bounded native Host dispatcher code with controlled Session method; no Host startup/socket, native UI, original server or gameplay authority.'}));
});
test('Host capture precedes await and never substitutes the original request token from its result',async()=>{
 let release;const answer=new Promise(resolve=>release=resolve),input=command('begin',-1),expected=structuredClone(input.levelRequest),h=harness(()=>answer,true),pending=h.run(input);assert.equal(h.calls.length,1);input.levelRequest.owner='changed';input.levelRequest.request=500;release({token:55});await pending;assert.deepEqual(h.sent[0].message.levelRequest,expected);assert.equal(h.sent[0].message.levelRequest.token,-1);assert.equal(h.sent[0].message.result.token,55);assert.deepEqual(h.observations[0].echo,{levelRequest:expected});
});
test('present malformed metadata refuses before Session and sends no invalid echo or private values',async()=>{
 let getters=0;for(const edit of [input=>input.levelRequest.generation++,input=>input.levelRequest.operation='cancel',input=>input.levelRequest.token=-2,input=>input.levelRequest.password='PRIVATE_SENTINEL',input=>Object.defineProperty(input.levelRequest,'owner',{get(){getters++;throw Error('PRIVATE_SENTINEL');}})]){const input=command(),h=harness(()=>({accepted:true}));edit(input);await h.run(input);assert.equal(h.calls.length,0);assert.equal(h.sent.length,1);assert.equal(h.sent[0].message.accepted,false);assert.equal(h.sent[0].message.levelRequest,undefined);assert.equal(h.sent[0].message.text,'Invalid local level-up reply scope');assert.equal(JSON.stringify(h.sent).includes('PRIVATE_SENTINEL'),false);}assert.equal(getters,0);
});
test('missing legacy metadata adds no echo; existing metadata is checked against original rather than Session-rewritten scope',async()=>{
 const old=command();delete old.levelRequest;const direct=harness(()=>({accepted:true}));await direct.run(old);assert.equal(direct.calls.length,1);assert.equal(direct.sent[0].message.levelRequest,undefined);
 const input=command();input.actorId=41;input.levelRequest.actorId=41;const h=harness(()=>({accepted:true}));await h.run(input);assert.equal(h.calls[0].actorId,0xffffffff);assert.equal(h.sent[0].message.levelRequest.actorId,41);
});
