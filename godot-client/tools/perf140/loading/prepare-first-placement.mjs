import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^first-placement-[a-z0-9-]+$/.test(label??''))throw Error('Fresh first-placement label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),parentFile=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/overlay.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');
const baseline=path.join(stage,'baseline'),candidate=path.join(stage,'candidate'),pins=[];
for(const target of [baseline,candidate]){
 fs.mkdirSync(target,{recursive:true});for(const pin of parent.trialPins){const bytes=fs.readFileSync(path.join(parent.rendererProject,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen source changed: '+pin.relative);const file=path.join(target,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);if(target===baseline)pins.push({...pin});}
}
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('First-placement boundary changed: '+a);return s.replace(a,b);};
const relative='systems/native_render/model_template.gd',original=fs.readFileSync(path.join(baseline,relative));let value=original.toString().replaceAll('\r\n','\n');
value=once(value,'var scene: PackedScene','var scene: PackedScene\n# Detached construction tree may serve the first placement after scene packing.\n# It has never entered the SceneTree; later placements use the immutable pack.\nvar _first_root: Node3D\nvar first_instance_reuses:=0\nvar packed_instance_creations:=0');
value=once(value,'\troot_node.free()\n\tif began>0: preparation_timings.root_dispose_ms=', '\tif result==OK: _first_root=root_node\n\telse: root_node.free()\n\tif began>0: preparation_timings.root_dispose_ms=');
value=once(value,'\tvar placement:=Placement.new(); var root_node:=scene.instantiate()', '\tvar placement:=Placement.new(); var root_node: Node\n\tif is_instance_valid(_first_root):\n\t\troot_node=_first_root; _first_root=null; first_instance_reuses+=1\n\telse:\n\t\troot_node=scene.instantiate(); packed_instance_creations+=1');
value+='\nfunc _notification(what: int) -> void:\n\t# Eviction before the first create must release the detached Node hierarchy.\n\tif what==NOTIFICATION_PREDELETE and is_instance_valid(_first_root):\n\t\t_first_root.free(); _first_root=null\n';
fs.writeFileSync(path.join(candidate,relative),value);
const fixture='tests/fixtures/native_perf140_loading_model_template_before.gd';for(const target of [baseline,candidate])fs.writeFileSync(path.join(target,fixture),original);
const changed=[{relative,before:hash(original),after:hash(Buffer.from(value))}];
const manifest={version:1,label,stage,baseline,candidate,parent:{file:parentFile,sha256:hash(parentBytes),rendererProject:parent.rendererProject},pins,fixture:{relative:fixture,sha256:hash(original)},changed,backup:[{file:path.join(baseline,relative),sha256:hash(original),verified:true}],serverConnections:0,sharedNativeBuilds:0,scope:'Reuse only the detached already-constructed hierarchy for the first placement after packing. Subsequent clones, immutable packed rest data, resource identity and ownership policies remain unchanged; pre-delete releases unused retained hierarchy.'};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({success:true,file,baseline,candidate,changed}));
