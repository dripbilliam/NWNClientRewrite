'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../..'),[label,outputLabel]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^[a-z0-9-]+$/.test(outputLabel??''))throw Error('Explicit experiment and fresh output label required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label),output=path.join(root,'cpu-'+outputLabel);if(fs.existsSync(output))throw Error('Existing evidence preserved');fs.mkdirSync(output);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),script='tools/native-particle-loop/cpu_benchmark.gd',bytes=fs.readFileSync(path.join(__dirname,'cpu_benchmark.gd'));
const manifests={};for(const variant of ['control','candidate']){const m=JSON.parse(fs.readFileSync(path.join(root,variant,'test-manifest.json')));const dest=path.join(m.project,script);if(fs.existsSync(dest)){if(hash(fs.readFileSync(dest))!==hash(bytes))throw Error('Existing CPU fixture differs');}else fs.writeFileSync(dest,bytes,{flag:'wx'});manifests[variant]=m;}
const rows=[];for(const [index,variant]of ['control','candidate','candidate','control','control','candidate','candidate','control'].entries()){
 const m=manifests[variant];for(const pin of m.pins)if(hash(fs.readFileSync(path.join(m.project,pin.relative)))!==pin.sha256)throw Error('Private stage differs: '+pin.relative);
 if(hash(fs.readFileSync(path.join(m.project,script)))!==hash(bytes)||hash(fs.readFileSync(m.engine.executable))!==m.engine.executableSha256)throw Error('Fixture/engine differs');
 const dir=path.join(output,index+'-'+variant);fs.mkdirSync(dir);const report=path.join(dir,'report.json'),log=path.join(dir,'engine.log');
 const child=spawnSync(m.engine.executable,['--headless','--path',m.project,'--script','res://'+script,'--log-file',log,'--','--report='+report],{cwd:m.project,windowsHide:true,timeout:60000,maxBuffer:4*1024*1024,encoding:'utf8',env:{...process.env,NWN_PARTICLE_KERNEL:'compiled',APPDATA:path.join(dir,'appdata'),LOCALAPPDATA:path.join(dir,'localappdata')}});
 fs.writeFileSync(path.join(dir,'stdout.log'),child.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(dir,'stderr.log'),child.stderr??'',{flag:'wx'});
 let value;try{value=JSON.parse(fs.readFileSync(report));}catch{}
 const text=[child.stdout,child.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n'),errors=text.split(/\r?\n/).filter(s=>/SCRIPT ERROR|Parse Error|(?:^|\s)ERROR:|WARNING:|ObjectDB.*leak|resources still in use/.test(s));
 const row={variant,index,success:child.status===0&&!child.error&&errors.length===0&&value?.success===true,exit:child.status,error:child.error?.message,errors,report,reportSha256:value?hash(fs.readFileSync(report)):null,...value?.measurements,samples_us:undefined};rows.push(row);console.log(JSON.stringify(row));if(!row.success)break;
}
const median=values=>{const sorted=[...values].sort((a,b)=>a-b),n=sorted.length;return n%2?sorted[n>>1]:(sorted[n/2-1]+sorted[n/2])/2;},averages=Object.fromEntries(['control','candidate'].map(variant=>[variant,median(rows.filter(r=>r.variant===variant).map(r=>r.mean_us))]));
const result={success:rows.length===8&&rows.every(r=>r.success)&&new Set(rows.map(r=>r.packet_sha256)).size===1,rows,averages,meanChangePercent:100*(averages.candidate/averages.control-1),fixtureSha256:hash(bytes),scope:'Eight sequential ABBA/ABBA private native CPU dispatch runs with exact final packet hash; no graphical FPS or main-client acceptance'};
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:result.success,averages,meanChangePercent:result.meanChangePercent}));if(!result.success)process.exitCode=1;
