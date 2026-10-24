import {EMITTER_RUNTIME_FIELDS} from '../../src/mdl_emitter.js';

// Resource metadata only. Original payloads travel with the private external
// runtime bundle, never into authored project files or the gameplay registry.
function nodeRecord(root){
 if(!root)throw Error('Native animation node is invalid');
 const controllers78=Array.from(root.controllers78??[],row=>Object.fromEntries(['displacement0','columnsA','rows4','timeIndex6','valueIndex8'].map(key=>[key,row[key]])));
 if(controllers78.length!==root.controllerCount80)throw Error('Native controller count changed');
 return{id34:root.id34,flags98:root.flags98,controllers78,controllerCount80:controllers78.length,values88:Array.from(root.values88??[])};
}
function nodeTree(root,depth=0){
 if(!root||depth>=1000)throw Error('Native animation hierarchy is invalid');
 const children68=Array.from(root.children68??[],row=>nodeTree(row,depth+1));
 if(children68.length!==root.childCount70)throw Error('Native animation child count changed');
 return{...nodeRecord(root),children68,childCount70:children68.length};
}
export function exportNativeAnimation(model){
 if(!model.nativeRoot)return null;
 const indices=new Map(model.nodes.map((source,index)=>[source.nativeNode,index]));
 if(indices.size!==model.nodes.length||indices.has(undefined)||!indices.has(model.nativeRoot))throw Error('Native physical model binding is incomplete');
 const parts=model.nodes.map(source=>({type:source.type,properties:structuredClone(source.properties??{}),transparencyHint:Boolean(source.transparencyHint),node:nodeRecord(source.nativeNode),children:source.nativeNode.children68.map(child=>{if(!indices.has(child))throw Error('Native physical child is outside model');return indices.get(child);})}));
 const clips={};
 for(const clip of model.animations??[])clips[clip.name]=clip.nativeRoot&&!clip.inheritedFrom?{root:nodeTree(clip.nativeRoot)}:{unavailable:clip.inheritedFrom?'inherited animation scale provider pending':'native clip storage unavailable'};
 return{version:1,root:indices.get(model.nativeRoot),parts,clips,emitterFields:EMITTER_RUNTIME_FIELDS};
}
