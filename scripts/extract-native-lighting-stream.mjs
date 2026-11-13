// Accept only tshark's stream/sequence/payload fields on stdin; retain only
// complete native lighting observations, never raw traffic or login messages.
import fs from 'node:fs/promises';
let text = '', bytes = 0;
for await (const chunk of process.stdin) {
  bytes += chunk.length;
  if (bytes > 32 * 1024 * 1024) throw Error('Lighting observation input exceeds bound');
  text += chunk;
}
const streams = new Map();
for (const line of text.trim().split(/\r?\n/)) {
  const [stream, sequence, hex] = line.split('\t');
  if (!hex || !/^\d+$/.test(sequence)) continue;
  if (!streams.has(stream)) streams.set(stream, []);
  streams.get(stream).push({sequence: Number(sequence), bytes: Buffer.from(hex.replaceAll(':', ''), 'hex')});
}
let gaps = 0, parsed = 0;const observations = [], worldLighting = [];
for (const segments of streams.values()) {
  const origin = segments[0].sequence;
  segments.forEach(row => { row.offset = (row.sequence - origin) >>> 0; });
  segments.sort((a, b) => a.offset - b.offset);
  const blocks = [];let parts = [], end = 0;
  for (const row of segments) {
    if (row.offset > end) { if (parts.length) blocks.push(Buffer.concat(parts)); parts = [];end = row.offset;gaps++; }
    const skip = Math.max(0, end - row.offset);
    if (skip < row.bytes.length) { parts.push(row.bytes.subarray(skip));end = row.offset + row.bytes.length; }
  }
  if (parts.length) blocks.push(Buffer.concat(parts));
  for (const block of blocks) for (const line of block.toString('utf8').split('\n')) {
    try {
      const row = JSON.parse(line);parsed++;
      if (row.kind === 'observed' && row.area_lighting) observations.push({
        at: Date.now(), nativeProcessId: row.nativeProcessId, areaId: row.areaId,
        generation: row.generation, connection: row.connection, lighting: row.area_lighting,
      });
      if (process.argv.includes('--world') && row.kind === 'raw-world-begin' && row.data?.area) {
        const area = row.data.area;
        const tiles = Array.isArray(area.tiles) ? area.tiles : [];
        const variants = new Map();
        for (const tile of tiles) {
          // Tile records are authored lighting/placement only, not creatures,
          // chat, login messages or account data.
          const key = JSON.stringify(tile);
          if (!variants.has(key) && variants.size < 512) variants.set(key, tile);
        }
        worldLighting.push({generation: row.generation, connection: row.connection,
          area: Object.fromEntries(['id','resRef','fields','width','height','tileset','time'].filter(key => key in area).map(key => [key,area[key]])),
          tileCount: tiles.length, tiles: [...variants.values()],
          lightColor: row.data.lightColor, headerKeys: Object.keys(row.data)});
      }
    } catch { /* A capture can start/end within a frame. Partial JSON is never evidence. */ }
  }
}
const result = {success: observations.length > 0 || worldLighting.length > 0, complete_observations: observations.length,
  parsed, gaps, latest: observations.at(-1), worldLighting: worldLighting.at(-1), scope: 'Passive own-loopback lighting diagnostics/area tile lighting only. Raw packet payloads, objects, and other messages are not retained.'};
await fs.writeFile(process.argv[2], JSON.stringify(result, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(process.argv.includes('--world') ? {success:result.success,parsed,gaps,
  areaId:result.worldLighting?.area?.id,tileset:result.worldLighting?.area?.tileset,tileCount:result.worldLighting?.tileCount,
  headerKeys:result.worldLighting?.headerKeys,output:process.argv[2]} : result, null, 2));
if (!result.success) process.exitCode = 1;
