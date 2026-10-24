import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {serverDiscoveryRequest,serverInfoRequest,readServerQueryResponse,readServerInfoAdvertisement} from '../src/server_discovery.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-server-query-v1.json',import.meta.url)));

test('native local server accepts discovery/info requests and supplies Prelude state',()=>{
 const sent=capture.requests.map(hex=>Buffer.from(hex,'hex')),port=sent[0].readUInt16LE(4);
 assert.deepEqual(Buffer.from(serverDiscoveryRequest(port)),sent[0]);assert.deepEqual(Buffer.from(serverInfoRequest(port)),sent[1]);
 for(const {hex,...expected}of capture.responses){
  const result=readServerQueryResponse(Buffer.from(hex,'hex'));
  if(result.advertisement)result.advertisement=Buffer.from(result.advertisement).toString('hex');
  assert.deepEqual(result,expected);
 }
 assert.equal(capture.responses[0].serverName,'Replacement Client Compatibility');
 assert.equal(capture.responses[1].moduleName,'Prelude');assert.equal(capture.responses[1].maximumPlayers,2);
});

test('truncated fixed fields/names, unknown packets and unsupported versions are rejected',()=>{
 for(const row of capture.responses){
  const bytes=Buffer.from(row.hex,'hex'),required=row.type==='discovery'?9+bytes[8]:20+bytes[19];
  for(let length=0;length<required;length++)assert.throws(()=>readServerQueryResponse(bytes.subarray(0,length)),/Truncated/);
 }
 assert.throws(()=>readServerQueryResponse(Buffer.from('BNZZ')),/Unsupported native server-query response/);
 const info=Buffer.from(capture.responses[1].hex,'hex');info[6]=0;assert.throws(()=>readServerQueryResponse(info),/version/);
 const discovery=Buffer.from(capture.responses[0].hex,'hex');discovery[7]=6;assert.throws(()=>readServerQueryResponse(discovery),/section/);
});

test('query strings preserve explicit byte lengths, CP1252 and native leading-NUL assignment',()=>{
 const bytes=Buffer.from('424e4552550114000480004162','hex');assert.equal(readServerQueryResponse(bytes).serverName,'€\0Ab');
 bytes[9]=0;assert.equal(readServerQueryResponse(bytes).serverName,'');
 assert.throws(()=>serverDiscoveryRequest(0),/port/);assert.throws(()=>serverInfoRequest(65536),/port/);
 assert.throws(()=>serverDiscoveryRequest(5121,-1),/section/);
});

test('public BNXR resource advertisement preserves native URL/hash and flags/language order',()=>{
 const string=value=>Buffer.concat([Buffer.from([value.length]),Buffer.from(value)]),primary='1'.repeat(40),extra='2'.repeat(40);
 const bytes=Buffer.concat([Buffer.from([2,1]),string('https://example.invalid/content'),string(primary),Buffer.from([1,3,255]),string(extra)]);
 assert.deepEqual(readServerInfoAdvertisement(bytes),{url:'https://example.invalid/content',hash:primary,manifests:[{flags:3,language:255,hash:extra}]});
 assert.deepEqual(readServerInfoAdvertisement(Buffer.concat([bytes,Buffer.from([0,0])])),readServerInfoAdvertisement(bytes));
 for(let length=1;length<bytes.length;length++)assert.throws(()=>readServerInfoAdvertisement(bytes.subarray(0,length)),/Truncated/);
 for(const bytes of [Buffer.alloc(0),Buffer.from([1]),Buffer.from([2,0])])assert.equal(readServerInfoAdvertisement(bytes),null);
 const bad=Buffer.from(bytes);bad[2+1+'https://example.invalid/content'.length+1]='g'.charCodeAt(0);assert.throws(()=>readServerInfoAdvertisement(bad),/manifest hash/);
});

test('Arelith live public response advertises a separate repository and primary content manifest',()=>{
 const observed=JSON.parse(fs.readFileSync(new URL('../backups/animations/arelith-public-discovery-v1.json',import.meta.url)));
 assert.deepEqual(readServerInfoAdvertisement(Buffer.from(observed.advertisementHex,'hex')),{url:'http://nwsync.nwnarelith.com',hash:'1fb727f690a7e0c462f79ef9177f5977c73d756f',manifests:[]});
});
