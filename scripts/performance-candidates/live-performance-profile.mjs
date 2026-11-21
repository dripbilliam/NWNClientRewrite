export const performanceCandidateDefinitions=Object.freeze([
  ['omitPreviews','Skip hidden editor particle previews',false],
  ['modelCache','Prepared model cache',true],
  ['managedMatrices','Reuse unchanged local matrices',false],
  ['scalarPoses','Scalar animation pose transfer',false],
  ['tileMatrices','Reuse static tile matrix subtrees',true],
  ['cachedRoots','Cache model root matrices',true],
  ['staticBatches','Batch compatible static textures',false],
  ['lightUniforms','Reuse unchanged light uniforms',false],
  ['materialReuse','Reuse unchanged material state',false],
  ['shadowInputs','Stop shadow cache scans for volatile maps',false],
  ['frameBudget','Spread loading work across frames',true],
].map(row=>Object.freeze(row)));
export function performanceCandidateFlags(profile='baseline') {
  if(!['baseline','candidates'].includes(profile))throw Error('Unknown performance profile');
  return Object.fromEntries(performanceCandidateDefinitions.map(([key])=>[key,profile==='candidates']));
}
export function validatePerformanceCandidateFlags(value) {
  if(!value||Object.keys(value).length!==performanceCandidateDefinitions.length)throw Error('Invalid performance settings');
  for(const [key]of performanceCandidateDefinitions)if(typeof value[key]!=='boolean')throw Error('Invalid performance flag '+key);
  return Object.fromEntries(performanceCandidateDefinitions.map(([key])=>[key,value[key]]));
}
export function summarizeCandidateFrames(rows) {
  if(!rows.length)return null;
  const sorted=rows.map(row=>row.gapMs).sort((a,b)=>a-b),total=sorted.reduce((a,b)=>a+b,0),average=key=>rows.reduce((sum,row)=>sum+row[key],0)/rows.length;
  return {frames:rows.length,fps:rows.length*1000/total,averageMs:total/rows.length,p95Ms:sorted[Math.ceil(sorted.length*.95)-1],maxMs:sorted.at(-1),hitchesOver50Ms:sorted.filter(value=>value>50).length,
    renderedFrames:rows.filter(row=>row.rendered).length,workMs:average('workMs'),renderMs:average('renderMs'),cameraMs:average('cameraMs'),particlesMs:average('particlesMs'),networkMs:average('networkMs')};
}
