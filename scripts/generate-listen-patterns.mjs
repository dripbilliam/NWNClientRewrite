import {readFileSync,writeFileSync} from 'node:fs';
const native=JSON.parse(readFileSync(new URL('../backups/animations/native-listen-expression-observations.json',import.meta.url)));
if(native.binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw new Error('Wrong target build');
writeFileSync(new URL('../src/associate_listen_patterns.js',import.meta.url),
  '// Native SetAssociateListenPatterns1403d8160: observed registration order and IDs.\n'+
  'export const associateListenPatterns='+JSON.stringify(native.associatePatterns,null,2)+';\n');
