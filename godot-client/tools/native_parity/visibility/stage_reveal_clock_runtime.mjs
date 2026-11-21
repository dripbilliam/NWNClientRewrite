// Copy only the reviewed existing absolute-source artifacts. No compilation,
// extension loading, timer initialization, OS sampling or process launch.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sha=raw=>createHash('sha256').update(raw).digest('hex');
export function stageRevealClockRuntime(project){
 project=path.resolve(project);
 if(!project.startsWith(path.join(source,'.cache')+path.sep)||!fs.existsSync(path.join(project,'project.godot')))throw Error('Existing private project required');
 const sourceFile=path.join(source,'systems/native_data/native_clock_source.gd'),rawSource=fs.readFileSync(sourceFile),text=rawSource.toString('utf8');
 const descriptor='native-clock-source-v1/clock_source.gdextension',library='native-clock-source-v1/nwn-clock-source.dll';
 const expectedSha='497e483e44595a7518b860f92c55e3ab3cef9cd372b15c53a2ac31dfd2498190';
 if(!text.includes('const LIBRARY_SHA256="'+expectedSha+'"')||!text.includes('const DESCRIPTOR="res://.cache/'+descriptor+'"')||!text.includes('const LIBRARY="res://.cache/'+library+'"'))throw Error('Reviewed source identity contract changed');
 const match=text.match(/^const DESCRIPTOR_TEXT=("(?:[^"\\]|\\.)*")$/m);
 if(!match)throw Error('Exact reviewed clock descriptor literal unavailable');
 const descriptorText=JSON.parse(match[1]);
 const expectedClass='NwnClockSourceCandidate';if(!text.includes('const NATIVE_CLASS=&"'+expectedClass+'"'))throw Error('Reviewed native clock class changed');
 const stagedSource=path.join(project,'systems/native_data/native_clock_source.gd');
 if(!fs.existsSync(stagedSource)||sha(fs.readFileSync(stagedSource))!==sha(rawSource))throw Error('Staged native clock owner differs');
 const pins=[];
 for(const [kind,suffix] of [['descriptor',descriptor],['library',library]]){
  const relative='.cache/'+suffix,original=path.join(source,relative),raw=fs.readFileSync(original);
  if(kind==='descriptor'&&raw.toString('utf8')!==descriptorText||kind==='library'&&sha(raw)!==expectedSha)throw Error('Existing reviewed clock artifact changed: '+kind);
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(fs.existsSync(target)){if(sha(fs.readFileSync(target))!==sha(raw))throw Error('Different existing clock artifact retained');}
  else fs.writeFileSync(target,raw,{flag:'wx'});
  pins.push({relative,source:original,sha256:sha(raw),bytes:raw.length});
 }
 return {version:1,owner:{relative:'systems/native_data/native_clock_source.gd',sha256:sha(rawSource)},nativeClass:expectedClass,pins,existingArtifactsOnly:true,nativeBuilds:0,sourceSamples:0,processLaunches:0};
}
