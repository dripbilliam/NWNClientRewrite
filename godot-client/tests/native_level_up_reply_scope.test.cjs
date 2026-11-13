const test=require('node:test'),assert=require('node:assert/strict');
const {captureLevelUpReplyScope}=require('../tools/native-level-up-reply-scope.cjs');
function command(operation='submit',token=8){return {kind:'native-level-up',operation,generation:7,areaId:0x80000001,actorId:0xffffffff,token,proposal:{privateValue:'NOT_COPIED'},levelRequest:{version:1,owner:'opaque view owner: 1',entry:0,request:1,generation:7,areaId:0x80000001,actorId:0xffffffff,nativeLifetime:32,knownLifetime:33,operation,token}};}
function rejected(value){assert.throws(()=>captureLevelUpReplyScope(value),error=>error instanceof TypeError&&error.message==='Invalid local level-up reply scope'&&!error.message.includes('PRIVATE_SENTINEL'));}
test('metadata capture is exact/detached and the same local echo serves success/failure',()=>{
 const input=command(),expected=structuredClone(input.levelRequest),echo=captureLevelUpReplyScope(input);assert.deepEqual(echo,{levelRequest:expected});assert.equal(Object.keys(echo.levelRequest).length,11);assert.equal(Object.isFrozen(echo),true);assert.equal(Object.isFrozen(echo.levelRequest),true);assert.equal(echo.proposal,undefined);
 input.levelRequest.owner='different';input.levelRequest.request=99;input.generation=10;assert.deepEqual(echo.levelRequest,expected);
 const success={accepted:true,result:{accepted:true},...echo},failure={accepted:false,text:'Authored refusal',...echo};assert.deepEqual(success.levelRequest,failure.levelRequest);assert.equal(success.result.accepted,true);assert.equal(failure.accepted,false);assert.deepEqual(JSON.parse(JSON.stringify(echo)),{levelRequest:expected});
});
test('actual JSON numbers and complete permitted operation/token domains round-trip',()=>{
 for(const[operation,token]of [['begin',-1],['submit',0],['submit',Number.MAX_SAFE_INTEGER],['cancel',-1],['cancel',0],['cancel',Number.MAX_SAFE_INTEGER]]){
  const input=command(operation,token);input.levelRequest.entry=Number.MAX_SAFE_INTEGER;input.levelRequest.request=Number.MAX_SAFE_INTEGER;input.levelRequest.nativeLifetime=Number.MAX_SAFE_INTEGER;input.levelRequest.knownLifetime=Number.MAX_SAFE_INTEGER;input.levelRequest.owner='~'.repeat(128);const decoded=JSON.parse(JSON.stringify(input));assert.deepEqual(captureLevelUpReplyScope(decoded).levelRequest,decoded.levelRequest);
 }
 const input=command();input.areaId=0;input.actorId=0;input.levelRequest.areaId=0;input.levelRequest.actorId=0;assert.equal(captureLevelUpReplyScope(input).levelRequest.actorId,0);
});
test('missing metadata yields no echo while present undefined/null/arrays refuse',()=>{
 const direct={operation:'begin'};assert.equal(captureLevelUpReplyScope(direct),null);Object.setPrototypeOf(direct,{levelRequest:{not:'received'}});rejected(direct);
 for(const value of [undefined,null,[],false,'metadata',new Date()]){const input=command();input.levelRequest=value;rejected(input);}
 for(const value of [null,[],false,undefined])rejected(value);
});
test('getters, unexpected keys and symbols reject without inspecting or exposing their values',()=>{
 let calls=0;for(const edit of [
  input=>Object.defineProperty(input,'levelRequest',{get(){calls++;throw Error('PRIVATE_SENTINEL');}}),
  input=>Object.defineProperty(input.levelRequest,'owner',{get(){calls++;throw Error('PRIVATE_SENTINEL');}}),
  input=>Object.defineProperty(input,'operation',{get(){calls++;throw Error('PRIVATE_SENTINEL');}}),
  input=>{input.levelRequest.password='PRIVATE_SENTINEL';},
  input=>{input.levelRequest[Symbol('PRIVATE_SENTINEL')]=1;},
  input=>{delete input.levelRequest.version;Object.setPrototypeOf(input.levelRequest,{version:1});}
 ]){const input=command();edit(input);rejected(input);}assert.equal(calls,0);
});
test('invalid scalar, opaque owner, operation and token shapes never become an echo',()=>{
 const edits=[
  m=>m.version=2,m=>m.version=true,m=>m.owner='',m=>m.owner='a'.repeat(129),m=>m.owner='\nPRIVATE_SENTINEL',m=>m.owner='\x7f',m=>m.owner='é',
  ...['entry','request','generation','nativeLifetime','knownLifetime'].flatMap(key=>[m=>m[key]=NaN,m=>m[key]=Infinity,m=>m[key]=1.5,m=>m[key]=Number.MAX_SAFE_INTEGER+1,m=>m[key]='1']),
  m=>m.entry=-1,m=>m.request=0,m=>m.generation=-1,m=>m.nativeLifetime=0,m=>m.knownLifetime=0,
  m=>m.areaId=-1,m=>m.areaId=0x100000000,m=>m.actorId=-1,m=>m.actorId=0x100000000,m=>m.operation='finish',m=>m.token=-1,m=>m.token=1.5,m=>m.token=NaN,m=>m.token=Number.MAX_SAFE_INTEGER+1
 ];for(const edit of edits){const input=command();edit(input.levelRequest);rejected(input);}
 rejected(command('begin',0));rejected(command('begin',-2));rejected(command('cancel',-2));
});
test('correlation scope is matched to the original command rather than rewritten Session scope',()=>{
 for(const key of ['operation','generation','areaId','actorId']){const input=command();input[key]=key==='operation'?'cancel':input[key]+1;rejected(input);}
 const input=command();input.areaGeneration=input.generation+1;input.sessionActorId=1;assert.equal(captureLevelUpReplyScope(input).levelRequest.generation,7);assert.equal(captureLevelUpReplyScope(input).levelRequest.actorId,0xffffffff);
});
