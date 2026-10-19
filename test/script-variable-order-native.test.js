import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeVariableOrder,nativeVariableByteHash} from '../src/script_variable_order.js';
import {ScriptVariableTable} from '../src/script_variables.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-variable-order-observations.json',import.meta.url)));
test('variable byte hashing matches original code over all short tails and long blocks',()=>{
 assert.equal(data.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of data.hashes)assert.equal(nativeVariableByteHash(Uint8Array.from(row.bytes)),row.value,`length ${row.bytes.length}`);
});
test('native variable insertion/find and captured unlink match physical order through rehashes',()=>{
 for(const scenario of data.scenarios){
  const order=new NativeVariableOrder();
  for(const result of scenario.results){
   const [kind,name]=result.operation;let matched=order.find(name);
   if(kind==='set'&&matched===undefined)matched=order.insert(name);else if(kind==='delete'&&matched!==undefined)order.remove(name);
   assert.equal(matched??null,result.match,JSON.stringify(result.operation));assert.deepEqual(order.names,result.order);assert.equal(order.bucketCount,result.buckets);
  }
 }
});
test('canonical local-variable table retains native order during mutation and item-copy assignment',()=>{
 for(const scenario of data.scenarios){const table=new ScriptVariableTable();for(const result of scenario.results){
  const [kind,name]=result.operation;if(kind==='set')table.setInt(name,1);else if(kind==='delete')table.deleteIndex(name,'int');
  assert.deepEqual([...table.nativeRows()].map(([name])=>name),result.order);
  if(kind!=='delete')assert.equal(table.getInt(name),result.match===null?0:1);
 }const copy=new ScriptVariableTable();copy.copyFrom(table);assert.deepEqual([...copy.nativeRows()],[...table.nativeRows()]);assert.equal(copy.nativeOrder.bucketCount,table.nativeOrder.bucketCount);}
});
