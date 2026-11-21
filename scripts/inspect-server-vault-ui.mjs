import fs from 'node:fs/promises';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
const resolver=await openServerResourceContext({install:process.argv[2]}),names=[...resolver.key.resources.keys()];
const result={gui:names.filter(k=>k.endsWith(':'+RESOURCE_TYPE.GUI)&&/char|mult|server|main|menu|load|join|net/i.test(k)),models:names.filter(k=>k.endsWith(':'+RESOURCE_TYPE.MDL)&&/^(pnl_|ctl_|mnu_|gui_|logo)/i.test(k)&&/char|mult|server|main|menu|load|join|net/i.test(k)),textures:names.filter(k=>k.endsWith(':'+RESOURCE_TYPE.TGA)&&/logo|mainmenu|menubg|multipl|beamdog/i.test(k))};await fs.writeFile('backups/animations/server-vault-ui-inventory-v1.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
