const {test}=require('node:test');
const assert=require('node:assert/strict');
const {previewProofMatches}=require('./native-character-preview-proof.cjs');
const scope={connection:7,key:'installed:wizard.bic',sha256:'a'.repeat(64)};
const expected={sha256:scope.sha256,abilities:{Str:10},classes:[{id:10,level:1}],skill_count:2,feat_count:3,spell_count:4};
const valid=()=>({...structuredClone(expected),...scope,native_only:true,title_matches:true,record_input:{success:true,...scope,checks:Array.from({length:12},()=>({passed:true}))}});
test('An exact current native BIC/control receipt passes',()=>assert.equal(previewProofMatches(valid(),scope,expected),true));
for(const [name,change] of [
 ['another character',p=>p.key='installed:cleric.bic'],
 ['another connection',p=>p.connection++],
 ['another BIC digest',p=>p.sha256='b'.repeat(64)],
 ['old control character',p=>p.record_input.key='installed:cleric.bic'],
 ['old control connection',p=>p.record_input.connection++],
 ['old control BIC',p=>p.record_input.sha256='b'.repeat(64)],
 ['failed control result',p=>p.record_input.success=false],
 ['missing control check',p=>p.record_input.checks.pop()],
 ['failed control input',p=>p.record_input.checks[3].passed=false],
 ['different received fields',p=>p.abilities.Str=99],
 ['non-native projection',p=>p.native_only=false],
 ['wrong rendered title',p=>p.title_matches=false]
])test('Rejects '+name,()=>{const proof=valid();proof.success=true;change(proof);assert.equal(previewProofMatches(proof,scope,expected),false);});
test('Earlier success never authorizes a newly selected character',()=>{const proof=valid();proof.success=true;assert.equal(previewProofMatches(proof,{...scope,key:'installed:druid.bic'},expected),false);});
test('Earlier success never authorizes a new digest of the same character',()=>{const proof=valid();proof.success=true;assert.equal(previewProofMatches(proof,{...scope,sha256:'b'.repeat(64)},{...expected,sha256:'b'.repeat(64)}),false);});
test('Missing independent BIC expectation cannot pass',()=>assert.equal(previewProofMatches(valid(),scope,null),false));
test('A malformed expected identity cannot pass',()=>assert.equal(previewProofMatches(valid(),{...scope,sha256:'invalid'},expected),false));
