// These are transport/guard tests only; importing the utilities never starts Godot.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {inside,safeName,privateProject,presets,cleanEngine,comparePacks,runtimeBundle,runtimeArguments,sha} from '../native-startup-experiment-lib.mjs';

test('authored cache boundaries reject traversal and previous evidence labels',()=>{
 assert.throws(()=>inside('C:/owned/stage','C:/owned/elsewhere'));
 assert.throws(()=>safeName('../escape'));assert.throws(()=>safeName(''));assert.equal(safeName('startup-v1'),'startup-v1');
});
test('private project preserves original autoload/render settings exactly',()=>{
 const original='config_version=5\n[application]\nconfig/name="Real"\nrun/main_scene="res://main.tscn"\n[autoload]\nClientAPI="*res://systems/client_api/client_api.gd"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
 const copy=privateProject(original);
 assert.ok(copy.endsWith(original.slice(original.indexOf('[autoload]'))));
 assert.match(copy,/run\/main_scene="res:\/\/__startup_probe.tscn"/);assert.match(copy,/config\/use_custom_user_dir=true/);
 assert.match(presets(),/script_export_mode=0/);assert.match(presets(),/script_export_mode=2/);
});
test('strict engine rejection is independent from reported success',()=>{
 assert.equal(cleanEngine('Godot Engine\nSTARTUP_PROBE {}\n'),true);
 for(const line of ['ERROR: failure','WARNING: unsupported','SCRIPT ERROR: parse','ObjectDB instances leaked at exit'])assert.equal(cleanEngine(line),false);
});
test('native adjacent routing uses identical basename and no disabled path override',()=>{
 const bundle=runtimeBundle(path.resolve('owned-stage'),'B');
 assert.equal(path.parse(bundle.executable).name,path.parse(bundle.pack).name);
 assert.equal(path.dirname(bundle.executable),path.dirname(bundle.pack));
 const args=runtimeArguments(path.resolve('report.json'),path.resolve('engine.log'));
 assert.ok(!args.includes('--path'));assert.ok(!args.includes('--main-pack'));assert.ok(args.includes('--headless'));
});
test('pack comparison proves text hashes, tokens/remaps and equal non-script bytes',()=>{
 const source=Buffer.from('extends Node\n'),binary=Buffer.alloc(12);binary.write('GDSC');binary.writeUInt32LE(100,4);
 const remap=Buffer.from('[remap]\npath="res://root.gdc"\n'),common=Buffer.from('same-project');
 const entry=data=>({data,bytes:data.length,sha256:sha(data)});
 const raw={entries:new Map([['root.gd',entry(source)],['project.binary',entry(common)]])};
 const token={entries:new Map([['root.gdc',entry(binary)],['root.gd.remap',entry(remap)],['project.binary',entry(common)]])};
 assert.equal(comparePacks(raw,token,[{relative:'root.gd',sha256:sha(source)}]).scripts,1);
 token.entries.set('project.binary',entry(Buffer.from('changed')));
 assert.throws(()=>comparePacks(raw,token,[{relative:'root.gd',sha256:sha(source)}]),/Non-script pack divergence/);
});
