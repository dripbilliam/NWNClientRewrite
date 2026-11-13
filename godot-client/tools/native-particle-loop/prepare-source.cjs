'use strict';
// Freeze the accepted native source before a private bookkeeping experiment.
// This never edits the application headers or an installed library.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..');
const label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh experiment label required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
if(fs.existsSync(root))throw Error('Existing experiment preserved');
const build=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-kernel/build-manifest.json')));
for(const [file,expected] of Object.entries(build.sources))if(hash(fs.readFileSync(path.join(project,file)))!==expected)throw Error('Accepted native source differs: '+file);
fs.mkdirSync(root,{recursive:true});
for(const variant of ['control','candidate'])fs.cpSync(path.join(project,'native'),path.join(root,variant,'native'),{recursive:true,errorOnExist:true,force:false});
const target=path.join(root,'candidate/native/particle_presentation.hpp');let code=fs.readFileSync(target,'utf8');
const replace=(before,after)=>{if(code.split(before).length!==2)throw Error('Native seam differs: '+before.slice(0,90));code=code.replace(before,after);};
replace('NativeOwner* owner=nullptr;EngineVar providers;Controls controls;EnginePose pose;','NativeOwner* owner=nullptr;const EngineVar* providers=nullptr;Controls controls;EnginePose pose;');
replace('value.providers=&providers;','value.providers=providers;');
replace('void advance(NativeOwner& value,const Controls& next,const EngineVar& services,','void advance(NativeOwner& value,const EngineVar& services,');
replace('owner=&value;providers=services;controls=next;camera=view;','owner=&value;providers=&services;camera=view;');
replace('std::unordered_map<int64_t,std::unique_ptr<Entry>> entries;std::vector<int64_t> order;','std::unordered_map<int64_t,std::unique_ptr<Entry>> entries;std::vector<int64_t> order;\n std::vector<Entry*> frame_entries;bool order_dirty=true;\n void refresh_order(){\n  if(!order_dirty)return;std::vector<Entry*> next;next.reserve(order.size());for(const auto id:order)next.push_back(entries.at(id).get());frame_entries.swap(next);order_dirty=false;\n }');
// Every membership/order mutation remains forbidden while frame() is running.
// unique_ptr-owned Entry addresses survive unordered_map rehashes. Never cache
// a Godot Node, visibility result, transform, or opaque callback result.
replace('auto entry=std::make_unique<Entry>();entry->id=id;','order_dirty=true;auto entry=std::make_unique<Entry>();entry->id=id;');
replace('entries.erase(id);order.erase(', 'order_dirty=true;frame_entries.clear();entries.erase(id);order.erase(');
replace('order=std::move(next);','order=std::move(next);order_dirty=true;');
replace('std::vector<Entry*> drawing;drawing.reserve(entries.size());\n  for(const auto id:order){auto& entry=*entries.at(id);','refresh_order();std::vector<Entry*> drawing;drawing.reserve(entries.size());\n  for(auto* current:frame_entries){auto& entry=*current;const auto id=entry.id;');
replace('entry.elapsed+=delta;auto next=entry.controls;','entry.elapsed+=delta;auto& next=entry.step.controls;next=entry.controls;');
replace('!::has(common,"animating")||::get(common,"animating").boolean()','animation_enabled(common)');
replace('entry.step.advance(*entry.owner,next,entry.providers,camera,reject_plane);','entry.step.advance(*entry.owner,entry.providers,camera,reject_plane);');
replace('if(counters)for(const auto id:order){const auto& entry=*entries.at(id);','if(counters)for(const auto* current:frame_entries){const auto& entry=*current;const auto id=entry.id;');
replace('entries.clear();order.clear();counters=nullptr;','frame_entries.clear();order_dirty=true;entries.clear();order.clear();counters=nullptr;');
replace('struct Owner {\n GDExtensionObjectPtr identity=nullptr;',`// Read at the original per-emitter boundary: a preceding callback can mutate\n// this Dictionary. One keyed read preserves absent versus explicit nil.\nbool animation_enabled(const EngineVar& common){\n EngineVar value;destroy(value.data);GDExtensionBool present=false;get_keyed(common.data,::key("animating").data,value.data,&present);return !present||value.boolean();\n}\nstruct Owner {\n GDExtensionObjectPtr identity=nullptr;`);
fs.writeFileSync(target,code);
const pins=[];function walk(folder,relative=''){for(const e of fs.readdirSync(folder,{withFileTypes:true})){const name=path.posix.join(relative,e.name);if(e.isDirectory())walk(path.join(folder,e.name),name);else pins.push({relative:name,sha256:hash(fs.readFileSync(path.join(folder,e.name)))});}}
for(const variant of ['control','candidate']){const start=pins.length;walk(path.join(root,variant));fs.writeFileSync(path.join(root,variant,'source-pins.json'),JSON.stringify(pins.splice(start),null,2)+'\n',{flag:'wx'});}
const proof={version:1,root,mainSource:require('../native-feature-manifest.cjs').sourceIdentity(project).sha256,installedBinary:build.binarySha256,control:hash(fs.readFileSync(path.join(root,'control/native/particle_presentation.hpp'))),candidate:hash(Buffer.from(code)),changes:['stable native entry traversal rebuilt at membership/order boundaries','one controls copy instead of two','borrow providers from the retained same-entry storage','one keyed animation lookup at the existing per-emitter boundary'],sharedSourceWrites:0,sharedDllWrites:0,engineLaunches:0};
fs.writeFileSync(path.join(root,'source-proof.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(proof));
