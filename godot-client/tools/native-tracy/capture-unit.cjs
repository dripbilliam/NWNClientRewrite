'use strict';
// No Tracy/native executable is launched. Test actual source parsers, not a
// second trace reader pretending to produce a native .tracy artifact.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),T=require('./trace-table.cjs'),P=require('./capture-plan.cjs');
let checks=0;function test(name,fn,reject=false){if(reject)assert.throws(fn,undefined,name);else fn();checks++;}
const E={cpuZones:[{name:'Main::iteration',minimumEvents:1},{name:'Smoke.Worker',minimumEvents:1}],minimumCPUThreads:2,minimumSpanSeconds:.001,maximumSpanSeconds:1,differentThreadZones:[['Main::iteration','Smoke.Worker']],maximumIncompleteEvents:1,gpu:{required:false}};
const header=T.headers.cpu.join('\t'),row=(name,start,duration,thread)=>[name,'file.cpp','1',start,duration,thread,''].join('\t');const data=[header,row('Main::iteration','0','1000000','9007199254740993'),row('Smoke.Worker','100','2000','2')].join('\n')+'\n';
test('completed CPU zones +exact64bit thread IDs',()=>{const v=T.cpuProof(data,E);assert.equal(v.completedEvents,2);assert(v.threadIds.includes('9007199254740993'));});
test('single thread cannot prove worker',()=>T.cpuProof(data.replaceAll('\t2\t','\t9007199254740993\t'),E),true);
test('wrong exact schema',()=>T.cpuProof(data.replace('exec_time_ns','milliseconds'),E),true);
test('missing actual required zone',()=>T.cpuProof(data.replace('Smoke.Worker','Unrelated'),E),true);
test('truncated/corrupted TSV',()=>T.cpuProof(data+'bad\tline\n',E),true);
test('unknown tab field not silently combined',()=>T.cpuProof(data.replace('Main::iteration','Main\titeration'),E),true);
test('unbounded duration rejected',()=>T.cpuProof(data.replace('1000000','2000000000'),E),true);
test('short capture rejected',()=>T.cpuProof(data.replace('1000000','1000'),E),true);
test('open event preserved separately',()=>{const v=T.cpuProof(data+row('Open','1000','-1001','2')+'\n',E);assert.equal(v.incompleteEvents,1);assert.equal(v.completedEvents,2);});
test('too many open events rejected',()=>T.cpuProof(data+row('Open','1000','-1001','2')+'\n'+row('Open2','1000','-1001','2')+'\n',E),true);
test('negative not completed required zone',()=>T.cpuProof(data.replace('2000','-2000'),E),true);
const gpu=T.headers.gpu.join('\t')+'\n';test('headless empty GPU explicit supported',()=>assert.equal(T.gpuProof(gpu,{required:false}).completedEvents,0));
test('CPU zones do not substitute GPU',()=>T.gpuProof(gpu,{required:true,minimumEvents:1}),true);
test('actual GPU event positive',()=>assert.equal(T.gpuProof(gpu+'GPU.Frame\tfile.cpp\t100\t5000\n',{required:true,zones:['GPU.Frame']}).completedEvents,1));
test('GPU wrong zone rejected',()=>T.gpuProof(gpu+'Other\tfile.cpp\t100\t5000\n',{required:true,zones:['GPU.Frame']}),true);
const summary=T.headers.summary.join('\t')+'\n'+['Main::iteration','file.cpp','1','1000000','50','1','1000000','1000000','1000000','0'].join('\t')+'\n'+['Smoke.Worker','file.cpp','1','2000','1','1','2000','2000','2000','0'].join('\t')+'\n';test('summary required actual counts',()=>assert.equal(T.summaryProof(summary,E).rows,2));
test('aggregate missing actual zone',()=>T.summaryProof(summary.replace('Smoke.Worker','Other'),E),true);
test('finite bounded expectations',()=>P.expectations({...E,minimumSpanSeconds:.01},1));test('missing GPU policy',()=>P.expectations({...E,gpu:{}},1),true);
test('invalid duration argument',()=>P.number(0,1,60,'seconds'),true);test('duplicate CLI rejected',()=>P.args(['--seconds=1','--seconds=2']),true);
test('actual official pinned local source/tools provenance',()=>{const v=P.toolchain();assert.equal(v.version,'0.13.0');assert.equal(v.protocol,76);});
const project=path.resolve(__dirname,'../..'),sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),out=path.join(project,'.cache/native-tracy/capture-source-check-a');fs.mkdirSync(out,{recursive:true});const sourceNames=['capture-plan.cjs','capture-run.ps1','trace-verify.cjs','trace-table.cjs','capture-unit.cjs','README-capture.txt'];const receipt={version:1,kind:'private-tracy-capture-source-check',success:true,checkedUtc:new Date().toISOString(),checks,sourceFiles:sourceNames.map(name=>({file:path.join(__dirname,name),sha256:sha(path.join(__dirname,name))})),nativeStarts:0,compilerStarts:0,downloads:0,tracyToolExecutions:0,scope:'Pure-JS actual TSV/parser/provenance checks only. No real .tracy artifact, capture handshake, export tool execution, PS parse or engine build acceptance yet.'};const file=path.join(out,'receipt.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),checks,tracyToolExecutions:0}));
