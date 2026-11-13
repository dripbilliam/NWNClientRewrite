import {test} from 'node:test';
import assert from 'node:assert/strict';
import {originalCadence,functionalArguments} from '../run-native-release-functional-v2.mjs';

const stage={copy:'C:/private/source',fixture:'C:/private/data'},entry={script:'tests/native_pregame_flow_test.gd',args:[]};
test('both arms preserve original Pregame60fps runner cadence without changing fixture arguments',()=>{
 for(const arm of ['editor','release']){
  const result=functionalArguments(arm,entry,stage,'C:/private/evidence','C:/install');
  assert.deepEqual(result.args.slice(0,3),['--headless','--max-fps','60']);
  assert.ok(result.args.includes('--entity-api-rest=false'));assert.ok(result.args.includes('--fixture=C:/private/data'));
  assert.ok(result.args.some(arg=>arg.startsWith('--report=')));
 }
});
test('release keeps canonical bootstrap entry and no disabled path switches',()=>{
 const {args}=functionalArguments('release',entry,stage,'C:/private/evidence','C:/install');
 assert.ok(args.includes('--release-entry=res://tests/native_pregame_flow_test.gd'));assert.ok(!args.includes('--path'));assert.ok(!args.includes('--main-pack'));assert.ok(!args.includes('--script'));
 const editor=functionalArguments('editor',entry,stage,'C:/private/evidence','C:/install').args;assert.ok(editor.includes('--script'));assert.ok(editor.includes('res://tests/native_pregame_flow_test.gd'));
});
test('cadence correction never mutates original argument array or silently overrides another cap',()=>{
 const original=['--headless','--log-file','log','--','--report=a'];const before=original.slice();const corrected=originalCadence(original);
 assert.deepEqual(original,before);assert.deepEqual(corrected.slice(3),original.slice(1));
 assert.throws(()=>originalCadence(['--headless','--max-fps','30']));
});
