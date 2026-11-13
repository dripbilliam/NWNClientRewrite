const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),{pathToFileURL}=require('node:url');
const {NativeDirectHandoffHostCheck}=require('./native-direct-handoff-host-check.cjs');
const {evaluate,canonicalChainAccepted}=require('./native-direct-handoff-capture.cjs');
const root=path.resolve(__dirname,'../..');
let imports;
async function source(){
 if(!imports)imports=(async()=>{
  const [proof,gff,writer]=await Promise.all(['godot-client/tools/native-handoff-character-proof.mjs','src/gff.js','src/gff_writer.js'].map(file=>import(pathToFileURL(path.join(root,file)))));
  const bytes=await fs.readFile(path.resolve(root,'../FullDecomp/NwnRootInstall/data/lcv/wizard.bic'));
  return{...proof,...gff,...writer,bytes,variant(edit){const record=writer.typedGff(gff.parseGff(bytes,'BIC ').root);edit(record);return writer.writeGff('BIC ',record);}};
 })();return imports;
}
async function driverState({scenario='roundtrip',configured=true,chain,pair,digest}={}){
 const api=await source(),fixture={descriptorSha256:'d'.repeat(64),servers:[{label:'A',module:'NativeHandA1',port:5129,sha256:'a'.repeat(64)},{label:'B',module:'NativeHandB1',port:5130,sha256:'b'.repeat(64)}]},state={session:null,lobby:{connection:1,session:null}};
 const driver=new NativeDirectHandoffHostCheck({fixture,scenario,send:()=>{},finish:()=>{},getScope:()=>state,rawCombat:{},characterDigest:digest??api.readHandoffCharacter,compareCharacterChain:chain===undefined?api.compareHandoffCharacterChain:chain,compareRetryCharacter:pair===undefined?api.compareHandoffCharacters:pair,canonicalCharacterContinuity:configured});
 const makeSession=()=>({closed:false,phase:'new',resourceResult:{ready:true},resolver:{},characterUploaded:false,async uploadCharacter(){this.character.fill(0);this.character=null;this.characterUploaded=true;},async connect(){},async disconnect(){this.closed=true;this.character?.fill(0);this.character=null;}});
 const first=makeSession();state.session=state.lobby.session=first;
 const read=(bytes,connection=state.lobby.connection)=>driver.readCharacter(state.session,connection,'installed:wizard.bic',bytes);
 const transfer=async(bytes,port)=>{
  const previous=state.session,from=state.lobby.connection,destination=makeSession(),next={session:destination};
  driver.preparing({current:previous,connection:from,next,endpoint:{host:'127.0.0.1',port}});driver.transferevent({stage:'prepared',from,to:from+1});previous.closed=true;previous.portalHandoffReady=true;destination.character=Uint8Array.from(bytes);driver.ready({previous,next});driver.transferevent({stage:'adopting',from,to:from+1});driver.transferevent({stage:'installed',from,to:from+1});state.session=state.lobby.session=destination;state.lobby.connection=from+1;await destination.uploadCharacter();
 };
 const final=bytes=>{driver.exportOwner={ref:new WeakRef(state.session),connection:state.lobby.connection};driver.exported(state.session,state.lobby.connection,bytes);};
 return{api,driver,state,first,read,transfer,final};
}
async function roundtrip({initial,downloadA,downloadB,finalExport,...options}={}){
 const t=await driverState(options),base=t.api.bytes;t.read(initial??base);await t.transfer(downloadA??base,5130);await t.transfer(downloadB??base,5129);t.driver.commitTransfers();t.final(finalExport??base);return t;
}
test('actual parsed BIC chain is required only when configured and retains raw-vs-selected evidence',async()=>{
 const api=await source(),rewritten=api.variant(()=>{}),t=await roundtrip({downloadB:rewritten});
 const report=t.driver.snapshot(),result=report.characterContinuity.result;
 assert.equal(report.semantic.configured,true);assert.equal(result.success,true);assert.equal(result.comparisons.length,2);assert.equal(result.comparisons[0].from,'downloadA');assert.equal(result.comparisons[1].to,'finalExport');assert.equal(result.comparisons[0].complete,true);assert.deepEqual(result.comparisons[0].coverage.before.missingCore,[]);assert.equal(result.comparisons[0].differenceCount,0);assert.equal(result.comparisons[0].rawEqual,false);assert.equal(canonicalChainAccepted(report),true);
 assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,true);assert.equal(evaluate(JSON.parse(JSON.stringify(report)),{beforeShutdown:true}).checks.canonicalCharacterContinuity,true);t.driver.close();
});
test('actual server-field difference on downloadB fails the chain without changing raw transfer gates',async()=>{
 const api=await source(),changed=api.variant(r=>r.fields.Gold.value++),t=await roundtrip({downloadB:changed}),report=t.driver.snapshot();
 assert.equal(report.characterContinuity.result.success,false);assert.equal(report.characterContinuity.result.comparisons[0].complete,true);assert.ok(report.characterContinuity.result.comparisons[0].differences.some(d=>d.path.includes('/progression/Gold')));assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.originalCharacterTransfer,true);assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,false);
 report.characterContinuity.result.success=true;assert.equal(canonicalChainAccepted(report),false,'aggregate success cannot conceal explicit differences');t.driver.close();
});
test('actual final-export mutation fails the second edge with exact coverage and differences',async()=>{
 const api=await source(),changed=api.variant(r=>r.fields.Int.value--),t=await roundtrip({finalExport:changed}),result=t.driver.snapshot().characterContinuity.result;
 assert.equal(result.comparisons[0].success,true);assert.equal(result.comparisons[1].success,false);assert.ok(result.comparisons[1].differences.some(d=>d.path.includes('/abilities/Int')));assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,false);t.driver.close();
});
test('matching incomplete actual BIC projections never certify canonical continuity',async()=>{
 const api=await source(),partial=api.variant(r=>{delete r.fields.Race;}),t=await roundtrip({downloadA:partial,downloadB:partial,finalExport:partial}),result=t.driver.snapshot().characterContinuity.result;
 assert.equal(result.comparisons[0].availableEqual,true);assert.equal(result.comparisons[0].complete,false);assert.deepEqual(result.comparisons[0].coverage.before.missingCore,['Race']);assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,false);t.driver.close();
});
test('initial installed-read difference remains diagnostic and is a frozen first read',async()=>{
 const api=await source(),initial=api.variant(r=>r.fields.Gold.value++),t=await roundtrip({initial}),report=t.driver.snapshot();
 assert.equal(report.characterContinuity.result.initialComparison.success,false);assert.equal(report.characterContinuity.result.initialComparison.required,false);assert.equal(report.characterContinuity.result.success,true);assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,true);assert.ok(report.characterContinuity.result.initialComparison.differences.length>0);t.driver.close();
});
test('missing proof, missing provider, malformed result and asynchronous provider do not fabricate success',async()=>{
 const api=await source();
 await assert.rejects(driverState({chain:null}),/callback unavailable/);
 for(const options of [{digest:bytes=>{const {character,...raw}=api.readHandoffCharacter(bytes);return raw;}},{chain:()=>({version:1,source:'native-handoff-character-v1',success:true,comparisons:[]})},{chain:()=>Promise.resolve({success:true})},{chain:()=>{throw Error('authored comparator unavailable');}}]){
  const t=await roundtrip(options),report=t.driver.snapshot();assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,false);assert.equal(t.driver.evaluate({beforeShutdown:true,canonicalCharacterContinuity:false}).checks.canonicalCharacterContinuity,false,'capture constructor configuration cannot be bypassed by later evaluation options');assert.ok(report.characterContinuity.status==='unavailable'||report.characterContinuity.status==='compared');t.driver.close();
 }
 const off=await roundtrip({configured:false,chain:null,pair:null});assert.equal(off.driver.snapshot().characterContinuity.status,'not-configured');assert.equal('canonicalCharacterContinuity'in off.driver.evaluate({beforeShutdown:true}).checks,false);assert.equal(off.driver.evaluate({beforeShutdown:true}).semanticCriteria,'not-configured');off.driver.close();
});
test('comparison callback receives detached digests and cannot mutate retained source-ready proof',async()=>{
 const api=await source();let observed;
 const t=await roundtrip({chain:input=>{const result=api.compareHandoffCharacterChain(input);observed=input;input.downloadA.character.canonical.abilities.Int.value=-1;input.initial.character.canonical.identity.FirstName.value.entries[0].text='mutated callback';return result;}});
 assert.equal(t.driver.rows[0].character.character.canonical.abilities.Int.value,19);assert.equal(t.driver.capture.data.characterReads[0].character.canonical.identity.FirstName.value.entries[0].text,'Spectorial');assert.equal(t.driver.evaluate({beforeShutdown:true}).checks.canonicalCharacterContinuity,true);observed.finalExport.character.coverage.missingCore.push('mutated');assert.deepEqual(t.driver.capture.data.finalCharacter.character.coverage.missingCore,[]);t.driver.close();
});
test('recovery compares only fresh retry read to final A export and labels abandoned source separately',async()=>{
 const api=await source(),abandoned=api.readHandoffCharacter(api.variant(r=>r.fields.Gold.value++)),finalBytes=api.variant(r=>r.fields.Int.value--),calls=[];
 const t=await driverState({scenario:'cancel',pair:(before,after)=>{calls.push([before.sha256,after.sha256]);return api.compareHandoffCharacters(before,after);}});
 t.read(api.bytes);t.driver.rows.push({character:abandoned});const retry={closed:false};t.state.session=t.state.lobby.session=retry;t.state.lobby.connection=4;t.driver.recovery.retryTo=4;t.read(api.bytes);t.final(finalBytes);
 const report=t.driver.snapshot(),diagnostic=report.retryCharacterContinuity;
 assert.equal(report.characterContinuity,null);assert.equal('canonicalCharacterContinuity'in t.driver.evaluate({beforeShutdown:true}).checks,false);assert.equal(diagnostic.required,false);assert.equal(diagnostic.status,'compared');assert.equal(diagnostic.result.success,false);assert.equal(diagnostic.initialToRetry.success,true);assert.equal(diagnostic.abandonedSource.sha256,abandoned.sha256);assert.ok(calls.every(([before,after])=>before!==abandoned.sha256&&after!==abandoned.sha256));assert.equal(diagnostic.result.complete,true);assert.ok(diagnostic.result.differences.some(d=>d.path.includes('/abilities/Int')));t.driver.close();
});
