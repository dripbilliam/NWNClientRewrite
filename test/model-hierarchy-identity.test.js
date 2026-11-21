import test from 'node:test';
import assert from 'node:assert/strict';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {buildUiModel} from '../src/native_ui_assets.js';
const node=(name,parentIndex,parent)=>({type:'dummy',name,parentIndex,parent,position:[0,0,0],orientation:[0,0,0,1]});
test('binary parent identity preserves duplicate parent/child names in world and UI hierarchies',()=>{
  const model={modelName:'duplicate',nodes:[node('head',-1,'NULL'),node('head',0,'head'),node('child',1,'head')]};
  const {root,nodeGroups}=createModelHierarchy(model);assert.equal(root.children.length,1);assert.equal(nodeGroups.get(model.nodes[1]).parent,nodeGroups.get(model.nodes[0]));assert.equal(nodeGroups.get(model.nodes[2]).parent,nodeGroups.get(model.nodes[1]));
  assert.notEqual(nodeGroups.get(model.nodes[0]),nodeGroups.get(model.nodes[1]));
  const ui=buildUiModel(model);assert.equal(ui.root.children.length,1);assert.equal(ui.root.children[0].children[0].children[0].name,'child');
});
test('actual hierarchy cycles fail explicitly while textual NULL remains a root sentinel',()=>{
  assert.throws(()=>createModelHierarchy({modelName:'cycle',nodes:[node('a',1,'b'),node('b',0,'a')]}),/parent cycle/);
  const rootNode=node('NULL',undefined,'NULL'),model={modelName:'root',nodes:[rootNode]};assert.equal(createModelHierarchy(model).root.children[0].name,'NULL');
});
