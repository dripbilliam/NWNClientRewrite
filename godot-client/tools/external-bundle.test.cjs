const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{pathToFileURL}=require('node:url');
const {resolveGodotExporterBuild,writeExternalGodotBundle}=require('./external-bundle.cjs');
test('the isolated exporter exposes the exact file URL required by trusted replay resource requests',()=>{
 const root=path.resolve(__dirname,'../..'),base=path.join(root,'godot-client/.cache/exporter'),folder=path.join(base,'v'+process.pid+Date.now()),directory=path.join(folder,'diagnostic-build');fs.mkdirSync(directory,{recursive:true});
 try{fs.writeFileSync(path.join(directory,'index.html'),'<!doctype html>',{flag:'wx'});const selected=resolveGodotExporterBuild(root,directory);assert.equal(selected.applicationUrl,pathToFileURL(selected.index).href);assert.equal(selected.experimental,true);assert.throws(()=>resolveGodotExporterBuild(root,root),/Expected/);}
 finally{const target=fs.realpathSync(folder);assert.ok(target.startsWith(fs.realpathSync(base)+path.sep));fs.rmSync(target,{recursive:true});}
});
test('empty captures and missing model inventory cannot become native engine bundles',async()=>{
 for(const manifest of [{version:1,counts:{meshes:0},inventory:[{id:1}]},{version:1,counts:{meshes:1},inventory:[]}])await assert.rejects(writeExternalGodotBundle({manifest,glbBase64:'AAAA'}),/empty/);
});

test('authenticated metadata digest covers rig and revision data as well as the GLB digest',async()=>{
 const crypto=require('node:crypto'),os=require('node:os');
 const glb=Buffer.alloc(20);glb.writeUInt32LE(0x46546c67,0);glb.writeUInt32LE(2,4);glb.writeUInt32LE(glb.length,8);
 const manifest={version:1,kind:'entity-content',counts:{meshes:0},inventory:[{id:1}],content:[{id:1,revision:3}],rigs:{version:1,entities:[]}};
 const bundle=await writeExternalGodotBundle({manifest,glbBase64:glb.toString('base64')},{registerLatest:false});
 try{
  const bytes=fs.readFileSync(bundle.scene.replace(/\.glb$/,'.json'));
  assert.equal(bundle.metadataSha256,crypto.createHash('sha256').update(bytes).digest('hex'));
  const changed=JSON.parse(bytes);changed.content[0].revision=4;
  assert.notEqual(bundle.metadataSha256,crypto.createHash('sha256').update(JSON.stringify(changed)).digest('hex'));
 }finally{
  const folder=fs.realpathSync(path.dirname(bundle.scene));assert.ok(folder.startsWith(fs.realpathSync(os.tmpdir())+path.sep+'nwn-godot-room-'));fs.rmSync(folder,{recursive:true});
 }
});

test('private visual resources use external bundles without replacing the captured-room reference',async()=>{
 const glb=Buffer.alloc(20);glb.writeUInt32LE(0x46546c67,0);glb.writeUInt32LE(2,4);glb.writeUInt32LE(20,8);
 const manifest={version:1,kind:'visual-model',counts:{meshes:0},inventory:[],entities:[],modelResources:['authored'],rigs:{version:1,entities:[{id:0,models:[{}]}]}},reference=path.resolve(__dirname,'../.cache/latest-room.json'),before=fs.existsSync(reference)?fs.readFileSync(reference):null;
 const bundle=await writeExternalGodotBundle({manifest,glbBase64:glb.toString('base64')});
 try{
  assert.ok(path.basename(path.dirname(bundle.scene)).startsWith('nwn-godot-visual-'));assert.deepEqual(fs.existsSync(reference)?fs.readFileSync(reference):null,before);
  for(const change of [m=>m.entities.push({id:1}),m=>m.rigs.entities[0].id=1,m=>m.modelResources=[],m=>m.inventory.push({id:1})]){const bad=structuredClone(manifest);change(bad);await assert.rejects(writeExternalGodotBundle({manifest:bad,glbBase64:glb.toString('base64')}),/private/);}
 }finally{const folder=fs.realpathSync(path.dirname(bundle.scene)),temp=fs.realpathSync(require('node:os').tmpdir());assert.ok(folder.startsWith(temp+path.sep+'nwn-godot-visual-'));fs.rmSync(folder,{recursive:true});}
});
