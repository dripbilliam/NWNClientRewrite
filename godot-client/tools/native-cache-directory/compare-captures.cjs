'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),base=path.join(root,'.cache/native-tracy/arelith-review-a'),out=path.join(root,'.cache/native-tracy/arelith-review-cache-a');
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex'),read=f=>JSON.parse(fs.readFileSync(f,'utf8').replace(/^\uFEFF/,''));
function table(file){const lines=fs.readFileSync(file,'utf8').trim().split(/\r?\n/);assert.equal(lines.shift(),'name,src_file,src_line,total_ns,counts');return lines.map(line=>{const a=line.split(','),calls=Number(a.pop()),totalNs=Number(a.pop()),sourceLine=Number(a.pop()),sourceFile=a.pop();assert(Number.isSafeInteger(calls)&&calls>0&&Number.isSafeInteger(totalNs)&&totalNs>=0);return{name:a.join(','),sourceFile,sourceLine,calls,totalNs,meanMs:totalNs/calls/1e6};});}
const oldSelf=table(path.join(base,'whole-self.csv')),newSelf=table(path.join(out,'whole-self.csv')),oldInclusive=table(path.join(base,'whole-inclusive.csv')),newInclusive=table(path.join(out,'whole-inclusive.csv'));
const file='res://systems/native_data/prepared_cache.gd';
function one(rows,name){const found=rows.filter(x=>x.sourceFile===file&&x.name===name);assert.equal(found.length,1);return found[0];}
const oldConfigure=one(oldInclusive,'configure'),newConfigure=one(newInclusive,'configure'),oldRecursive=one(oldSelf,'make_dir_recursive_absolute'),newExists=one(newSelf,'dir_exists_absolute');
assert(!newSelf.some(x=>x.sourceFile===file&&(x.name==='make_dir_recursive_absolute'||x.name==='create_directory')));
const logFile=path.join(root,'.cache/native-tracy/manual-cache-a-log-comparison-a/receipt.json'),logs=read(logFile);assert.equal(logs.success,true);
const files=['whole-self.csv','whole-inclusive.csv'].flatMap(name=>[path.join(base,name),path.join(out,name)]).concat([path.join(out,'session.tracy'),logFile]);
const proof={version:1,success:true,createdUtc:new Date().toISOString(),inputs:files.map(file=>({file,sha256:sha(file),bytes:fs.statSync(file).size})),source:{file:__filename,sha256:sha(__filename)},rows:{oldSelf:oldSelf.length,newSelf:newSelf.length},
 cache:{oldConfigure,newConfigure,oldRecursive,newExists,preparedCacheRecursiveCallsAfter:0,observedMeanConfigureReductionPercent:100*(1-newConfigure.meanMs/oldConfigure.meanMs),observedMeanOperationReductionPercent:100*(1-newExists.meanMs/oldRecursive.meanMs)},
 optionalWriter:logs.optionalWriterComparison,comparability:logs.comparability,remainingFindings:logs.findings,
 limitations:['Whole-capture named-zone averages span threads, menu/loading/gameplay and different route durations. Self spans include IO/preemption/tracing overhead.','Configure is inclusive of its directory operation; do not add parent and child totals.','Same areas were visited in reverse order. There are no strict matched focused/camera/motion/population windows, so no causal FPS gain is reported.','Actual detailed profiling was on in both runs. No additional FPS run, compiler, native exporter or second large trace load was started.'],
 scope:'Actual stopped GUI capture and empty-filter/range-off Statistics exports compared with the retained original, plus closed native profile reports. The large saved file is hashed but not reopened by a second native reader.'};
fs.writeFileSync(path.join(out,'comparison.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,cacheConfigureMeanMsBefore:oldConfigure.meanMs,cacheConfigureMeanMsAfter:newConfigure.meanMs,reductionPercent:proof.cache.observedMeanConfigureReductionPercent,recursiveCallsAfter:0,writer:proof.optionalWriter,matchedFPSpairs:proof.comparability.eligibleStrictPairs.length},null,2));
