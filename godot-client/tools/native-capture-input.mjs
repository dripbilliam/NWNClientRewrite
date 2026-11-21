// Offline protocol fixture only. No model selection, rendering, geometry,
// materials, animation preparation, Three, GLB or installed/network fallback.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {createHash} from 'node:crypto';
import {SceneReplay} from '../../electron/scene_replay.mjs';
import {NetworkWorld} from '../../src/network_world.js';
const arg=n=>process.argv.find(a=>a.startsWith('--'+n+'='))?.slice(n.length+3);
const run=arg('run')??'native-capture-input-v1';if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid input descriptor name');
const supplements=process.argv.filter(a=>a.startsWith('--supplement=')).map(a=>path.resolve(a.slice(13)));
if(!arg('capture')||!arg('supplement'))throw Error('Explicit sealed capture/supplement required');
const replay=await SceneReplay.open(path.resolve(arg('capture'))),context=replay.views.at(-1)?.context;
if(!context)throw Error('Captured view/context is missing');
const diagnostics=[],world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)});
for(const record of replay.records)if(record.context===context&&record.event.kind==='message')world.apply(structuredClone(record.event.message));
if(diagnostics.length)throw Error('Raw protocol reconstruction rejected input');
const area=world.registry.get(world.areaId)?.state;
if(!area)throw Error('Final raw area packet is absent');
const fixture={version:1,scope:'Offline protocol-state fixture; native Godot must select/prepare all rendered resources',capture:path.resolve(arg('capture')),supplements,context,eventsSha256:replay.archive.manifest.eventsSha256,area,controlledId:world.localObjectId,entry:world.entry,time:world.time,module:world.module,objects:[...world.registry.objects.values()],view:replay.views.at(-1).event.view};
const bytes=Buffer.from(JSON.stringify(fixture,(_key,value)=>typeof value==='bigint'?{native64:value.toString()}:value instanceof ArrayBuffer?[...new Uint8Array(value)]:ArrayBuffer.isView(value)?Array.from(value):value));
const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-protocol-input-')),input=path.join(directory,'decoded-input.json');await fs.writeFile(input,bytes,{flag:'wx'});
const report={scope:fixture.scope,input,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,eventsSha256:fixture.eventsSha256,context,areaId:area.id,areaName:area.resRef,tiles:area.tiles.length,objects:fixture.objects.length,renderingPrepared:false,network:false};
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report));
