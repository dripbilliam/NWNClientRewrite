import fs from 'node:fs/promises';import {createReferenceFixture} from './reference-fixture.mjs';
const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('Use an unused --output path');
const cases=[];
for(const flags of [0,3])for(const mode of ['bound-anchor','canonical-root-fallback']){
 const fixture=createReferenceFixture({flags});try{
  if(mode==='canonical-root-fallback')fixture.source.references.poses.setParent(fixture.first,fixture.target,'root',flags);
  const frames=[];let descriptor;
  for(let index=0;index<20;index++){
   const frame=fixture.update(index);descriptor??=frame.descriptor;
   frames.push({anchor:fixture.target.groups.get('target_anchor').matrixWorld.toArray(),pivot:fixture.targetWrapper.matrixWorld.toArray(),expected:frame.descriptor.referenceTarget.matrix,emitter:frame.descriptor.matrix,root:frame.descriptor.rootMatrix});
  }
  cases.push({flags,mode,descriptor,frames});
 }finally{fixture.close();}
}
const result={scope:'Authored model/reference transforms evaluated by the retained complete physical reference/attachment owners; no game assets',cases};await fs.writeFile(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,cases:cases.length,frames:cases.reduce((sum,row)=>sum+row.frames.length,0)}));
