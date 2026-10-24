const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {JsonLines,validateCommand,MAX_FRAME}=require('./local-protocol.cjs');

test('combat feedback preferences are typed local settings available before area admission but owned by the current connection',()=>{
 const c={connection:2},m={connection:2,kind:'client-feedback-options',values:{floatingFeedback:false,damageTotalsOnly:true}};
 assert.doesNotThrow(()=>validateCommand(m,c));
 for(const change of [{connection:1},{values:null},{values:{floatingFeedback:1,damageTotalsOnly:false}},{values:{floatingFeedback:true}},{values:{floatingFeedback:true,damageTotalsOnly:false,color:'fake'}}])assert.throws(()=>validateCommand({...m,...change},c));
});
test('inventory shortcut drops require scoped private inventory/quickbar handles and a bounded destination',()=>{
 const c={connection:2,areaId:7,generation:1},m={...c,kind:'inventory-shortcut',viewId:4,entryId:9,quickbarId:6,index:35};
 assert.doesNotThrow(()=>validateCommand(m,c));for(const change of [{viewId:-1},{entryId:'9'},{quickbarId:-1},{index:36},{index:0.5},{generation:0},{connection:1}])assert.throws(()=>validateCommand({...m,...change},c));
});
test('map and journal requests remain local scoped commands with bounded category handles',()=>{const c={connection:2,areaId:7,generation:1};for(const row of[{kind:'map-open'},{kind:'map-close'},{kind:'journal-open'},{kind:'journal-close'},{kind:'journal-page',viewId:2,page:3}])assert.doesNotThrow(()=>validateCommand({...c,...row},c));for(const row of[{kind:'journal-page',viewId:-1,page:0},{kind:'journal-page',viewId:2,page:4},{kind:'map-open',generation:0}])assert.throws(()=>validateCommand({...c,...row},c));});
test('context menus accept only scoped IDs/slots; targeting and original cursors stay bounded',()=>{
 const current={connection:3,areaId:7,generation:2},open={...current,kind:'radial-open',requestId:4,targetId:null,position:[1,2,3]};assert.doesNotThrow(()=>validateCommand(open,current));
 for(const change of [{requestId:-1},{targetId:'7'},{position:[Infinity,0,0]},{generation:1}])assert.throws(()=>validateCommand({...open,...change},current));
 const select={...current,kind:'radial-select',requestId:4,menuId:1,slot:7};assert.doesNotThrow(()=>validateCommand(select,current));assert.throws(()=>validateCommand({...select,slot:8},current));assert.throws(()=>validateCommand({...select,menuId:0},current));
 assert.doesNotThrow(()=>validateCommand({...current,kind:'target-select',token:7,targetId:null,position:[0,1,2]},current));assert.throws(()=>validateCommand({...current,kind:'target-select',token:7,targetId:2,position:[0,NaN,2]},current));
 for(const cursorId of [1,58,91,292])assert.doesNotThrow(()=>validateCommand({...current,kind:'cursor-request',cursorId},current));for(const cursorId of [0,293,1.5])assert.throws(()=>validateCommand({...current,kind:'cursor-request',cursorId},current));
});
test('examination preserves unsigned target identity; chat channels and Tell recipient follow native input ownership',()=>{
 const current={connection:3,areaId:7,generation:2};
 assert.doesNotThrow(()=>validateCommand({...current,kind:'examine',targetId:0xffffffff},current));
 assert.throws(()=>validateCommand({...current,kind:'examine',targetId:-1},current));
 for(const channel of [1,2,3,6,14])assert.doesNotThrow(()=>validateCommand({...current,kind:'chat',text:'hello',channel},current));
 assert.doesNotThrow(()=>validateCommand({...current,kind:'chat',text:'hello',channel:4,recipient:'Ada'},current));
 for(const fields of [{channel:5},{channel:4},{channel:4,recipient:' '},{channel:4,recipient:'x'.repeat(129)},{channel:1,recipient:'Ada'}])assert.throws(()=>validateCommand({...current,kind:'chat',text:'hello',...fields},current));
});
test('drive ownership, coordinates and collision-only retries are bounded separately from wire input',()=>{
 const current={connection:1,areaId:7,generation:3},request={...current,kind:'drive',actorId:1,lifetime:1,requestId:2,operation:'drive',position:[1,2,0],render:[1,2,0],orientation:[1,0,0],heading:0,flags:3,transmit:true,poses:[]};
 assert.equal(validateCommand(request,current),request);
 for(const change of [{flags:64},{position:[NaN,0,0]},{heading:3600},{actorId:-1},{lifetime:0},{poses:Array(129).fill({id:2,position:[0,0,0]})}])assert.throws(()=>validateCommand({...request,...change},current));
 assert.throws(()=>validateCommand({...request,kind:'drive-preview-request'},current),/cannot transmit/);
 assert.doesNotThrow(()=>validateCommand({...request,kind:'drive-preview-request',transmit:false},current));
 assert.throws(()=>validateCommand({...request,connection:3},current),/Stale/);
});
class Socket extends EventEmitter{destroy(){this.destroyed=true;}write(value){this.output=(this.output??'')+value;}}
test('native transport handles split UTF-8 and multiple coalesced frames',()=>{
 const socket=new Socket(),wire=new JsonLines(socket),received=[];wire.on('message',m=>received.push(m));const raw=Buffer.from('{"text":"Nibs · é"}\n{"kind":"poses"}\n');
 for(let at=0;at<raw.length;at++)socket.emit('data',raw.subarray(at,at+1));
 assert.deepEqual(received,[{text:'Nibs · é'},{kind:'poses'}]);assert.equal(wire.buffer.length,0);
});
test('native transport rejects malformed, non-object, and oversized frames',()=>{
 for(const data of [Buffer.from('null\n'),Buffer.from('{bad}\n'),Buffer.alloc(MAX_FRAME+1,65)]){const socket=new Socket(),wire=new JsonLines(socket);socket.emit('data',data);assert.equal(socket.destroyed,true);assert.equal(wire.buffer.length,0);}
});
test('native transport serializes a bounded JSON record without interpreting game text',()=>{
 const socket=new Socket(),wire=new JsonLines(socket);wire.send({text:'<cxyz>server text</c>\nsecond line'});assert.equal(socket.output.split('\n').length,2);assert.deepEqual(JSON.parse(socket.output),{text:'<cxyz>server text</c>\nsecond line'});assert.throws(()=>wire.send({text:'a'.repeat(MAX_FRAME)}));
});

