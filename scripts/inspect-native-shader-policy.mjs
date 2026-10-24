// Static inspection only: read installed resources in place, retain hashes and
// line anchors. Never execute a shader, launch a game, or copy shader assets.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {parseKey} from '../src/resource_archive.js';

const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const installation=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const binary=await fs.readFile(path.join(installation,'bin/win32/nwmain.exe'));
const binarySha256=hash(binary);
if(binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Native build changed; remap call sites before interpreting shader policy.');
const keyBytes=await fs.readFile(path.join(installation,'data/nwn_base.key'));
const key=parseKey(keyBytes),bif=await fs.readFile(path.join(installation,'data/base_shaders.bif'));
if(bif.toString('ascii',0,4)!=='BIFF')throw Error('Unsupported shader archive');
const version=bif.toString('ascii',4,8);
if(!['V1  ','V1.1'].includes(version))throw Error('Unsupported shader archive version');
const stride=version==='V1.1'?20:16,table=bif.readUInt32LE(16);
const markers={
 inc_lighting:{arrayCapacity:/\[MAX_NUM_LIGHTS\]/,runtimeCount:/uniform.*int numLights/,runtimeLoop:/for \(int i = 0; i < numLights;/,enhancedRange:/fLightRange = abs\(lightColor/,rangeReturn:/if\(fLightRange<fDistance_sq/,enhancedRatio:/fLightFalloff2 = fDistance_sq/,enhancedFade:/fAttenuation = 1.0-/,enhancedDenominator:/fAttenuation \/=/,legacyAttenuation:/lightQuadraticAtten\[nLightID\] \*/,ambientSign:/lightColor\[i\]\.a < 0.0/,ambientMaterial:/AmbientLight \*= materialFrontAmbient/,diffuseMaterial:/\* materialFrontDiffuse\.rgb/,emissiveTotal:/TotalLight = materialFrontEmissive/,constantLight:/ConstantLight =/,constantFloor:/TotalLight = max\(TotalLight/,legacyClamp:/TotalLight = clamp/},
 inc_standard:{fragmentLighting:/FRAGMENT_LIGHTING/,fragmentNormal:/FRAGMENT_NORMAL/,staticVertex:/VertexStaticLighting/,computeLighting:/ComputeLighting\(/},
 inc_config:{quality:/SHADER_QUALITY_MODE/,fresnel:/SPECULAR_FRESNEL/,softening:/SOFTENING/},
 inc_common:{noDiscard:/NO_DISCARD/,forceAllowDiscard:/FORCE_ALLOW_DISCARD/,discardDefinition:/define discard/,legacyMaxLights:/MAX_LIGHTS/,colorConversion:/^(float|vec[34]) (Apply|Revert)ColorSpace/,signedPower:/return sign\(/,preservedAlpha:/return vec4\((Apply|Revert)ColorSpace/},
};
const resources=[];
for(const [name,patterns]of Object.entries(markers)){
 const entry=[...key.resources.values()].find(e=>e.resref===name&&e.resourceType===2069&&key.bifNames[e.bifIndex].endsWith('base_shaders.bif'));
 if(!entry)throw Error('Missing shader resource '+name);
 const row=table+entry.resourceIndex*stride+(stride===20?8:4);
 const offset=bif.readUInt32LE(row),size=bif.readUInt32LE(row+4);
 if(offset+size>bif.length)throw Error('Shader resource range exceeds archive');
 const bytes=bif.subarray(offset,offset+size),lines=bytes.toString('utf8').split('\n');
 resources.push({name,type:2069,resourceIndex:entry.resourceIndex,offset,bytes:size,sha256:hash(bytes),lineCount:lines.length,
  anchors:Object.fromEntries(Object.entries(patterns).map(([label,pattern])=>[label,lines.flatMap((line,index)=>pattern.test(line)?[index+1]:[])]))});
}
const report={version:1,build:'89.8193.37-17',binarySha256,
 scope:'Static source inspection in the base archive, not execution, timing, active override resolution or proof of the settings used by a running client. Resource text is not retained.',
 sources:{key:{path:'../FullDecomp/NwnRootInstall/data/nwn_base.key',sha256:hash(keyBytes)},archive:{path:'../FullDecomp/NwnRootInstall/data/base_shaders.bif',sha256:hash(bif)}},
 lineNumbering:'One-based UTF-8 source lines; anchors locate reviewed branches, they are not semantic validation tests.',resources};
const output=path.join(workspace,'runtime-logs/native-render-parity/base-shader-policy-metadata.json');
await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output:path.relative(workspace,output),resources:resources.map(({name,sha256,anchors})=>({name,sha256,anchors}))}));
