import test from 'node:test';
import assert from 'node:assert/strict';
import {submitNativeDialogReply} from './native-dialog-input.mjs';
test('offered dialogue choice retains the ordinary validated server request',async()=>{
 const input={entryId:3,replyId:4},seen=[],ui=[];const session={replyDialog:async request=>{seen.push(request);return{sent:true}}};
 assert.deepEqual(await submitNativeDialogReply(session,input,value=>ui.push(value)),{sent:true});assert.deepEqual(seen,[input]);assert.deepEqual(ui,[]);
});
test('a server-closed dialogue dismisses its stale projection without sending another choice',async()=>{
 const ui=[],session={dialog:null,replyDialog:async()=>{throw Error('Native dialog reply is stale or unavailable')}};
 assert.deepEqual(await submitNativeDialogReply(session,{},value=>ui.push(value)),{sent:false,resynchronized:true});assert.deepEqual(ui,[{kind:'dialog-close'}]);
});
test('an advanced dialogue reprojects only current received entry/replies with isolated data',async()=>{
 const replies={kind:'dialog-replies',entryId:8,replies:[{id:9,text:{text:'Current offer'}}]},session={dialog:{kind:'dialog-entry',ownerId:7,text:{text:'Current'},replies},replyDialog:async()=>{throw Error('Native dialog reply is stale or unavailable')}},ui=[],before=structuredClone(session.dialog);
 await submitNativeDialogReply(session,{},value=>ui.push(value));assert.equal(ui[0].kind,'dialog-entry');assert.equal(ui[0].replies,undefined);assert.deepEqual(ui[1],replies);ui[1].replies[0].id=99;assert.deepEqual(session.dialog,before);
});
test('unrelated protocol errors remain errors',async()=>{
 await assert.rejects(submitNativeDialogReply({replyDialog:async()=>{throw Error('Connection retired')}},{},()=>{}),/Connection retired/);
});
