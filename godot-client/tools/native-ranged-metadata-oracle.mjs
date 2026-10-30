import fs from 'node:fs/promises';import {clientRangedProjectileMetadata} from '../../src/client_ranged_projectile.js';
const cases=[];
for(const legacy of [0,1,2])for(const ammo of [0,1,2,3,4,5,6,128,255])for(const appearance of [0,1,2,3,4,5,8]){
 const baseitems={columns:['AmmunitionType'],orderedRows:[{AmmunitionType:String(ammo)}],defaultValue:'****'},columns=['Model','ShotSound','ImpactSound',...(legacy===1?[]:['AmmunitionType']),...(legacy===2?[]:['DamageRangedProjectile'])];
 const rows=Array.from({length:40},(_,i)=>({Model:'authored_'+i,ShotSound:i%2?'shot':'****',ImpactSound:'impact',AmmunitionType:String(i<8?i:i===8?-1:i===9?-128:1),DamageRangedProjectile:String(i<8?appearance:i===10?appearance:0)}));
 const ammunitiontypes={columns,orderedRows:rows,defaultValue:'****'},tables={baseitems,ammunitiontypes};cases.push({tables,baseItem:0,appearance,expected:clientRangedProjectileMetadata(tables,0,appearance)});
}
await fs.writeFile('godot-client/reports/native-ranged-metadata-oracle-v1.json',JSON.stringify({scope:'Authored active-table cases evaluated by retained original-derived loader; not original resource payload or fresh binary execution',cases})+'\n',{flag:'wx'});console.log(JSON.stringify({cases:cases.length}));
