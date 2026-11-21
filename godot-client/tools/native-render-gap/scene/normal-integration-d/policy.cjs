'use strict';
// Explicit candidate parameters. E-C and Ob3 remain deliberately unselected;
// a reviewed final policy can replace these values in a NEW private stage.
module.exports=Object.freeze({
 version:1,
 expectedMainSourceSha256:'4553daad7d614e5d9f6e353be56df6356aa717d9c220c491e5c9af6e103a3e12',
 baselineSelection:'.cache/native-presentation-parity/production-replay/render-gap-resident-legacy-v7-c/production-selection.json',
 engine:{choice:'installed-v7',buildKind:'scons-engine-build',file:'.tools/native-core/Godot_native_core_v7_win64.exe',sha256:'75bc654d66aa249787ec166980a813e69f3081d98c8453fe23aeff2b07779ca6',bytes:90957312,runtimeRelative:'.tools/native-core/Godot_native_core_d_win64.exe',proofRelative:'.tools/native-core/accepted-core-d.json',buildReceipt:'.cache/native-render-gap/engine/build-1794142557441/receipt.json',sourceManifest:'.cache/native-render-gap/engine/build-1794142557441/source-manifest.json'},
 nativeKernel:{choice:'combined-b',stage:'.cache/native-render-gap/particles/combined-b',sha256:'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d',functionalReceipt:'.cache/native-render-gap/particles/combined-b/combined-oracles-a/receipt.json',functionalReceiptSha256:'43c1518421dff58f7653cba80ea7a3447f8c5d905099217aa26298551a054957'},
 flags:['--particle-scene-boundary=native','--particle-scene-direct=pod','--particle-setup-boundary=bound','--particle-hot-parameters=bound','--visibility-chain-cache=epochs','--light-input-read=typed','--light-input-proof=segments','--light-pair-layer-repair=exact','--light-pair-filter=consumers','--pair-record-reuse=exact','--rig-skin-publisher=native','--skeleton-force-pass=once','--particle-resident-text=borrow','--particle-empty-clips=skip'],
 receipts:[
  '.cache/native-render-gap/particles/resident-text-b/focused-v7-a/receipt.json',
  '.cache/native-render-gap/particles/empty-clips-b/focused-v7-a/receipt.json',
  '.cache/native-render-gap/particles/combined-b/combined-oracles-a/receipt.json',
  '.cache/native-render-gap/particles/combined-b/review-a.json',
  '.cache/native-render-gap/promotions/resource-cache-a/receipt.json',
  '.cache/native-render-gap/scene/resource-cache-functional-a/acceptance.json'
 ],
 deferredChoices:{engineEC:'not selected; waiting on matched FPS',nativeOb3:'not selected; waiting on matched FPS'},
 unselectedEngineEC:{choice:'manual-light-c',buildKind:'private-manual-light-module-engine',file:'.cache/native-render-gap/scene/light-member-build-c-a/candidate/godot.windows.template_release.x86_64.exe',sha256:'10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13',bytes:90973184,runtimeRelative:'.tools/native-core/Godot_native_core_d_win64.exe',proofRelative:'.tools/native-core/accepted-core-d.json',buildReceipt:'.cache/native-render-gap/scene/light-member-build-c-a/candidate/receipt.json',sourceManifest:'.cache/native-render-gap/scene/light-member-build-c-a/candidate/source-manifest.json',manualBuild:'.cache/native-render-gap/scene/light-member-build-c-a/candidate/manual-build.json',sourcePersistenceRelative:'tools/accepted-engine-source/light-input-c',functionalReceipt:'.cache/native-render-gap/scene/light-member-acceptance-c-a/acceptance.json',functionalReceiptSha256:'65461aaaea4902d78dd5ab4c0a89600fd0add87e6534e7feaa8df19c18f5afc4'},
 scope:'Private normal integration D parameter plan; underlying accepted combined-b components only. Current explicit normal/isolated/profile policies preserved. Normal-route acceptance and promotion remain separate.'
});
