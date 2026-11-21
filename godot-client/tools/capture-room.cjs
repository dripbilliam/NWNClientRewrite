// Reuse the offline-only capture delivery/security implementation, with exact
// in-memory extension points. No production source or live network is loaded.
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
const original=path.resolve(__dirname,'../../scripts/performance-queue/replay-scene.cjs'),helper=path.join(__dirname,'external-bundle.cjs');let code=fs.readFileSync(original,'utf8');
function replace(before,after){if(code.split(before).length!==2)throw Error('Offline export harness boundary changed');code=code.replace(before,after);}
replace("require('../../electron/application_build.cjs').resolveApplicationBuild(root,['--client-build='+arg('build')])","require("+JSON.stringify(helper)+").resolveGodotExporterBuild(root,arg('build'))");
replace("   report.final=await js('window.sceneReplayForTest.snapshot()');","   const godotReady=await js('window.sceneReplayForTest.snapshot()');if(godotReady.objects!==report.canonical.ids.length||godotReady.models===0||godotReady.pendingAssets||godotReady.graphicsPending)throw Error('Complete captured world required before Godot transfer');\n   report.godotBundle=await require("+JSON.stringify(helper)+").writeExternalGodotBundle(await js('window.sceneReplayForTest.godotExport()'));\n   report.final=await js('window.sceneReplayForTest.snapshot()');");
const child=new Module(original,module);child.filename=original;child.paths=Module._nodeModulePaths(path.dirname(original));child._compile(code,original);
