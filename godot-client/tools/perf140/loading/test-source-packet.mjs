import fs from 'node:fs';import path from 'node:path';
import {isolatedHeadless} from './isolated-headless.mjs';
const packet=await isolatedHeadless({label:process.argv[2],pattern:/^source-packet-[a-z0-9-]+$/,script:'native_perf140_loading_source_packet_test.gd',argumentsForVariant:variant=>['--expect-packets='+(variant==='candidate'),'--prepared-cache-write=disabled']});
if(packet.success)await isolatedHeadless({label:process.argv[2],pattern:/^source-packet-[a-z0-9-]+$/,directory:'checks-job-integration',script:'native_perf140_loading_job_digest_test.gd',argumentsForVariant:(_variant,root)=>{const cache=path.join(root,'owned-prepared-cache');fs.mkdirSync(cache);return ['--expect-reuse=true','--prepared-cache-write=sync','--cache-root='+cache];}});