test('shortcut assignment menu requires a current scoped destination and private request identity',()=>{
 const c={connection:2,areaId:9,generation:1},m={...c,kind:'quickbar-menu',quickbarId:7,requestId:2,index:35};assert.doesNotThrow(()=>validateCommand(m,c));
 for(const change of [{connection:1},{generation:0},{quickbarId:-1},{requestId:-1},{index:36},{index:0.5}])assert.throws(()=>validateCommand({...m,...change},c));
});

test('radial shortcut assignment requires both owners and a bounded physical leaf slot',()=>{
 const c={connection:2,areaId:9,generation:1},m={...c,kind:'radial-shortcut',quickbarId:7,menuId:5,requestId:2,slot:7,index:35};
 assert.doesNotThrow(()=>validateCommand(m,c));
 for(const change of [{connection:1},{generation:0},{menuId:0},{quickbarId:-1},{requestId:-1},{slot:8},{slot:0.5},{index:36}])assert.throws(()=>validateCommand({...m,...change},c));
});
test('area ownership rejects stale movement, replies and malformed coordinates',()=>{
 const current={areaId:2147483649,generation:3},base={...current,kind:'walk',position:[3,0,-10]};assert.equal(validateCommand(base,current),base);
 for(const m of [{...base,generation:2},{...base,areaId:0},{...base,position:[NaN,0,0]},{...base,position:[1,2]},{...base,kind:'connect',host:'remote'}])assert.throws(()=>validateCommand(m,current));
 assert.doesNotThrow(()=>validateCommand({...current,kind:'reply',entryId:7,replyId:0xffffffff,abort:true},current));assert.throws(()=>validateCommand({...current,kind:'reply',entryId:7,replyId:-1,abort:true},current));
});
test('server object IDs retain all 32 unsigned bits and chat has a bounded length',()=>{
 const current={areaId:2147483649,generation:1};assert.doesNotThrow(()=>validateCommand({...current,kind:'interact',targetId:4294967091},current));assert.throws(()=>validateCommand({...current,kind:'interact',targetId:4294967296},current));assert.throws(()=>validateCommand({...current,kind:'chat',text:'a'.repeat(1001)},current));
});

test('native book and shortcut commands accept only bounded scoped handles, never arbitrary spell bindings',()=>{
 const current={connection:3,areaId:9,generation:2},base={...current};
 const valid=[{kind:'spellbook-open'},{kind:'spellbook-query',classIndex:0,level:9,metamagic:32},{kind:'book-prepare',viewId:2,entryId:0,destinationId:4},{kind:'quickbar-assign',viewId:2,entryId:0,index:35},{kind:'quickbar-move',quickbarId:4,sourceIndex:0,index:12}];
 for(const value of valid)assert.doesNotThrow(()=>validateCommand({...base,...value},current));
 for(const value of [{kind:'spellbook-query',classIndex:8,level:0,metamagic:0},{kind:'spellbook-query',classIndex:0,level:10,metamagic:0},{kind:'spellbook-query',classIndex:0,level:0,metamagic:3},{kind:'book-activate',viewId:2,entryId:-1},{kind:'quickbar-assign',viewId:2,entryId:0,index:36},{kind:'quickbar-move',quickbarId:4,sourceIndex:36,index:0}])assert.throws(()=>validateCommand({...base,...value},current));
});

