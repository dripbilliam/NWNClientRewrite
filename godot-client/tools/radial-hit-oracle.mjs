import fs from 'node:fs/promises';import {radialHit} from '../../src/radial_actions.js';
const output=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);if(!output)throw Error('Use an unused --report= path');
const cases=[];for(let x=-310;x<=310;x+=10)for(let y=-310;y<=310;y+=10)cases.push({point:[x,y],expected:radialHit(x,y)});
for(const radius of [20,21,56,57,150,151,300,301])for(const sign of [-1,1])cases.push({point:[sign*radius,0],expected:radialHit(sign*radius,0)});
await fs.writeFile(output,JSON.stringify({scope:'Authored pixel-coordinate cases evaluated by the retained original-derived JS radial selection bands; not a fresh native-binary observation',cases},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({cases:cases.length,output}));
