'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const file=path.join(__dirname,'comparison.cjs');let text=fs.readFileSync(file,'utf8');
function change(before,after){assert.equal(text.split(before).length,2,before);text=text.replace(before,after);}
change("const fs=require('node:fs')","const U=require('./native-use-gates.cjs');\nconst fs=require('node:fs')");
change('const checkpoint=context.checkpoint;','U.events(value,mode);const semanticChecks=U.semanticChecks(value,role,mode);const checkpoint=context.checkpoint;');
change('checks:value.checks,checkpoint:','checks:semanticChecks,checkpoint:');
change('return{mode,success:true,semanticTranscript:a,errorTranscripts:transcripts,','return{mode,success:true,semanticTranscript:a,roleChecks:{baseline:baseline.checks,candidate:candidate.checks},roleActualUse:{baseline:baseline.actual_use,candidate:candidate.actual_use},errorTranscripts:transcripts,');
fs.writeFileSync(file,text);
console.log(JSON.stringify({sourceOnly:true,nativeStarts:0}));
