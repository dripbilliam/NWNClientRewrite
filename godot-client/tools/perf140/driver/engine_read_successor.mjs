// Pure, selected-source composition contract. Does not stage or build anything.
import path from 'node:path';
export const CONSUMER_V2_MANIFEST_SHA = 'd569ec0a8d66cd586783f43906769062c23a036390ce5d6863f0e775dc205b14';
export const CONSUMER_V2_COMPOSE_SHA = 'a5d8cc9c8e1c971b568485ef428cbf53533437b4238bc1020201667446afb9a1';
export const CONSUMER_V2_BUILDER_SHA = 'c9cc13f915dfc988c37ef77a7c8d0592f10db135e0f8581f50b837353014d799';
const overlaySha = '8af556f79785a0468f25cd9c87792e40da1f121eecd3a7ba81b0a7462da77e1b';
const managedSha = '20fab7baae2500eb4e45a95e77da68a2f4f913b52fe252666e1f2fa81a1afd14';
const consumer = 'native/experimental/nwn_particle_read_consumer_v1.hpp';
const before = '1c5deb517798a20329dc63f4e3408bec4a6c75e105e30c483b8d5d025205b221';
const after = '5042fa0ea77dc24245a54ea0b1a8bf275daf3b17cfa1ce210302492dc36856a9';

export function engineReadSourceComposition(overlay, successor, reviewedSha) {
  if (!Array.isArray(overlay?.outputs) || overlay.outputs.length !== 5 ||
      new Set(overlay.outputs.map(row => row.relative)).size !== 5 ||
      overlay.outputs.find(row => row.relative === consumer)?.sha256 !== before) {
    throw new Error('Frozen five-file consumer overlay contract differs');
  }
  if (!successor && reviewedSha === undefined) return overlay.outputs.map(row => ({...row}));
  if (reviewedSha !== CONSUMER_V2_MANIFEST_SHA || !successor ||
      successor.version !== 1 || successor.kind !== 'source-only-consumer-successor-package' ||
      successor.parentManagedReceiptSha256 !== managedSha ||
      successor.parentProductionOverlay?.sha256 !== overlaySha ||
      successor.parentConsumerSha256 !== before ||
      successor.abi?.sha256 !== '985efa740c5284506b50f2703d4d9b028d2b5b7414f883a2461000bacc7f7527' ||
      successor.producerManifestSha256 !== '32c32bcb91a9d03782d62c575b44548a25a6b343378f2b3fe107e19fe23260e8' ||
      JSON.stringify(successor.productionDeltaFromV1) !== JSON.stringify([consumer])) {
    throw new Error('Explicit reviewed ConsumerV2 lineage is required');
  }
  const rows = successor.productionFiles;
  if (!Array.isArray(rows) || rows.length !== 5 || new Set(rows.map(row => row.relative)).size !== 5) {
    throw new Error('ConsumerV2 production source inventory differs');
  }
  for (const old of overlay.outputs) {
    const row = rows.find(value => value.relative === old.relative);
    if (row?.sha256 !== (old.relative === consumer ? after : old.sha256)) {
      throw new Error('Unreviewed consumer source change: ' + old.relative);
    }
  }
  return rows.map(row => ({...row}));
}

export function engineReadV2BuildInvocation(build, sourceProject, apiRoot, builderFile) {
  const same = (a, b) => typeof a === 'string' && typeof b === 'string' &&
    path.resolve(a).toLowerCase() === path.resolve(b).toLowerCase();
  const invocation = build?.actualInvocation, guard = invocation?.environmentGuard;
  if (!invocation || invocation.version !== 1 || build.sourceReceiptUnchanged !== true ||
      build.builderUnchanged !== true || invocation.builderSha256 !== CONSUMER_V2_BUILDER_SHA ||
      !same(invocation.builderFile, builderFile) || !same(invocation.workingDirectory, sourceProject) ||
      typeof invocation.compilerFile !== 'string' || !path.isAbsolute(invocation.compilerFile) ||
      !/^[0-9a-f]{64}$/.test(invocation.compilerSha256 ?? '') || invocation.compilerVersion !== build.compiler ||
      guard?.policy !== 'reject-nonempty-CL-and-_CL_' || guard.CL !== false || guard._CL_ !== false ||
      guard.checkedImmediatelyBeforeCompiler !== true) {
    throw new Error('Reviewed V2 compiler/builder/environment witness differs');
  }
  const args = invocation.arguments, output = path.join(sourceProject, '.cache/native-kernel');
  const prefix = ['/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD'];
  const optionPath = (value, option, expected) => typeof value === 'string' &&
    value.startsWith(option) && same(value.slice(option.length), expected);
  if (!Array.isArray(args) || args.length !== 16 || prefix.some((value, i) => args[i] !== value) ||
      !optionPath(args[9], '/I', apiRoot) ||
      !optionPath(args[10], '/Fo', path.join(output, 'engine-read-v2-kernel.obj')) ||
      !optionPath(args[11], '/Fe', path.join(output, 'nwn-particle-kernel.dll')) ||
      !same(args[12], path.join(sourceProject, 'native/particle_kernel.cpp')) ||
      args[13] !== '/link' || args[14] !== '/INCREMENTAL:NO' ||
      !optionPath(args[15], '/IMPLIB:', path.join(output, 'engine-read-v2-kernel.lib'))) {
    throw new Error('Actual V2 strict compiler argument array differs');
  }
  return true;
}
