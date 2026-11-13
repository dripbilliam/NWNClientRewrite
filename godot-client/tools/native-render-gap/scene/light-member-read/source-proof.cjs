'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),directory=path.join(project,'.cache/native-render-gap/scene/light-member-read-a'),manifestFile=path.join(directory,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile)),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const sourceRoot=path.join(project,'.cache/native-render-gap/engine/source');
const inputs=['modules/gdscript/gdscript.h','modules/gdscript/gdscript.cpp','scene/3d/node_3d.cpp','core/object/object.cpp','core/object/ref_counted.cpp','core/variant/dictionary.cpp','core/variant/variant.cpp','core/variant/variant_internal.h'];
const pins=inputs.map(relative=>({relative,file:path.join(sourceRoot,relative),sha256:sha(fs.readFileSync(path.join(sourceRoot,relative)))}));
const read=relative=>fs.readFileSync(path.join(sourceRoot,relative),'utf8');
assert(read('modules/gdscript/gdscript.h').includes('Variant debug_get_member_by_index(int p_idx) const { return members[p_idx]; }'));
assert(read('modules/gdscript/gdscript.cpp').includes('r_ret = members[E->value.index];'));
const cpp=fs.readFileSync(manifest.files[0].file,'utf8');for(const item of manifest.files)assert.equal(sha(fs.readFileSync(item.file)),item.sha256);
assert.equal((cpp.match(/debug_get_member_by_index\(/g)||[]).length,3);
assert(cpp.includes('const bool member_indices_enabled=light_member_indices_requested()&&plain_segment_requested;'));
assert(cpp.includes('LightMemberIndexSegment member_indices;'));
for(const value of ['props','state'])assert(cpp.includes('scratch_boundary('+value+');'));
assert(cpp.includes('entry.row.is_read_only()'));
const original=fs.readFileSync(manifest.files[0].original,'utf8'),dStart=original.indexOf('bool field_number('),dEnd=original.indexOf('bool dynamic_size(',dStart);assert(cpp.includes(original.slice(dStart,dEnd)));
const proof={version:1,success:true,created:new Date().toISOString(),proposal:{file:manifestFile,sha256:sha(fs.readFileSync(manifestFile))},pins,fixture:{file:path.join(__dirname,'fixture.gd'),sha256:sha(fs.readFileSync(path.join(__dirname,'fixture.gd')))},scope:'Source review and exact transformation checks only; no engine compilation/runtime or FPS evidence.',findings:[
{path:'modules/gdscript/gdscript.cpp',function:'GDScriptInstance::get',conclusion:'Getter-free member path performs map lookup then copies members[current index]; public release debug_get_member_by_index returns the same current Variant by value. E removes only the repeated map lookup.'},
{path:'modules/gdscript/gdscript.h',function:'debug_get_member_by_index',conclusion:'Public and outside TOOLS_ENABLED/DEBUG_ENABLED conditionals. No engine API extension or private member access required.'},
{path:'core/variant/variant.cpp',function:'Variant::reference',conclusion:'Valid Dictionary/Dictionary/INT destinations are initially NIL; copies increment container ownership or copy immediate integer, without copying contained Objects. No authored callback on this valid path.'},
{path:'scene/3d/node_3d.cpp',function:'Node3D::get_global_transform/_update_local_transform',conclusion:'Ordinary getter only reads dirty masks, composes math and parent transforms, and clears dirty bits; no signal, virtual notification, script call or queued flush.'},
{path:'core/object/object.cpp',function:'Object::get_meta',conclusion:'Direct metadata lookup and return-by-value. Valid enhanced BOOL/INT/FLOAT and priority INT copies are immediate. Invalid Object copies preserve original ref hooks and fail numeric/integer checks before any subsequent indexed read.'},
{path:'core/variant/dictionary.cpp',function:'Dictionary::operator[]',conclusion:'Nonconst readonly lookup assigns shared scratch Variant, potentially destroying prior Object. E invalidates before readonly props/state numeric reads and readonly row in_view read, then uses original get-by-name until next per-node proof.'},
{path:'core/variant/dictionary.cpp',function:'Dictionary::assign',conclusion:'Source replaces variant_map without clearing read_only scratch. Focused fixture uses this existing public behavior to leave scratch sole owner of a Finalizer and exercise actual PREDELETE schema reorder. Runtime feasibility still pending.'},
{path:'light_input_registry.cpp',function:'plain_reader_segment',conclusion:'Exact existing current node Script, ScriptInstance language/nonplaceholder, and reader Script checks remain on every row. Current source/COW and compiled getter-free typed schema derive the tuple once per pure segment. No index/value survives poll stack.'},
{path:'light_input_registry.cpp',function:'poll',conclusion:'Existing row replacement/update barriers clear tuple, as do unknown reader callback barriers. Poll-local destructor clears on every error/return. Explicit final barrier precedes tombstone deletion. Invalid numeric Objects cannot reach a subsequent member read.'}
],remaining:['Private engine compile','Actual readonly scratch Finalizer/reload exercise','64-row current-layout/count witness','All accepted D/canonical/segment/legacy regressions','Matched default-OFF/ON performance with actual use counters']};
const target=path.join(directory,'source-proof.json');if(fs.existsSync(target))throw Error('Existing source proof retained');fs.writeFileSync(target,JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,file:target,sha256:sha(fs.readFileSync(target)),scope:proof.scope}));
