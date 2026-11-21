const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');

// Read source, never require the broker or private-login/Electron modules.
const sourcePath=path.join(__dirname,'native-session-bootstrap.cjs');
const sourceBytes=fs.readFileSync(sourcePath);
const source=sourceBytes.toString('utf8');
const begin=source.indexOf(' if(loginPipe){');
const end=source.indexOf('\n const partnerPipe=',begin);
assert.ok(begin>=0&&end>begin,'Actual private-login branch boundaries are present');
const branch=source.slice(begin,end);
assert.ok(Buffer.byteLength(branch)<2048,'Only the bounded actual loginPipe branch is evaluated');
const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
const evaluate=new AsyncFunction('loginPipe','process','require','settings','privateTestKey',branch+'\nreturn privateTestKey;');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

async function exercise(flags,options={}){
 const loginPipe=Object.hasOwn(options,'loginPipe')?options.loginPipe:'synthetic-private-pipe';
 const readFails=options.readFails??false;
 const credentials=Object.freeze({cdKey:'synthetic-unit-credential-not-a-valid-key'});
 const input=Object.freeze({credentials});
 const settings=Object.freeze({syntheticSettingsOwner:true});
 const calls=[];
 const privateLogin=Object.freeze({
  connectPrivatePipe(name){assert.equal(name,loginPipe);calls.push('connect');return input;},
  async readPrivateKey(value){assert.strictEqual(value,input);calls.push('read');if(readFails)throw Error('Synthetic read failure');return value.credentials.cdKey;},
  async savePrivateLogin(value,owner){assert.strictEqual(value,input);assert.strictEqual(owner,settings);calls.push('save');return true;},
 });
 let required=0;
 const fakeRequire=name=>{assert.equal(name,'./private-login.cjs');required++;return privateLogin;};
 const key=await evaluate(loginPipe,{argv:['node','synthetic-bootstrap.cjs',...flags]},fakeRequire,settings,'');
 return {key,calls,required,expected:credentials.cdKey};
}

test('actual direct-handoff private-login branch reads ephemerally and never saves',async()=>{
 const result=await exercise(['--direct-handoff-check']);
 assert.equal(result.key,result.expected);
 assert.deepEqual(result.calls,['connect','read']);assert.equal(result.required,1);
});

test('normal interactive private-login branch retains its existing save behavior',async()=>{
 const result=await exercise([]);
 assert.equal(result.key,'');assert.deepEqual(result.calls,['connect','save']);assert.equal(result.required,1);
});

for(const flag of ['--action-check','--local-check','--creation-check','--script-floating-check','--script-floating-visual']){
 test(`existing owned ${flag} branch remains ephemeral`,async()=>{
  const result=await exercise([flag]);
  assert.equal(result.key,result.expected);assert.deepEqual(result.calls,['connect','read']);assert.equal(result.required,1);
 });
}

for(const flag of ['--direct-handoff-check=true','--direct-handoff-checker','--unrelated-check','--native-headless']){
 test(`unrelated/nonexact ${flag} cannot activate private-key reading`,async()=>{
  const result=await exercise([flag]);
  assert.equal(result.key,'');assert.deepEqual(result.calls,['connect','save']);assert.equal(result.required,1);
 });
}

test('without a private pipe even direct-handoff performs no read/save or module load',async()=>{
 const result=await exercise(['--direct-handoff-check'],{loginPipe:undefined});
 assert.equal(result.key,'');assert.deepEqual(result.calls,[]);assert.equal(result.required,0);
});

test('failed ephemeral read cannot fall through to persistent private-login save',async()=>{
 let saved=0;
 const input={},settings={};
 const privateLogin={connectPrivatePipe:()=>input,readPrivateKey:async()=>{throw Error('Synthetic read failure');},savePrivateLogin:async()=>saved++};
 await assert.rejects(evaluate('synthetic-private-pipe',{argv:['node','test','--direct-handoff-check']},()=>privateLogin,settings,''),/Synthetic read failure/);
 assert.equal(saved,0);
});

test('evaluating the isolated branch leaves the actual source bytes unchanged',()=>{
 assert.equal(digest(fs.readFileSync(sourcePath)),digest(sourceBytes));
});
