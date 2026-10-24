const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),{createHash}=require('node:crypto');
const {writeExternalGodotBundle}=require('./external-bundle.cjs');

// Original assets and resolved table records stay in external runtime bundles.
// The returned envelope is small enough for the authenticated native bridge;
// phase/program metadata is not silently embedded into workspace reports.
async function writeVisualDefinitionBundle(definition,scope){
 const area=definition?.kind==='area-visual-definition';
 if(definition?.version!==1||!['visual-definition','area-visual-definition'].includes(definition.kind)||!definition.state||!area&&(!Array.isArray(definition.state.models88)||definition.state.models88.length!==3)||!definition.resources||Array.isArray(definition.resources)||!Array.isArray(definition.warnings)||!scope||!['connection','areaId','generation','transferId'].every(key=>Number.isSafeInteger(scope[key])&&scope[key]>=0))throw Error('Invalid scoped visual definition');
 if((area?[definition.state.model]:definition.state.models88).some(model=>model!==null&&(!model||typeof model!=='object'||!Object.hasOwn(definition.resources,model.resource))))throw Error('Visual definition references a missing model resource');
 const resources={};
 const entries=Object.entries(definition.resources);if(entries.length>32)throw Error('Visual resource limit exceeded');
 for(const [key,value]of entries){
  if(!/^[a-z0-9_]{1,16}$/i.test(key)||value?.manifest?.kind!=='visual-model')throw Error('Invalid private visual resource');
  resources[key]=await writeExternalGodotBundle(value,{registerLatest:false});
 }
 const document={...definition,resources,live:{...scope}},directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-effects-')),file=path.join(directory,'definition.json');
 const bytes=Buffer.from(JSON.stringify(document)+'\n');if(bytes.length>4*1024*1024)throw Error('Visual definition metadata limit exceeded');
 await fs.writeFile(file,bytes,{flag:'wx'});
 return{file,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,resourceCount:entries.length,resourceBytes:Object.values(resources).reduce((total,row)=>total+row.bytes,0),visualId:area?definition.state.visual180:definition.state.visualF8,warnings:definition.warnings.map(row=>row.code),accepted:false};
}
module.exports={writeVisualDefinitionBundle};
