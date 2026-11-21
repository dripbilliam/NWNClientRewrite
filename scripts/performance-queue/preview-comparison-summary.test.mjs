import test from 'node:test';
import assert from 'node:assert/strict';
import {summarizePreviewComparison} from './preview-comparison-summary.mjs';
import {previewComparisonModes as modes} from './preview-comparison-transform.mjs';
function fixture(){return modes.map((omit,pass)=>({pass,omitPreviews:omit,resRef:pass%2?'area_b':'area_a',loadMs:omit?8000:10000,movingActors:20,
  previewAudit:{omit,rootPresent:true,previewChecked:false,persistentModelPreparation:false,mainBatches:false,matrixSubtrees:false,failedEmitters:0,emitters:2,nodes:omit?200:266,previews:omit?0:2,previewSprites:omit?0:64},
  frames:{dropped:0,rows:Array.from({length:240},(_,i)=>({at:i,gapMs:omit?20:25}))},
  samples:[{scene:{objects:120,controlled:{rendered:true}},shadowBudget:{native:{maximum:1}},frame:{viewport:{bufferWidth:3440,bufferHeight:1369,pixelRatio:1},totalMs:25,renderMs:10,cameraAndShadowsMs:5,particlesMs:5,draw:{calls:1500}}}]}));}
test('paired summary uses neighboring baseline means and excludes initial connection from comparisons',()=>{
  const rows=fixture();rows[0].loadMs=90000;const result=summarizePreviewComparison(rows);
  assert.equal(result.comparisons.length,4);assert.equal(result.medianFpsChangePercent,25);assert.ok(Math.abs(result.medianLoadChangePercent+20)<1e-9);assert.ok(result.comparisons.every(pair=>!pair.warnings.length));assert.equal(result.enableByDefault,false);assert.equal(result.goalComplete,false);
});
test('missing visits or mode reordering cannot produce a successful comparison',()=>{
  assert.throws(()=>summarizePreviewComparison(fixture().slice(1)),/twelve/);const rows=fixture();rows[4].omitPreviews=false;assert.throws(()=>summarizePreviewComparison(rows),/mode\/order/);
});
test('mismatched area, viewport or shadow configuration rejects comparison',()=>{
  for(const change of [rows=>rows[4].resRef='another_area',rows=>rows[4].samples[0].frame.viewport.bufferWidth=1424,rows=>rows[4].samples[0].shadowBudget.native.maximum=3]){const rows=fixture();change(rows);assert.throws(()=>summarizePreviewComparison(rows),/different areas|render size|shadow setting/);}
});
test('truncated samples, absent preview overhead or failed real emitters reject comparison',()=>{
  for(const change of [rows=>rows[4].frames.dropped=1,rows=>rows[2].previewAudit.previewSprites=0,rows=>rows[4].previewAudit.failedEmitters=1]){const rows=fixture();change(rows);assert.throws(()=>summarizePreviewComparison(rows),/observation|opt-out|emitters/);}
});
test('native scene population differences remain explicit quality warnings',()=>{
  const rows=fixture();rows[4].samples[0].scene.objects++;const result=summarizePreviewComparison(rows);assert.ok(result.comparisons[0].warnings.some(warning=>warning.includes('objects')));assert.equal(result.enableByDefault,false);
});
test('baseline drift is reported instead of silently presenting a noisy gain',()=>{
  const rows=fixture();rows[6].frames.rows.forEach(row=>row.gapMs=40);const result=summarizePreviewComparison(rows);assert.ok(result.comparisons[0].warnings.some(warning=>warning.includes('5%')));
});
