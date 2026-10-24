const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),{createHash}=require('node:crypto');
const{writeVisualDefinitionBundle}=require('./visual-definition-bundle.cjs');
const scope={connection:1,areaId:2,generation:3,transferId:4};
function fixture(){
 const bytes=Buffer.alloc(20);bytes.writeUInt32LE(0x46546c67,0);bytes.writeUInt32LE(2,4);bytes.writeUInt32LE(20,8);
 const resource={manifest:{version:1,kind:'visual-model',inventory:[],entities:[],counts:{meshes:0},modelResources:['authored'],rigs:{version:1,entities:[{id:0,models:[{}]}]}},glbBase64:bytes.toString('base64')};
 return{version:1,kind:'visual-definition',state:{visualF8:42,models88:[{id:1,resource:'authored',alias:'fxground'},null,null]},programs:{},visual:{},resources:{authored:resource},warnings:[]};
}
async function clean(folder){
 const target=await fs.realpath(folder),temp=await fs.realpath(os.tmpdir());
 assert.ok(target.startsWith(temp+path.sep)&&/^nwn-godot-(effects|visual)-/.test(path.basename(target)));await fs.rm(target,{recursive:true});
}
test('effect definitions externalize original assets and hash scope/phase metadata without retaining base64 payloads',async()=>{
 const bundle=await writeVisualDefinitionBundle(fixture(),scope);let data;
 try{
  const bytes=await fs.readFile(bundle.file);data=JSON.parse(bytes);assert.equal(bundle.sha256,createHash('sha256').update(bytes).digest('hex'));assert.deepEqual(data.live,scope);assert.equal(bundle.resourceCount,1);assert.equal(bundle.accepted,false);assert.ok(!bytes.toString().includes('glbBase64'));assert.equal(data.resources.authored.metadataSha256.length,64);assert.ok(!data.resources.authored.scene.startsWith(process.cwd()+path.sep));assert.equal(bundle.resourceBytes,20);
 }finally{if(data)for(const resource of Object.values(data.resources))await clean(path.dirname(resource.scene));await clean(path.dirname(bundle.file));}
});
test('malformed ownership, scope and missing resource references fail before any file writes',async()=>{
 for(const change of [f=>f.state.models88=[],f=>f.state.models88[0].resource='absent',f=>f.resources=[],f=>f.warnings=null,f=>f.kind='other']){const input=fixture();change(input);await assert.rejects(writeVisualDefinitionBundle(input,scope),/definition|resource/);}
 for(const value of [null,{...scope,generation:-1},{...scope,connection:NaN},{...scope,transferId:1.5}])await assert.rejects(writeVisualDefinitionBundle(fixture(),value),/scoped/);
});
