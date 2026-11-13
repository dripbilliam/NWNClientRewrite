'use strict';
const path = require('node:path'), assert = require('node:assert/strict');
function relative(value) {
 assert(typeof value === 'string' && value && !path.win32.isAbsolute(value) && !path.posix.isAbsolute(value), 'Absolute/empty project target');
 const parts = value.split(/[\\/]+/);
 for (const part of parts) assert(part && part !== '.' && part !== '..' && !/[<>:"|?*\x00-\x1f]/.test(part) && !/[. ]$/.test(part), 'Unsafe project path component');
 return parts.join('/');
}
const key = value => relative(value).toLowerCase();
function unique(rows, label) {
 const seen = new Set();
 return rows.map(row => { const normalized = relative(row.relative), id = key(normalized); assert(!seen.has(id), label + ' contains duplicate Windows target: ' + normalized); seen.add(id); return { ...row, relative: normalized }; });
}
function plan(base, overlay, binaries) {
 const baseRows = unique(base, 'Base'), overlayRows = unique(overlay, 'Overlay'), binaryRows = unique(binaries, 'Binary');
 unique([...overlayRows, ...binaryRows], 'Combined overrides');
 const replaced = new Set([...overlayRows, ...binaryRows].map(row => key(row.relative)));
 return { base: baseRows.filter(row => !replaced.has(key(row.relative))), overlay: overlayRows, binaries: binaryRows };
}
module.exports = { relative, key, unique, plan };
