const fs=require('node:fs/promises'),syncFs=require('node:fs'),path=require('node:path'),os=require('node:os'),{createHash}=require('node:crypto'),{pathToFileURL}=require('node:url');
function resolveGodotExporterBuild(root,argument){
 const directory=syncFs.realpathSync(path.resolve(root,argument)),allowed=syncFs.realpathSync(path.join(root,'godot-client/.cache/exporter')),relative=path.relative(allowed,directory);if(!/^v[1-9][0-9]*[\\/]diagnostic-build$/.test(relative))throw Error('Expected the isolated versioned Godot export bridge');const index=path.join(directory,'index.html');return{directory,index,applicationUrl:pathToFileURL(index).href,experimental:true};
}
async function writeExternalGodotBundle(exported,{registerLatest=true}={}){
 const delta=exported?.manifest?.kind==='entity-content';
 const visual=exported?.manifest?.kind==='visual-model',m=exported?.manifest;
 if(visual&&(m.rigs?.version!==1||m.rigs.entities?.length!==1||m.rigs.entities[0].id!==0||!m.rigs.entities[0].models?.length||m.modelResources?.length!==m.rigs.entities[0].models.length||m.inventory?.length!==0||m.entities?.length!==0))throw Error('Invalid private visual resource');
 if(exported?.manifest?.version!==1||!(exported.manifest.counts?.meshes>0||(delta||visual)&&exported.manifest.counts?.meshes===0)||!visual&&!exported.manifest.inventory?.length||typeof exported.glbBase64!=='string'||exported.glbBase64.length>768*1024*1024||!/^[A-Za-z0-9+/]*={0,2}$/.test(exported.glbBase64))throw Error('Invalid, empty or oversized export envelope');
 const bytes=Buffer.from(exported.glbBase64,'base64');if(bytes.length<20||bytes.readUInt32LE(0)!==0x46546c67||bytes.readUInt32LE(4)!==2||bytes.readUInt32LE(8)!==bytes.length)throw Error('Invalid GLB container');
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),visual?'nwn-godot-visual-':'nwn-godot-room-')),scene=path.join(directory,'room.glb'),sha256=createHash('sha256').update(bytes).digest('hex');
 const metadata=JSON.stringify({...exported.manifest,sha256,bytes:bytes.length},null,2)+'\n',metadataSha256=createHash('sha256').update(metadata).digest('hex');
 await fs.writeFile(scene,bytes,{flag:'wx'});await fs.writeFile(path.join(directory,'room.json'),metadata,{flag:'wx'});
 if(registerLatest&&!visual){const reference=path.resolve(__dirname,'../.cache/latest-room.json');await fs.mkdir(path.dirname(reference),{recursive:true});await fs.writeFile(reference,JSON.stringify({version:1,scene,sha256,scope:'External offline capture; no server connection'},null,2)+'\n');}
 return{scene,sha256,metadataSha256,bytes:bytes.length,counts:exported.manifest.counts,gaps:exported.manifest.gaps,accepted:false};
}
module.exports={resolveGodotExporterBuild,writeExternalGodotBundle};
