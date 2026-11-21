// Deferred QA build. Does not write production sources, settings or dist.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {transformPreviewComparison} from './preview-comparison-transform.mjs';
import {transformLivePerformance} from './live-performance-transform.mjs';
import {transformSceneReplay} from './scene-replay-transform.mjs';
import {transformReplayThreeBridge} from './replay-three-bridge.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const args=process.argv.slice(2);
if(!args.includes('--run')) {
  console.log('Prepared only. --run --out=<backups/animations/performance-queue/.../preview-build> --report=<runtime-logs/performance-queue/...json> builds a QA-only preview comparison after checking no game is open.');
} else {
  await prepare();
}
async function prepare() {
  for(const arg of args)if(arg!=='--run'&&arg!=='--diagnostic'&&arg!=='--replay'&&arg!=='--draw-bridge'&&!arg.startsWith('--out=')&&!arg.startsWith('--report='))throw Error('Unknown option: '+arg);
  const diagnostic=args.includes('--diagnostic');
  const replay=args.includes('--replay');if(replay&&!diagnostic)throw Error('Replay requires an isolated diagnostic build');
  const drawBridge=args.includes('--draw-bridge');if(drawBridge&&!replay)throw Error('Private draw bridge requires offline replay');
  const outArgument=args.find(arg=>arg.startsWith('--out='))?.slice(6),reportArgument=args.find(arg=>arg.startsWith('--report='))?.slice(9);
  if(!outArgument||!reportArgument)throw Error('Explicit output and report paths required');
  const out=path.resolve(root,outArgument),reportFile=path.resolve(root,reportArgument);
  const inside=(directory,file)=>{const relative=path.relative(directory,file);return relative&&!relative.startsWith('..')&&!path.isAbsolute(relative);};
  if(!inside(path.join(root,'backups/animations/performance-queue'),out)||path.basename(out)!==(diagnostic?'diagnostic-build':'preview-build'))throw Error('Invalid QA build directory');
  if(!inside(path.join(root,'runtime-logs/performance-queue'),reportFile)||!reportFile.endsWith('.json'))throw Error('Invalid QA report path');
  if(process.platform!=='win32')throw Error('Prepared build guard targets Windows');
  const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
  const {stdout}=await promisify(execFile)(powershell,['-NoProfile','-NonInteractive','-Command',"$ErrorActionPreference='Stop'; $queueGames=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('nwmain.exe','nwmain-windows.exe','electron.exe') } | Select-Object ProcessId,Name); ConvertTo-Json -InputObject $queueGames -Compress"],{windowsHide:true});
  const games=JSON.parse(stdout.trim()||'[]');if(!Array.isArray(games))throw Error('Invalid game inventory');
  if(games.length)throw Error('Game preserved; defer this build until closed: '+games.map(game=>game.Name+' PID '+game.ProcessId).join(', '));
  for(const filename of [out,reportFile]){let exists=false;try{await fs.access(filename);exists=true;}catch(error){if(error.code!=='ENOENT')throw error;}if(exists)throw Error('Refusing to overwrite '+filename);}
  const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
  const snapshot=async directory=>{
    const result={};async function walk(folder){for(const entry of await fs.readdir(folder,{withFileTypes:true})){const file=path.join(folder,entry.name);if(entry.isDirectory())await walk(file);else result[path.relative(directory,file).replaceAll('\\','/')]=hash(await fs.readFile(file));}}
    await walk(directory);return result;
  };
  const mainFile=path.join(root,'src/main.js'),source=await fs.readFile(mainFile,'utf8'),normal=await snapshot(path.join(root,'dist'));
  const report={success:false,scope:diagnostic?'Isolated live experimental candidate build with baseline switch and diagnostics. No connection performed by the builder.':'Isolated QA comparison build; default baseline keeps gameplay previews. No test or connection is performed by the builder.',out,diagnostic,sourceSha256:hash(source),normalDistBefore:normal};
  try {
    const {build}=await import('vite');let transforms=0,bridgeTransforms=0;const threeFile=path.join(root,'node_modules/three/build/three.module.js'),threeHash=hash(await fs.readFile(threeFile));
    await build({root,configFile:false,base:'./',mode:'production',envDir:false,envPrefix:[],cacheDir:path.join(out,'.vite-cache'),
      plugins:[{name:'queued-preview-comparison',enforce:'pre',transform(code,id){if(path.resolve(id.split('?')[0])!==mainFile)return null;transforms++;const result=(replay?transformSceneReplay:diagnostic?transformLivePerformance:transformPreviewComparison)(code);report.edits=result.edits;report.transformedSha256=hash(result.code);return {code:result.code,map:null};}},{name:'private-replay-three-bridge',enforce:'pre',transform(code,id){if(!drawBridge||path.resolve(id.split('?')[0])!==threeFile)return null;bridgeTransforms++;const transformed=transformReplayThreeBridge(code);report.privateDrawBridge={sourceSha256:threeHash,inputSha256:hash(code),transformedSha256:hash(transformed)};return{code:transformed,map:null};}}],
      build:{outDir:out,emptyOutDir:false,sourcemap:true}});
    if(transforms!==1)throw Error('Expected exactly one main-module transform');
    if(drawBridge&&bridgeTransforms!==1)throw Error('Expected exactly one private Three bridge transform');if(hash(await fs.readFile(threeFile))!==threeHash)throw Error('Installed Three file changed');
    report.bundle=(await fs.readFile(path.join(out,'index.html'),'utf8')).match(/src="\.\/assets\/([^"\s]+\.js)"/)?.[1];
    if(!report.bundle)throw Error('QA build did not emit its main bundle');
    report.bundleSha256=hash(await fs.readFile(path.join(out,'assets',report.bundle)));
    report.normalDistAfter=await snapshot(path.join(root,'dist'));report.productionSourceUnchanged=hash(await fs.readFile(mainFile))===report.sourceSha256;
    report.normalDistUnchanged=JSON.stringify(report.normalDistBefore)===JSON.stringify(report.normalDistAfter);
    if(!report.productionSourceUnchanged||!report.normalDistUnchanged)throw Error('Production source/build changed during QA preparation');
    report.success=true;
  } catch(error) {report.failure=error.stack;process.exitCode=1;}
  finally {await fs.mkdir(path.dirname(reportFile),{recursive:true});await fs.writeFile(reportFile,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,out,report:reportFile,failure:report.failure}));}
}
