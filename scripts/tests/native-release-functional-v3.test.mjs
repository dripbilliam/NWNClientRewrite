import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyFixtureOverlay} from '../run-native-release-functional-v3.mjs';
const pack=entries=>({entries:new Map(entries.map(([name,sha256])=>[name,{sha256}]))});
test('a new test fixture cannot silently change any existing source/bootstrap/native payload',()=>{
 const old=pack([['product.gd','one'],['__release_boot.gd','boot'],['native/a.gdextension','dll']]);
 const next=pack([['product.gd','one'],['__release_boot.gd','boot'],['native/a.gdextension','dll'],['tests/gate.gd','new']]);
 const allowed=[{relative:'tests/gate.gd',sha256:'new'}];assert.equal(verifyFixtureOverlay(old,next,allowed).commonPayloadsUnchanged,3);
 next.entries.set('product.gd',{sha256:'changed'});assert.throws(()=>verifyFixtureOverlay(old,next,allowed),/Existing canonical payload changed/);
});
test('unexpected additional payloads reject a supposedly test-only overlay',()=>{
 assert.throws(()=>verifyFixtureOverlay(pack([['a','same']]),pack([['a','same'],['other','extra']]),[]),/Unexpected additional pack payload/);
});
