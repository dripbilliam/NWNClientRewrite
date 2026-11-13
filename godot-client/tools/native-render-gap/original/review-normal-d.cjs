'use strict';
// Review-time retained source/receipt reading only; no native or compiler starts.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const stage = '.cache/native-render-gap/scene/normal-integration-d-b/';
const pin = relative => {
  const b = fs.readFileSync(path.join(root, relative));
  return { relative, bytes: b.length, sha256: crypto.createHash('sha256').update(b).digest('hex') };
};
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative)));
const manifest = read(stage + 'manifest.json');
const receipt = read(stage + 'bounded-checks-a/acceptance.json');
const files = [stage + 'manifest.json', stage + 'bounded-checks-a/acceptance.json',
  ...['prepare.cjs', 'patches.cjs', 'policy.cjs', 'check-bounded.cjs'].map(x => 'tools/native-render-gap/scene/normal-integration-d/' + x)];
const result = {
  version: 1, createdUtc: new Date().toISOString(), kind: 'independent-normal-d-b14-source-review',
  disposition: 'No current D14 functional policy/cache blocker found in the reviewed sources and retained bounded receipts. Private staging is not promotion acceptance.',
  scope: 'Independent read-only review; no test execution, engine/native/compiler launch, large main identity hash or source mutation. Review-time source pins do not retroactively prove executed historical source bytes.',
  subject: {
    stage, overlays: manifest.overlays.length, flags: manifest.normal.renderCore.flags,
    engineSha256: manifest.artifact.sha256, nativeSha256: manifest.nativeKernel.sha256,
    mainBefore: manifest.mainBefore, mainAfter: manifest.mainAfter,
    resourceSha256: manifest.resourceCache.binarySha256,
  },
  supportedByRetainedReceipts: {
    success: receipt.success, boundedChecks: receipt.checks.length,
    nativeChecks: receipt.native.checks, nativeExit: receipt.native.exit, nativeClean: receipt.native.clean,
    cacheCheckOnly: receipt.children.map(x => ({ script: x.script, exit: x.exit, stderrEmpty: x.stderr === '' })),
    qualification: '24 JS/cache checks include synthetic feature-use contracts;17 real headless checks exercise flags/capability/settings and32-lamp owner behavior. They are not graphical thread, all-feature heavy-world positive-use, normal local authority, FPS, or image acceptance.',
  },
  reviewed: [
    { area: 'Runtime/explicit choices', conclusion: 'native-client-flags resolver is unchanged. Default normal policy adds only the selected combined modes. Explicit standard, editor/release and isolated check/visual/probe routes keep the existing policy branches; explicit profile/native-profile choices retain C behavior.', evidence: 'Retained15-case current-C parity +2 explicit-env cases and conflict case; source native-performance-runtime acceptedRenderCore remains gated by normalGameplay and verified-native.' },
    { area: 'Script lighting fallback', conclusion: 'typedFlags filtering removes typed/segmented lighting and optional future E flags when script lighting is explicit. Particle and renderer common flags remain selected consistently with C.', evidence: 'Current script-light case parity and source filter set. New final E policy needs its own exact flag-array regression checks.' },
    { area: 'Cold feature observations', conclusion: 'Resident and empty census are cold dispatch21/22 reads. New selected flag report order matches policy. Busy-use verifier demands actual borrowed reads and configured/sealed/empty-map skips; negative zero-use synthetic cases reject.', evidence: 'native_live_world/render-core observation overlays and bounded contract cases. Small Prelude may report zero-use cohorts with requireBusyUse:false; this must not replace heavy-world proof.' },
    { area: 'Native cache', conclusion: 'Combined source/header/inc union and exact485741 DLL are staged together. Source manifest retains ordinary build/API dependencies and distinguishes accepted runtime engine from ABI-reference engine. CheckOnly confirms no rebuild and unchanged manifests.', evidence: 'Factory cacheInputs assertions and retained ensure-particle-kernel.ps1 CheckOnly exit0.' },
    { area: 'Independent resource cache', conclusion: 'Resource F2 and seven actual quoted-include/build/API dependencies are preserved. New resident/empty headers do not belong to the resource compile closure; resource CheckOnly exit0 supports avoiding the previous unnecessary rebuild.', evidence: 'Resource quoted include helper and resource-cache source manifest. No new resource compiler job is claimed.' },
    { area: 'Artifact/source provenance', conclusion: 'Private proof production:false and scope explicitly separate accepted component inputs from normal-route acceptance. Existing75bc engine build closure and combined build receipt are distinct. Source factory requires main identity45 at both ends and uses exact-seam patches.', evidence: 'manifest/artifact scopes and factory assertions. No installed write or original packed-asset claim occurs here.' },
  ],
  findings: [
    {
      severity: 'provenance-hardening', blockingCurrentPrivateReview: false,
      issue: 'Preparation manifest pins policy but not prepare.cjs/patches.cjs; bounded receipt does not pin its checker source. Current review can verify source consistency now but cannot independently prove these were the exact bytes executed historically.',
      requiredForFreshFinal: 'Freeze final preparation/patch/check source bytes before invocation; include their SHA and invocation in fresh manifest/receipt, then retain them. Do not rewrite accepted b evidence to invent historical pins.',
      communicatedTo: ['/root', '/root/cleanup_logs'],
    },
    {
      severity: 'future-variant-coverage', blockingCurrentPrivateReview: false,
      issue: 'Current bounded checker intentionally assumes14 selected features. It must not be reused unchanged as proof for a future E16/17 or Ob3 selection.',
      requiredForFreshFinal: 'Derive exact ordered flags from sealed final policy, require the expected feature set rather than only a count, test removal of optional typed E flags for script lighting, and keep independent exact native/compiler/source proof for Ob3.',
    },
  ],
  promotionGuards: [
    'Freeze exact final selected policy, overlays and source factory before normal acceptance; deferred E/Ob3 selection must not silently inherit D14 receipts as proof of its extra work.',
    'Require final graphical normal-runtime/loaded engine+DLL+resource/process creation proof, profiling OFF, separate observed render thread, and explicit normalGameplay=true/isolated=false.',
    'Require fresh matched heavy-world feature-use verification and saved-view review with the exact selected final flags; no synthetic or empty-Prelude waiver for heavy routes.',
    'Require fresh ordinary local authoritative-walk and clean exit using expected flags derived from sealed final proof; preserve accepted C j evidence and original protected user preferences.',
    'Before installed writes, verify each exact beforeSha256 or absence against the reviewed overlay set, selected engine/kernel/resource hashes and provenance receipts; journal/backup replacements and refuse unrelated drift.',
    'After install, perform ordinary bounded check-only/cache and policy validation without an unplanned compiler rebuild; retain exact source identity and component outputs.',
    'Retain test-only TLS/fixture files outside promotion overlays and normal replay selection; candidate test helpers do not become product inputs.',
  ],
  reviewTimePins: files.map(pin),
  changes: [], newRuntimeTests: [],
};
const out = '.cache/native-render-gap/original/normal-d-review-a.json';
fs.writeFileSync(path.join(root, out), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(pin(out)));
