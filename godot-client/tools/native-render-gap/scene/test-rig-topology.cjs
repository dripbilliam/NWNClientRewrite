const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const id=process.argv[2]??'rig-topology-a';if(!/^[a-z0-9-]+$/.test(id))throw Error('Invalid run name');
const directory=path.join(project,'.cache/native-render-gap/scene',id),renderer=path.join(directory,'renderer');
if(fs.existsSync(directory))throw Error('Frozen test evidence exists');fs.mkdirSync(renderer,{recursive:true});const pins=[];
const version2=process.argv.includes('--v2');
const files=version2?[['rig_topology_census.gd','tools/native-render-gap/scene/rig_topology_census.gd'],['rig_topology_census_v2.gd','tools/native-render-gap/scene/rig_topology_census_v2.gd'],['rig_topology_v2_test.gd','test.gd']]:[['rig_topology_census.gd','rig_topology_census.gd'],['rig_topology_test.gd','test.gd']];
for(const [from,to]of files){const bytes=fs.readFileSync(path.join(__dirname,from));fs.mkdirSync(path.dirname(path.join(renderer,to)),{recursive:true});fs.writeFileSync(path.join(renderer,to),bytes,{flag:'wx'});pins.push({input:from,copy:to,sha256:sha(bytes)});}
if(version2){const relative='systems/native_render/chunk_models.gd',bytes=fs.readFileSync(path.join(project,relative));fs.mkdirSync(path.dirname(path.join(renderer,relative)),{recursive:true});fs.writeFileSync(path.join(renderer,relative),bytes,{flag:'wx'});}
fs.writeFileSync(path.join(renderer,'project.godot'),'config_version=5\n[application]\nconfig/name="Cold rig topology check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
fs.mkdirSync(path.join(renderer,'.godot'));fs.writeFileSync(path.join(renderer,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');const args=['--headless','--path',renderer,'--script','res://test.gd','--',`--report=${path.join(directory,'native.json')}`];
const r=spawnSync(engine,args,{encoding:'utf8',windowsHide:true,timeout:15000,maxBuffer:1024*1024});fs.writeFileSync(path.join(directory,'stdout.log'),r.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(directory,'stderr.log'),r.stderr??'',{flag:'wx'});
const native=fs.existsSync(path.join(directory,'native.json'))?JSON.parse(fs.readFileSync(path.join(directory,'native.json'))):null;const merged=(r.stdout??'')+(r.stderr??'');const clean=!/SCRIPT ERROR|Parse Error|Compile Error|leaked|still in use|crash/i.test(merged);
const changed=pins.filter(p=>sha(fs.readFileSync(path.join(__dirname,p.input)))!==p.sha256||sha(fs.readFileSync(path.join(renderer,p.copy)))!==p.sha256).map(p=>p.input);
const receipt={success:r.status===0&&native?.success===true&&clean&&!changed.length,code:r.status,clean,native,pins,changed,engineSha256:sha(fs.readFileSync(engine)),scope:'Pure constructed SceneTree topology census checks, no actual animation/Part writes/GPU/FPS'};fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(receipt,null,2),{flag:'wx'});console.log(JSON.stringify({directory,...receipt},null,2));process.exitCode=receipt.success?0:1;
