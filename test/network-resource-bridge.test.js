import test from 'node:test';
import assert from 'node:assert/strict';
import {rendererNetworkBridge,networkResourceResult} from '../src/network_resource_bridge.js';
test('base lobby texture selection preserves typed misses and does not forward through a server session',async()=>{
 const refs=[],bridge=rendererNetworkBridge({lobbyTextureResourceResult:async ref=>{refs.push(ref);return ref==='icon'?{ok:true,value:{type:2073,bytes:new ArrayBuffer(4)}}:{ok:false,code:'RESOURCE_NOT_FOUND',message:'Missing base icon'};}});
 assert.equal((await bridge.lobbyTextureResource('icon')).type,2073);await assert.rejects(bridge.lobbyTextureResource('missing'),{code:'RESOURCE_NOT_FOUND'});assert.deepEqual(refs,['icon','missing']);
});
test('serialized resource misses reconstruct typed errors after the renderer boundary',async()=>{
 const calls=[],raw={getResourceResult:async(...args)=>{calls.push(args);return JSON.parse(JSON.stringify({ok:false,message:'Optional image missing',code:'RESOURCE_NOT_FOUND'}));}},bridge=rendererNetworkBridge(raw);
 await assert.rejects(bridge.getResource('session','optional',6),{code:'RESOURCE_NOT_FOUND',resRef:'optional',resourceType:6});assert.deepEqual(calls,[['session','optional',6]]);
 assert.throws(()=>networkResourceResult({ok:false,message:'Unavailable',code:'UNKNOWN'},'x',3),error=>error.message==='Unavailable'&&!error.code);assert.equal(networkResourceResult({ok:true,value:123}),123);
});
test('bridge preserves ordinary requests and supports non-Electron fixture providers',async()=>{
 const raw={getResource:async()=>17,connect:async()=>23};assert.equal(await rendererNetworkBridge(raw).getResource(),17);assert.equal(await rendererNetworkBridge(raw).connect(),23);assert.equal(rendererNetworkBridge(null),null);
});
test('selected texture data and typed misses cross the bridge without selecting another format',async()=>{
 const calls=[],bridge=rendererNetworkBridge({getTextureResourceResult:async(...args)=>{calls.push(args);return args[1]==='stone'?{ok:true,value:{type:2033,extension:'dds',bytes:new ArrayBuffer(4)}}:{ok:false,code:'RESOURCE_NOT_FOUND',message:'Missing texture'};}});
 assert.equal((await bridge.getTextureResource('owner','stone')).type,2033);
 await assert.rejects(bridge.getTextureResource('owner','missing'),{code:'RESOURCE_NOT_FOUND'});
 assert.deepEqual(calls,[['owner','stone'],['owner','missing']]);
});
