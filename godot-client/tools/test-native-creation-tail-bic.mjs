import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const label=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/creation-tail-bic',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){const source=bytes.toString();for(const match of source.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));for(const match of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));}
}
for(const file of ['tests/native_creation_tail_bic_test.gd'])include(path.join(project,file));
include(fileURLToPath(import.meta.url));
include(path.join(project,'reports/native-tail-appearance-save-original-v1.json'));
include(path.join(workspace,'scripts/inspect-native-tail-appearance-save.py'));
for(const file of ['package.json','src/gff.js','src/gff_text.js'])include(path.join(workspace,file));

for(const [file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed while copied');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Typed Tail BIC"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected Godot runtime');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(godot,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/native_creation_tail_bic_test.gd','--','--report='+report,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall')],{windowsHide:true,timeout:20000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
let independentChecks=0,independentError=null;
if(child.status===0&&!child.error&&clean&&result?.success===true){
 try{
  const {parseGff,getGffFieldTypes,getGffStructType}=await import(pathToFileURL(path.join(copy,'src/gff.js')));
  const bic=parseGff(fs.readFileSync(report+'.bic'),'BIC ').root,uti=parseGff(fs.readFileSync(report+'.uti'),'UTI ').root;
  const equal=(actual,expected)=>{assert.deepEqual(actual,expected);independentChecks++;};
  equal([bic.Appearance_Head,bic.xAppearance_Head,getGffFieldTypes(bic).Appearance_Head,getGffFieldTypes(bic).xAppearance_Head],[0,300,0,2]);
  equal([bic.BodyPart_Torso,bic.xBodyPart_Torso],[0,297]);equal(Object.hasOwn(bic,'BodyPart_Robe'),false);
  equal(Object.keys(bic.Equip_ItemList[0]),['EquippedRes']);equal(bic.Equip_ItemList[0].EquippedRes,'physical_outfit');equal(getGffStructType(bic.Equip_ItemList[0]),2);equal(getGffFieldTypes(bic.Equip_ItemList[0]).EquippedRes,11);
  equal([bic.FirstName.entries[0].text,bic.LastName.entries[0].text,bic.Description.entries[0].text,bic.Deity],['  é'+'€'.repeat(247),' Last ','  Biography é €  ',' deity é ']);equal([bic.Age,bic.SoundSetFile],[-7,50001]);
  const parts=['RFoot','LFoot','RShin','LShin','LThigh','RThigh','Pelvis','Torso','Belt','Neck','RFArm','LFArm','RBicep','LBicep','RShoul','LShoul','RHand','LHand','Robe'];
  for(const [index,part]of parts.entries()){const normal='ArmorPart_'+part,extended=('x'+normal).slice(0,16);equal([uti[normal],uti[extended],getGffFieldTypes(uti)[normal],getGffFieldTypes(uti)[extended]],[0,400+index,0,2]);}
  for(const[index,material]of ['Leather1','Leather2','Cloth1','Cloth2','Metal1','Metal2'].entries())equal([uti[material+'Color'],getGffFieldTypes(uti)[material+'Color']],[255-index,0]);
  equal(uti.SourceQword,0xfedcba98fedcba98n);equal([...uti.PrivateData],[7,8,9]);equal([uti.Tag,uti.PropertiesList[0].PropertyName,uti.PropertiesList[0].Subtype,uti.APart_7_Col_2],['Physical outfit tag',321,456,37]);
 }catch(error){independentError=error.stack??String(error);}
}
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&changed.length===0&&!independentError&&independentChecks>0,checks:(result?.checks??0)+independentChecks,nativeChecks:result?.checks??0,independentChecks,independentError,failures:result?.failures??[],directory,report,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,scope:'Staged source-tail typed BIC/UTI patch validation plus independent copied JS parser; no shipping builder/creator/server integration.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,failures:proof.failures.length,inputs:proof.inputs.length}));process.exitCode=proof.success?0:1;
