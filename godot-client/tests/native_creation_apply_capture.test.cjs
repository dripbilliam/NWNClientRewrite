const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {validateCreationCapture}=require('../tools/native-creation-apply-capture.cjs');
const digest=value=>crypto.createHash('sha256').update(value).digest('hex');
function fixture(){
 const descriptor={archives:[{path:'owned/Prelude.nwm',priority:23000000}],nwsync:[]};
 const setup=Buffer.from(JSON.stringify({kind:'setup',connection:1,resourceSources:descriptor})+'\n');
 const raw=Buffer.from([{kind:'raw-world-begin',connection:1,generation:1,serial:1,count:1,data:{bridgeMode:'full'}},{kind:'raw-world-chunk',connection:1,generation:1,serial:1,objects:[{id:0xffffffff}]},{kind:'raw-world-end',connection:1,generation:1,serial:1}].map(row=>JSON.stringify(row)+'\n').join(''));
 const ledger={setup:{sha256:digest(setup),bytes:setup.length},snapshot:{sha256:digest(raw),bytes:raw.length,connection:1,generation:1,serial:1,objects:1}};
 const original={endpoint:'127.0.0.1:5129',creationVaultFixture:{kind:'owned-native-first-level-vault',module:'Prelude',public:false,serverVault:true},creationProof:{success:true},creationApplyDiagnostic:structuredClone(ledger),creationResourceSources:descriptor};
 return {setup,raw,ledger,original};
}
test('exact retained owned creation frames validate without synthesizing world data',()=>{
 const f=fixture(),opened=validateCreationCapture(f.ledger,f.setup,f.raw,f.original);
 assert.equal(opened.identity.objects,1);assert.equal(opened.identity.frames[1].objects[0].id,0xffffffff);assert.equal(opened.value.rawFrames.join(''),f.raw.toString());
});
test('changed bytes, scope, resource source or non-owned provenance are rejected',()=>{
 for(const change of [f=>f.raw[10]^=1,f=>f.ledger.snapshot.serial++,f=>f.original.creationResourceSources={archives:[]},f=>f.original.endpoint='public.example:5129',f=>f.original.creationApplyDiagnostic=null,f=>f.original.creationProof.success=false]){const f=fixture();change(f);assert.throws(()=>validateCreationCapture(f.ledger,f.setup,f.raw,f.original));}
});