test('native merchant requests accept scoped item handles and bounded categories/pages, not direct item IDs or unknown operations',()=>{
 const current={connection:2,areaId:7,generation:1};
 for(const row of[{operation:'close'},{operation:'buy',entryId:0},{operation:'sell',entryId:4},{operation:'identify',entryId:4},{operation:'panel',panel:4},{operation:'page',page:255}])assert.doesNotThrow(()=>validateCommand({...current,kind:'inventory-store',viewId:1,...row},current));
 for(const row of[{operation:'buy',itemId:3},{operation:'sell',entryId:-1},{operation:'panel',panel:5},{operation:'page',page:256},{operation:'open'}])assert.throws(()=>validateCommand({...current,kind:'inventory-store',viewId:1,...row},current));
 assert.throws(()=>validateCommand({...current,connection:1,kind:'inventory-store',viewId:1,operation:'close'},current));
});

test('character record commands permit only known pages and scoped bounded shortcut handles',()=>{const current={connection:2,areaId:7,generation:1};for(const row of[{kind:'sheet-open',page:0},{kind:'sheet-page',viewId:1,page:2},{kind:'sheet-close'},{kind:'sheet-assign',viewId:1,entryId:0,index:35}])assert.doesNotThrow(()=>validateCommand({...current,...row},current));for(const row of[{kind:'sheet-open',page:-1},{kind:'sheet-page',viewId:1,page:3},{kind:'sheet-assign',viewId:1,entryId:0,index:36},{kind:'sheet-assign',viewId:1,binding:{type:4,intParam:0},index:0}])assert.throws(()=>validateCommand({...current,...row},current));});

test('native level-up accepts bounded private page/control handles and text batches, never direct proposals',()=>{const current={connection:2,areaId:7,generation:1};for(const r of[{kind:'level-open'},{kind:'level-cancel'},{kind:'level-page',viewId:1,step:6,texts:[]},{kind:'level-control',viewId:1,controlId:0,value:true},{kind:'level-submit',viewId:1}])assert.doesNotThrow(()=>validateCommand({...current,...r},current));for(const r of[{kind:'level-page',viewId:1,step:7},{kind:'level-control',viewId:1,controlId:-1},{kind:'level-control',viewId:1,controlId:0,texts:[{controlId:0,value:'x'.repeat(129)}]},{kind:'level-submit',viewId:-1}])assert.throws(()=>validateCommand({...current,...r},current));});

test('NUI is connection scoped during area transitions and rejects forged handles before dispatch',()=>{const c={connection:4};assert.doesNotThrow(()=>validateCommand({kind:'nui-input',connection:4,windowId:3,operation:'event',controlId:8},c));for(const change of[{connection:3},{windowId:-1},{controlId:'8'},{operation:'execute'}])assert.throws(()=>validateCommand({kind:'nui-input',connection:4,windowId:3,operation:'event',controlId:8,...change},c));});
test('private dummy status is typed and world scoped, with bounded internal identity and token',()=>{
 const current={connection:2,areaId:7,generation:1},value={...current,kind:'client-dummy-status',id:0,token:1,transferId:3,stage:'ready'};
 assert.doesNotThrow(()=>validateCommand(value,current));
 for(const change of[{connection:1},{areaId:8},{generation:0},{id:-1},{id:0x7f000000},{token:0},{token:1.5},{transferId:-1},{stage:'other'}])assert.throws(()=>validateCommand({...value,...change},current));
});
test('world audio resource requests and driver observations retain current world ownership and typed private handles',()=>{
 const scope={connection:2,areaId:7,generation:1};
 const resource={...scope,kind:'world-audio-resource',resourceId:1,name:'sound-é',transferId:3};assert.doesNotThrow(()=>validateCommand(resource,scope));
 for(const change of[{connection:1},{areaId:8},{generation:0},{resourceId:0},{name:'../file'},{name:'c:sound'},{name:'x'.repeat(17)},{transferId:-1}])assert.throws(()=>validateCommand({...resource,...change},scope));
 const observed={...scope,kind:'world-audio-observed',soundId:1,resourceId:-1,effectId:0,stage:'stopped',transferId:3,driver:'WASAPI'};assert.doesNotThrow(()=>validateCommand(observed,scope));
 for(const change of[{soundId:0},{resourceId:-2},{effectId:-1},{stage:'unknown'},{driver:'x'.repeat(129)}])assert.throws(()=>validateCommand({...observed,...change},scope));
});
