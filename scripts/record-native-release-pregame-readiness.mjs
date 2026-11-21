// Immutable diagnostic summarizer. No engine, source mutation, cache extraction or key access.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {workspace,project,parityRoot,record} from './native-release-functional-lib.mjs';
import {json} from './native-startup-experiment-lib.mjs';

const base=path.join(parityRoot,'release-functional-v1'),directory=path.join(base,'readiness-observation-root-approved-v1');
const proofFile=path.join(directory,'runner.json'),proof=JSON.parse(fs.readFileSync(proofFile));
assert.equal(proof.diagnosticCompleted,true);assert.equal(proof.baselineAccepted,false);assert.equal(proof.baselineReproduced,true);
assert.deepEqual(proof.changedInputs,[]);assert.deepEqual(proof.changedCopied,[]);assert.equal(proof.cleanEngine,true);
const observed=proof.readiness,jobs=observed.completions;
assert.equal(observed.completionOverflow,false);assert.equal(observed.layoutReady,true);assert.equal(observed.visibleInTree,true);assert.equal(observed.pendingJobs,0);assert.equal(observed.browserFailure,'');
const range=values=>({min:Math.min(...values),max:Math.max(...values)});
const sourceFiles=['systems/server_browser.gd','systems/native_server_browser.gd','tests/native_pregame_flow_test.gd'].map(file=>record(path.join(base,'workspace/godot-client',file)));
const evidenceFiles=['runner.json','result.json','result.json.observation.json','result.json.readiness.json','stdout.log','stderr.log','engine.log'].map(file=>record(path.join(directory,file)));
const report={
 success:true,scope:'Completed bounded editor-only readiness diagnosis. Original baseline is still rejected; no functional release, original-pixel or user responsiveness acceptance.',
 sourceRevision:proof.sourceRevision,sourceFiles,evidenceFiles,
 baseline:{accepted:false,originalFourthAssertionUnchanged:true,originalInputsAndWaitsUnchanged:true,observationalPostFailureCeilingMs:5000,failedAssertion:'Physical Internet action reaches native list using an authored received view'},
 timings:{samples:1,internetIntentToLayoutReadyMs:observed.internetToReadyMs,internetIntentToVisibleMs:observed.internetToVisibleMs,sourcePreparedBeginToBrowserReadyMs:observed.configureToReadyMs,entireSourcePreparedCallMs:(observed.configureEndUsec-observed.configureBeginUsec)/1000,postAssertionObservedFrames:observed.postAssertionFrames,readinessFailure:null},
 resources:{completedJobs:jobs.length,models:observed.models,requestedModels:observed.requestedModels,sources:observed.sources,finalPendingJobs:observed.pendingJobs,finalQueued:observed.assetsPending,finalRunning:observed.assetsRunning,readMs:range(jobs.map(row=>row.readMs)),workerMs:range(jobs.map(row=>row.workerMs)),serviceQueueMs:range(jobs.map(row=>row.phases.service_queue_ms)),workerQueueMs:range(jobs.map(row=>row.phases.worker_queue_ms)),errorCount:jobs.filter(row=>row.error).length},
 sourceContract:{configure:'ServerBrowser.configure_native creates NativeBrowser and immediately starts its GUI/model jobs; NativeBrowser.configure is already eager, before Internet open.',show:'ServerBrowser.refresh_entry requires NativeBrowser.layout_ready before source_visible.',fixture:'Initial await_flow claims browser preparation but waits Main/Multiplayer/Picker artwork only; Internet visibility assertion follows only two frames.'},
 recommendation:{parityFixture:'A NEW explicitly reviewed initial-readiness gate should also wait NativeBrowser.layout_ready under the existing15s ceiling, with original inputs and visibility assertion unchanged. This can isolate editor/release functional parity from background construction.',coldResponsiveness:'Keep this latency evidence separate.485ms cold resource delay remains an observed user-flow cost, not accepted responsive behavior. Further production preprepare/queue changes require their own source-backed scope.',preprepare:'Do not add a duplicate open-time preparation call: work already begins in configure. No production scheduling/worker/cache default change is justified from one controlled diagnostic.'},
 limitations:['One observer-bearing headless sample with controlled UI artwork/fonts, not a repeated performance benchmark.','The550.773ms sourcePrepared interval includes other frontend setup; it is not isolated NativeBrowser.configure time.','Later live source changes listed by the diagnostic are outside this fixed snapshot acceptance.','No release case ran; both earlier baseline rejections remain preserved.'],
 preservedRejections:['execution-root-approved-functional-v1/runner.json','execution-root-approved-functional-v2/runner.json','observation-root-approved-v1/runner.json'].map(file=>record(path.join(base,file))),
 productionChanges:0,assertionChanges:0,originalWaitChanges:0,packageRewrites:0,nativeBuilds:0,downloads:0,networkSessions:0,keyAccess:0,userProcessActions:0,gpuBenchmarks:0
};
const output=path.join(project,'reports/native-release-pregame-readiness-v1-receipt.json');json(output,report);
console.log(JSON.stringify({success:true,report:path.relative(workspace,output),sha256:record(output).sha256,baselineAccepted:false,timings:report.timings,resources:report.resources,engineLaunches:0}));
