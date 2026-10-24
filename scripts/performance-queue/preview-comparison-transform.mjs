// Build-time QA transform only. Production never imports this module.
export const previewComparisonHooks = `
let qaOmitGameplayPreviews=false;
window.setGameplayPreviewsForTest=value=>{
  if(typeof value!=='boolean')throw Error('Preview comparison requires boolean');
  qaOmitGameplayPreviews=value;
};
window.gameplayPreviewAuditForTest=()=>{
  const root=networkPresentation?.root;
  const result={omit:qaOmitGameplayPreviews,previewChecked:previewEffectsEnabled.checked,
    persistentModelPreparation:usePersistentModelPreparation,mainBatches:rendererMainBatches.enabled,
    matrixSubtrees:prepareMatrixSubtrees,failedEmitters:modelParticles.snapshot().filter(entry=>entry.failed).length,
    rootPresent:Boolean(root),nodes:0,previews:0,previewSprites:0,emitters:0};
  root?.traverse(node=>{result.nodes++;if(node.userData.emitterPreview)result.previews++;
    if(node.userData.emitterParticle)result.previewSprites++;if(node.userData.mdlEmitter)result.emitters++;});
  return result;
};
`;

export function transformPreviewComparison(mainSource) {
  if(mainSource.includes('qaOmitGameplayPreviews')||mainSource.includes('setGameplayPreviewsForTest'))throw Error('Preview comparison transform already present');
  const edits=[
    ['network-instance','buildObject(asset.model,asset.textures,asset.override,{shareGeometry:true,managedMatrices:true})',
      'buildObject(asset.model,asset.textures,asset.override,{previews:!qaOmitGameplayPreviews,shareGeometry:true,managedMatrices:true})'],
    ['gameplay-standalone','const root=buildObject(asset.model,asset.textures);',
      'const root=buildObject(asset.model,asset.textures,null,{previews:!qaOmitGameplayPreviews});'],
  ];
  let code=mainSource;
  for(const [name,old,replacement]of edits) {
    if(code.split(old).length!==2)throw Error('Preview comparison call-site drift: '+name);
    code=code.replace(old,replacement);
  }
  // Appending preserves import and declaration order. Hooks are called only
  // after the complete module has initialized. Normal builders stay intact.
  return {code:code+'\n'+previewComparisonHooks,edits:edits.map(([name])=>name)};
}

export const previewComparisonModes=Object.freeze([false,false,false,false,true,true,false,false,true,true,false,false]);
export const previewComparisonPairs=Object.freeze([[2,4,6],[3,5,7],[6,8,10],[7,9,11]].map(pair=>Object.freeze(pair)));
