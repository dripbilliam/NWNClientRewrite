'use strict';
// Pure source transforms. They do not select/start a process or touch settings.
const assert = require('node:assert/strict');
const path = require('node:path');
function one(source, before, after) {
 assert.equal(source.split(before).length - 1, 1, 'Private Tracy source seam changed: ' + before.slice(0, 90));
 return source.replace(before, after);
}
function runtimeSource(original, descriptor, descriptorSha256, config) {
 let source = original;
 source = one(source, 'const relative=".tools/native-core/Godot_native_core_d_win64.exe";', 'const relative=' + JSON.stringify(config.engineRelative) + ';');
 source = one(source, 'const sha256="10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13",bytes=90973184;', 'const sha256=' + JSON.stringify(descriptor.engineSha256) + ',bytes=' + descriptor.engineBytes + ';');
 source = one(source, 'const proofRelative=".tools/native-core/accepted-core-d.json",proofSha256="5b76f260b5c65f18fcaa332ce806f2843325e08ec218f751652dd545689c579e";', 'const proofRelative=' + JSON.stringify(config.descriptorRelative) + ',proofSha256=' + JSON.stringify(descriptorSha256) + ';');
 source = one(source, 'const nativeSha256="485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d";', 'const nativeSha256=' + JSON.stringify(descriptor.nativeKernelSha256) + ';');
 source = one(source, 'policy:enabled?"accepted-normal-combined-d":"conservative-or-isolated"', 'policy:enabled?"private-tracy-diagnostic":"conservative-or-isolated"');
 source = one(source, "kind:'verified-native',executable", "kind:'private-tracy-diagnostic',executable");
 source = one(source, "revision:'verified-native-normal-bundle-d'", "revision:'private-tracy-source-equivalent-d'");
 source = one(source, "verification:'Exact engine/native SHA256, engine byte count and accepted component proof'", "verification:'Exact private diagnostic engine/DLL SHA256 and build receipts; no normal-performance acceptance'");
 source = one(source, "particleExtensionPolicy:'Exact accepted combined-b DLL plus corresponding native sources; conservative flag-absent branches retained'", "particleExtensionPolicy:'Accepted combined-b source plus engine-owned Tracy bridge/PDB build; explicit diagnostic DLL hash'");
 source += '\nconst diagnostic=' + JSON.stringify({ descriptorRelative: config.descriptorRelative, descriptorSha256, tracing: descriptor.tracing, acceptedReference: descriptor.acceptedReference, performanceAccepted: false }) + ';\n';
 source += `function decorateOptions(options){
  if(options.runtime!=='verified-native'||!options.renderCore?.enabled||!options.renderCore?.typed)throw Error('Private Tracy manual route requires the unchanged normal native/builtin preset');
  const wanted=${JSON.stringify(descriptor.fullFunctionalFlags)};
  if(JSON.stringify(options.renderCore.flags)!==JSON.stringify(wanted))throw Error('Private Tracy requires all16 accepted-D functional flags');
  options.renderCore={...options.renderCore,engineSha256:sha256,nativeKernelSha256:nativeSha256,policy:'private-tracy-diagnostic',diagnosticTrace:diagnostic,scope:'Normal-D functional flags with a separately identified Tracy engine/DLL. Diagnostic capture only; no FPS acceptance.'};
  return options;
 }
 module.exports.decorateOptions=decorateOptions;
 module.exports.diagnostic=diagnostic;
 module.exports.recordNativeSpawn=function(child){
  require('node:fs').writeFileSync(${JSON.stringify(path.join(config.out, 'native-start.json'))},JSON.stringify({version:1,pid:child.pid,hostPid:process.pid,run:${JSON.stringify(config.run)},engine:${JSON.stringify(config.engineLaunch)},engineSha256:sha256,nativeKernelSha256:nativeSha256,diagnosticOnly:true,performanceAccepted:false,scope:'Owned child PID from genuine selected diagnostic runtime. Exact FILETIME and loaded-DLL identity still require independent watcher proof.'})+${JSON.stringify('\n')},{flag:'wx'});
 };
`;
 return source;
}
function hostSource(original, config) {
 let source = original;
 source = one(source, "const performanceOptions=clientFlags.resolvePerformanceOptions(process.argv.slice(2),{env:process.env});", 'const privateTracyRuntime=require(' + JSON.stringify(path.join(config.view, 'tools/native-performance-runtime.cjs')) + ');\nconst performanceOptions=privateTracyRuntime.decorateOptions(clientFlags.resolvePerformanceOptions(process.argv.slice(2),{env:process.env}));');
 source = one(source, "const runtimeSelection=(await require('./native-performance-runtime.cjs').selectPerformanceRuntime(project,performanceOptions.runtime))??await require('./native-engine-runtime.cjs').selectNativeRuntime(project,engineRuntime,enginePackage);", 'const runtimeSelection=await privateTracyRuntime.selectPerformanceRuntime(' + JSON.stringify(config.view) + ',performanceOptions.runtime);');
 source = one(source, "...(engineRuntime==='editor'?['--path',project]:[])", "...(engineRuntime==='editor'?['--path'," + JSON.stringify(config.view) + ']:[])');
 source = one(source, 'featureManifest.createStartupManifest({run,project,runtime:runtimeSelection', 'featureManifest.createStartupManifest({run,project:' + JSON.stringify(config.view) + ',runtime:runtimeSelection');
 source = one(source, 'nativeArgs.unshift(...performanceOptions.engineArguments);', 'nativeArgs.push(' + ['render-preferences', 'menu-layout', 'lobby-preferences'].map((name, index) => JSON.stringify('--' + name + '=' + path.join(config.userdata, ['native-render-preferences.cfg', 'native-menu-layout.cfg', 'native-lobby-preferences.cfg'][index]))).join(',') + ');\n nativeArgs.unshift(...performanceOptions.engineArguments);');
 const spawn = "native=spawn(launch,launchArgs,{cwd:runtimeSelection.directory,windowsHide:true,env:{...process.env,...renderConfiguration.environment},stdio:['ignore','pipe','pipe']});";
 source = one(source, spawn, spawn.replace('...renderConfiguration.environment}', '...renderConfiguration.environment,APPDATA:' + JSON.stringify(config.appdata) + ',LOCALAPPDATA:' + JSON.stringify(config.localappdata) + '}') + '\n privateTracyRuntime.recordNativeSpawn(native);');
 return source;
}
function manualArguments(run) {
 assert(/^[a-z0-9-]+$/.test(run));
 return ['--run=' + run, '--public-servers', '--detailed-profiling=off'];
}
module.exports = { one, runtimeSource, hostSource, manualArguments };
