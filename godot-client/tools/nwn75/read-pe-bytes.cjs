const fs = require('node:fs');

const [binaryPath, addressText, lengthText = '32'] = process.argv.slice(2);
if (!binaryPath || !addressText) throw new Error('Usage: node read-pe-bytes.cjs <PE path> <virtual address> [length]');
const bytes = fs.readFileSync(binaryPath);
const pe = bytes.readUInt32LE(0x3c);
if (bytes.toString('ascii', pe, pe + 4) !== 'PE\0\0') throw new Error('Not a PE image');
const optional = pe + 24;
if (bytes.readUInt16LE(optional) !== 0x20b) throw new Error('Expected PE32+');
const imageBase = bytes.readBigUInt64LE(optional + 24);
const rva = Number(BigInt(addressText) - imageBase);
const length = Number(lengthText);
if (!Number.isInteger(rva) || !Number.isInteger(length) || length < 1 || length > 4096) throw new Error('Invalid address or length');
const count = bytes.readUInt16LE(pe + 6);
const sectionTable = optional + bytes.readUInt16LE(pe + 20);
let result;
for (let index = 0; index < count; index++) {
  const header = sectionTable + index * 40;
  const name = bytes.toString('ascii', header, header + 8).replace(/\0.*$/, '');
  const virtualAddress = bytes.readUInt32LE(header + 12);
  const rawSize = bytes.readUInt32LE(header + 16);
  const rawPointer = bytes.readUInt32LE(header + 20);
  if (rva < virtualAddress || rva + length > virtualAddress + rawSize) continue;
  const fileOffset = rawPointer + rva - virtualAddress;
  if (fileOffset + length > bytes.length) throw new Error('Read exceeds PE file');
  result = {address: addressText, length, section: name, fileOffset, bytesHex: bytes.subarray(fileOffset, fileOffset + length).toString('hex')};
  break;
}
if (!result) throw new Error('Address is outside initialized section bytes');
process.stdout.write(JSON.stringify(result, null, 2) + '\n');
