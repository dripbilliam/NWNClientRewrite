import assert from 'node:assert/strict';import path from 'node:path';
export function syncHandoffFixture(value){
 assert.equal(value.version,1);assert.ok(path.isAbsolute(value.cacheDirectory));assert.equal(value.servers.length,2);
 for(const [i,s]of value.servers.entries()){
  assert.equal(s.label,i?'B':'A');assert.equal(s.port,i?5122:5121);assert.match(s.hash,/^[a-f0-9]{40}$/);const url=new URL(s.url);assert.equal(url.protocol,'http:');assert.equal(url.hostname,'127.0.0.1');assert.equal(url.username,'');assert.equal(url.password,'');assert.equal(url.search,'');assert.equal(url.hash,'');
  assert.equal(s.entries.length,15);assert.equal(new Set(s.entries.map(v=>v.name+':'+v.type)).size,15);assert.equal(s.pixel.length,4);assert.ok(s.pixel.every(v=>Number.isInteger(v)&&v>=0&&v<=255));
  for(const e of s.entries){assert.match(e.name,/^(?:gd_(?:sync_(?:[0-9]|1[01]|icon)|only_[ab])|port_nui_jui)$/);assert.ok([3,2017,2083].includes(e.type));assert.match(e.hash,/^[a-f0-9]{40}$/);assert.ok(Number.isSafeInteger(e.size)&&e.size>0&&e.size<100000);}
  assert.ok(s.entries.some(v=>v.name==='gd_only_'+s.label.toLowerCase()));assert.ok(s.entries.some(v=>v.name==='gd_sync_icon'&&v.type===3));
  const expected=[...Array.from({length:12},(_,n)=>'gd_sync_'+n+':2017'),'gd_sync_icon:3','gd_only_'+s.label.toLowerCase()+':2017','port_nui_jui:2083'].sort();assert.deepEqual(s.entries.map(v=>v.name+':'+v.type).sort(),expected);
 }
 assert.notEqual(value.servers[0].hash,value.servers[1].hash);return value;
}
