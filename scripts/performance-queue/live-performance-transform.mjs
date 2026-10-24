import {transformPreviewComparison} from './preview-comparison-transform.mjs';
export function transformLivePerformance(mainSource) {
  let code=transformPreviewComparison(mainSource).code;
  const replacements=[
    ['const prepareMatrixSubtrees=','let prepareMatrixSubtrees='],
    ["import.meta.env.VITE_FRAME_BUDGET_LOADING==='1'",'qaPerformanceFlags.frameBudget'],
    ["cachedRootMatrices:import.meta.env.VITE_CACHED_ROOT_MATRICES==='1'",'cachedRootMatrices:qaPerformanceFlags.cachedRoots'],
    ['presentation.texturePreparation=frameWork?', 'presentation.qaAreaSettings={...qaPerformanceFlags};presentation.texturePreparation=frameWork?'],
    ["if(!document.hidden&&(timing.totalMs>250", "qaStageProfiler?.finishFrame();qaPerformanceDiagnostics?.record(frameEnded,timing,!rendererWarmupCount);\n  if(!document.hidden&&(timing.totalMs>250"],
  ];
  for(const [before,after]of replacements){if(code.split(before).length!==2)throw Error('Live diagnostic call-site drift: '+before);code=code.replace(before,after);}
  code="import {installLivePerformanceDiagnostics} from '/scripts/performance-candidates/live-performance-diagnostics.mjs';\nimport {installStageProfiler} from '/scripts/performance-candidates/stage-profiler.mjs';\nimport {performanceCandidateFlags,validatePerformanceCandidateFlags} from '/scripts/performance-candidates/live-performance-profile.mjs';\nlet qaPerformanceDiagnostics=null,qaStageProfiler=null;let qaPerformanceFlags=performanceCandidateFlags();\n"+code;
  code+=`
void import('/scripts/performance-candidates/scene-capture-controls.mjs').then(({installSceneCaptureControls})=>installSceneCaptureControls({root:viewport,bridge:window.nativeNetwork,
 view:()=>networkFrontend?.id&&networkFrontend.phase==='playing'?{sessionId:networkFrontend.id,view:{areaId:networkFrontend.world.areaId,position:camera.position.toArray(),quaternion:camera.quaternion.toArray(),target:controls.target.toArray(),fov:camera.fov,near:camera.near,far:camera.far,buffer:[canvas.width,canvas.height],flags:{...qaPerformanceFlags},shadowLights:rendererShadowBudget.maximum,stats:{objects:networkPresentation?.objects.size??0,models:networkPresentation?.instances.size??0,particleEmitters:modelParticles.entries.size,particleActive:[...modelParticles.entries.values()].reduce((n,e)=>n+(e.e?.active188.records.length??0),0),particleFailed:[...modelParticles.entries.values()].filter(e=>e.failed).length,programs:renderer.info.programs?.length??0,geometries:renderer.info.memory.geometries,textures:renderer.info.memory.textures,draws:renderer.info.render.calls,shadowDraws:rendererShadowTraversal.snapshot()?.drawCalls??0}}}:null,
 report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)
}));
qaStageProfiler=installStageProfiler({particles:modelParticles,shadowTraversal:rendererShadowTraversal});
qaPerformanceDiagnostics=installLivePerformanceDiagnostics({root:viewport,
 apply:next=>{
  next=validatePerformanceCandidateFlags(next);
  if(next.staticBatches!==qaPerformanceFlags.staticBatches){rendererMainBatches.reset();rendererMainBatches.staticOnly=true;rendererMainBatches.palettes.minRepeatSize=1024;rendererMainBatches.palettes.maxBytes=256*1024*1024;rendererMainBatches.palettes.compressed=true;}
  rendererMainBatches.enabled=next.staticBatches;
  if(next.lightUniforms!==qaPerformanceFlags.lightUniforms)rendererLightUniforms.reset();rendererLightUniforms.enabled=next.lightUniforms;
  if(next.materialReuse!==qaPerformanceFlags.materialReuse)rendererMaterialReuse.reset();rendererMaterialReuse.enabled=next.materialReuse;
  rendererShadowTraversal.cache.shortCircuitVolatile=next.shadowInputs;
  setManagedMatrixReuse(next.managedMatrices);setScalarPoseTransfer(next.scalarPoses);
  prepareMatrixSubtrees=next.tileMatrices;setMatrixSubtreeReuse(next.tileMatrices);
  usePersistentModelPreparation=next.modelCache;canvas.dataset.persistentModelPreparation=String(next.modelCache);if(!next.modelCache)persistentModelSources.clear();
  window.setGameplayPreviewsForTest(next.omitPreviews);qaPerformanceFlags={...next};
 },
 readContext:()=>({phase:networkFrontend?.phase??'menu',areaId:networkPresentation?.area?.id??null,area:networkPresentation?.area?.resRef??null,areaSettings:networkPresentation?.qaAreaSettings??null,graphicsPending:Boolean(networkPresentation?.graphicsPending),renderBuffer:[canvas.width,canvas.height]}),
 readTelemetry:()=>{const read=(element,key)=>{try{return JSON.parse(element?.dataset?.[key]??'null');}catch{return null;}};return {performance:read(document.querySelector('#performance-debug'),'state'),frame:read(canvas,'frameTimings'),stages:qaStageProfiler?.snapshot(),shadowInputEarlyExit:rendererShadowTraversal.cache.shortCircuitVolatile,particleWorkers:read(canvas,'particleVertexWorkers'),particles:read(canvas,'modelParticles'),models:read(canvas,'rendererModelPreparation'),modelSources:read(canvas,'preparedModelSources'),geometry:read(canvas,'rendererModelGeometry'),workers:read(canvas,'resourceWorkers'),prefetch:read(canvas,'resourcePrefetch'),shadows:read(canvas,'rendererShadowBudget'),batches:read(canvas,'rendererMainBatches'),lightUniforms:read(canvas,'rendererLightUniforms'),materialReuse:read(canvas,'rendererMaterialReuse')};},
 report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)
});
networkFrontend.lobby?.showMain();qaPerformanceDiagnostics.hide();
`;
  return {code,edits:['preview-call-sites','live-candidate-controls','per-area-setting-identity','frame-and-resource-diagnostics']};
}
