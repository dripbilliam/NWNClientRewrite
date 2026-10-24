import {parseGff} from './gff.js';
import {RESOURCE_TYPE} from './resource_archive.js';
import {resolvePlayerModels} from './character.js';
import {parseModel} from './model_parser.js';
import {inheritAnimations} from './mdl_animation.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {resolveTextureResource,textureResourceFile} from './texture_resource.js';

export async function loadCharacterCreationAssets(draft,rules){
  const data={Race:draft.raceId,Gender:draft.gender,Appearance_Type:Number(rules.racialtypes.orderedRows[draft.raceId].Appearance),Phenotype:draft.phenotype,Appearance_Head:draft.head,
    Color_Skin:draft.skin,Color_Hair:draft.hair,Color_Tattoo1:draft.tattoo1,Color_Tattoo2:draft.tattoo2,ArmorPart_RFoot:1};
  for(const part of ['Neck','Torso','Pelvis','LBicep','LFArm','LHand','LThigh','LShin','LFoot','RBicep','RFArm','RHand','RThigh','RShin'])data[`BodyPart_${part}`]=1;
  const clothes=rules.chargenclothes.orderedRows[draft.clothes];
  if(clothes){const armor=parseGff(await rules.creationResolver.getResource(clothes.ItemResRef,RESOURCE_TYPE.UTI),'UTI ').root;for(const[key,value]of Object.entries(armor))if(key.startsWith('ArmorPart_'))data[key.replace('ArmorPart_','BodyPart_')]=value;data.ArmorPart_RFoot=armor.ArmorPart_RFoot??1;for(const material of ['Metal1','Metal2','Cloth1','Cloth2','Leather1','Leather2'])data[`Color_${material}`]=armor[`${material}Color`]??0;}
  const appearance=resolvePlayerModels(data,rules),resolver=rules.creationResolver,parsed=new Map(),files=[],paletteRows=new Map(),partKeys=new Map();
  if(!appearance)throw new Error('Character appearance is unavailable');
  const load=async(primary,fallback)=>{if(parsed.has(primary))return primary;try{parsed.set(primary,parseModel(await resolver.getResource(primary,RESOURCE_TYPE.MDL)));return primary;}catch(error){if(error.code!=='RESOURCE_NOT_FOUND'||!fallback||primary===fallback)throw error;parsed.set(fallback,parseModel(await resolver.getResource(fallback,RESOURCE_TYPE.MDL)));return fallback;}};
  const bodyName=await load(appearance.model,appearance.fallbackModel);
  const partNames=new Map();for(const part of appearance.parts){partNames.set(part,await load(part.model,part.fallbackModel));for(const candidate of part.pltCandidates??[]){try{const bytes=await resolver.getResource(candidate,RESOURCE_TYPE.PLT),key=`${candidate}__creation_${partNames.size}`;files.push({name:`${key}.plt`,arrayBuffer:async()=>bytes});paletteRows.set(key,appearance.paletteColors);partKeys.set(part,key);break;}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}}}
  const animationSources=new Map(parsed);for(const model of parsed.values())await inheritAnimations(model,async name=>{if(!animationSources.has(name))animationSources.set(name,parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL)));return animationSources.get(name);});
  for(const name of new Set([...parsed.values()].flatMap(p=>p.materialNames))){if(!name||name.toLowerCase()==='null')continue;paletteRows.set(name,appearance.paletteColors);try{files.push(textureResourceFile(name,await resolveTextureResource(resolver,name)));}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;runtimeDiagnostics.record('character.preview-texture-unavailable',`Character preview texture ${name} is unavailable`,{resource:name});}}
  return{appearance,resolver,parsed,files,paletteRows,partKeys,bodyName,partNames};
}
