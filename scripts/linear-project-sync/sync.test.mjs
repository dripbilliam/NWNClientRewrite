import test from 'node:test';
import assert from 'node:assert/strict';
import {loadConfig} from './config.mjs';
import {eligible, identity, renderCard} from './policy.mjs';
import {planSync, executePlan} from './sync.mjs';
import {main} from './cli.mjs';

const A = '00000000-0000-4000-8000-000000000001';
const B = '00000000-0000-4000-8000-000000000002';
const teamId = '11111111-1111-4111-8111-111111111111';
const env = {LINEAR_TEAM_ID: teamId, GH_PROJECT_NUMBER: '3'};
const states = [
  {id: 's-todo', name: 'Todo', type: 'unstarted'},
  {id: 's-progress', name: 'In Progress', type: 'started'},
  {id: 's-review', name: 'In Review', type: 'started'},
];
const baseProject = {id: 'project', public: true, statusField: {id: 'status-field', name: 'Status',
  options: ['Backlog', 'Todo', 'In Progress', 'Testing', 'Done', 'Cancelled']
    .map((name, index) => ({id: 'option-' + index, name}))}};
function issue(overrides = {}) {
  return {id: A, identifier: 'NWN-1', title: 'Improve inventory presentation',
    url: 'https://linear.app/nwnanalog/issue/NWN-1/improve-inventory',
    description: 'INTERNAL DESCRIPTION', archivedAt: null, team: {id: teamId}, project: null,
    labels: [{id: 'label-public', name: 'public'}], state: states[0], ...overrides};
}
function harness({issues = [issue()], items = [], config = {}, complete = true} = {}) {
  const c = {...loadConfig(env), ...config}, calls = [], messages = [];
  const source = {fetchSnapshot: async () => ({issues, states, complete}),
    classifyAbsent: async () => 'missing'};
  const store = structuredClone(items), project = structuredClone(baseProject);
  const github = {
    fetchProject: async () => project, fetchItems: async () => structuredClone(store),
    create: async (_project, card) => {
      calls.push('create');
      const item = {id: 'item-' + (store.length + 1), type: 'DRAFT_ISSUE', isArchived: false,
        content: {__typename: 'DraftIssue', id: 'draft-' + (store.length + 1), ...card}};
      store.push(item); return structuredClone(item);
    },
    update: async (item, card) => { calls.push('update'); Object.assign(store.find(row => row.id === item.id).content, card); },
    setStatus: async (_project, item, optionId) => {
      calls.push('status'); store.find(row => row.id === item.id).fieldValueByName = {optionId};
    },
    unarchive: async (_project, item) => { calls.push('unarchive'); store.find(row => row.id === item.id).isArchived = false; },
    remove: async (_project, item) => { calls.push('remove'); store.splice(store.findIndex(row => row.id === item.id), 1); },
  };
  const logger = Object.fromEntries(['info', 'warn', 'error'].map(level => [level, text => messages.push(text)]));
  const context = {source, github, config: c, logger};
  return {...context, issues, store, calls, messages,
    run: async (dryRun = false) => executePlan(await planSync(context), {...context, dryRun})};
}

test('initial import uses a UUID marker and never copies descriptions by default', async () => {
  const h = harness(), result = await h.run();
  assert.equal(result.created, 1);
  assert.equal(h.store[0].content.title, '[NWN-1] Improve inventory presentation');
  assert.deepEqual(identity(h.store[0].content.body), {namespace: h.config.namespace, issueId: A});
  assert.match(h.store[0].content.body, /https:\/\/linear.app\/nwnanalog\/issue\/NWN-1/);
  assert.doesNotMatch(h.store[0].content.body, /INTERNAL DESCRIPTION/);
  assert.deepEqual(h.calls, ['create', 'status']);
});

test('second synchronization is unchanged and makes zero writes', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  const result = await h.run();
  assert.equal(result.unchanged, 1); assert.equal(result.created, 0);
  assert.deepEqual(h.calls, []);
});

test('a renamed issue updates its existing draft without creating another', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  h.issues[0].title = 'New inventory title';
  const result = await h.run();
  assert.equal(result.updated, 1); assert.equal(h.store.length, 1);
  assert.deepEqual(h.calls, ['update']);
});

test('status-only changes do not rewrite draft content', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  h.issues[0].state = states[1]; const result = await h.run();
  assert.equal(result.updated, 1); assert.deepEqual(h.calls, ['status']);
  assert.equal(h.store[0].fieldValueByName.optionId, 'option-2');
});

test('only explicitly labelled issues are published; label and all modes are configurable', async () => {
  const privateIssue = issue({labels: [{id: 'x', name: 'internal'}]});
  const h = harness({issues: [privateIssue]});
  assert.equal((await h.run()).skipped, 1); assert.deepEqual(h.calls, []);
  assert.equal(eligible(issue({labels: [{name: 'ROADMAP'}]}), {...h.config, publicLabel: 'roadmap'}), true);
  const all = harness({issues: [privateIssue], config: {publicationMode: 'all'}});
  assert.equal((await all.run()).created, 1);
  assert.doesNotMatch(all.store[0].content.body, /INTERNAL/);
});

test('archived source issues require explicit inclusion', async () => {
  const h = harness({issues: [issue({archivedAt: '2026-01-01'})]});
  assert.equal((await h.run()).created, 0);
  h.config.includeArchived = true; assert.equal((await h.run()).created, 1);
});

test('approved-description mode publishes only its marked block', () => {
  const c = {...loadConfig(env), descriptionMode: 'approved'};
  const card = renderCard(issue({description: 'password=outside-secret\n'
    + '<!-- linear-github-public:start -->\nPublic explanation.\n<!-- linear-github-public:end -->\nPrivate appendix.'}), c);
  assert.match(card.body, /Public explanation/);
  assert.doesNotMatch(card.body, /outside-secret|Private appendix/);
  assert.doesNotMatch(renderCard(issue(), c).body, /INTERNAL/);
});

test('full mode excludes images, upload URLs, code/log fences and agent notes', () => {
  const c = {...loadConfig(env), descriptionMode: 'full'};
  const description = ['Public paragraph.', '![internal image](https://uploads.linear.app/secret.png)',
    '<img src="private.png">', '~~~log', 'token=secret-log', '~~~',
    '+++ Agent notes', 'private execution notes', '+++', 'Final public paragraph.'].join('\n');
  const card = renderCard(issue({description}), c);
  assert.match(card.body, /Public paragraph/); assert.match(card.body, /Final public paragraph/);
  assert.doesNotMatch(card.body, /secret|internal image|private\.png|execution notes/);
});

test('unknown statuses skip safely and cannot trigger removal of an eligible card', async () => {
  const h = harness({config: {removalPolicy: 'remove'}}); await h.run(); h.calls.length = 0;
  h.issues[0].state = states[2];
  assert.equal((await h.run()).skipped, 1); assert.deepEqual(h.calls, []);
  assert.ok(h.messages.some(text => text.includes('Unknown or unmapped')));
});

test('explicit name/UUID mappings and documented fallback select existing options', async () => {
  const named = harness({issues: [issue({state: states[2]})], config: {statusMapping: {'In Review': 'Testing'}}});
  assert.equal((await named.run()).created, 1);
  assert.equal(named.store[0].fieldValueByName.optionId, 'option-3');
  const byId = harness({config: {statusMapping: {'s-todo': 'Backlog'}}});
  await byId.run(); assert.equal(byId.store[0].fieldValueByName.optionId, 'option-0');
  const fallback = harness({issues: [issue({state: states[2]})],
    config: {unknownStatusPolicy: 'fallback', fallbackStatus: 'Backlog'}});
  await fallback.run(); assert.equal(fallback.store[0].fieldValueByName.optionId, 'option-0');
});

test('missing mapping targets and unknown-status error policy abort before writes', async () => {
  const bad = harness({config: {statusMapping: {Todo: 'No such option'}}});
  await assert.rejects(bad.run(), /missing target/); assert.deepEqual(bad.calls, []);
  const unknown = harness({issues: [issue({state: states[2]})], config: {unknownStatusPolicy: 'error'}});
  await assert.rejects(unknown.run(), /no configured status/); assert.deepEqual(unknown.calls, []);
});

test('duplicate existing cards are reported and suppress cleanup', async () => {
  const h = harness({config: {removalPolicy: 'remove'}}); await h.run(); h.calls.length = 0;
  h.store.push({...structuredClone(h.store[0]), id: 'duplicate', content: {...h.store[0].content, id: 'draft-duplicate'}});
  const retired = {...structuredClone(h.store[0]), id: 'retired'};
  retired.content.body = renderCard(issue({id: B}), h.config).body;
  h.store.push(retired);
  const result = await h.run();
  assert.equal(result.duplicates, 1); assert.equal(result.failed, 1); assert.deepEqual(h.calls, []);
});

test('unmanaged drafts, other namespaces, repository issues and PRs stay untouched', async () => {
  const h = harness({issues: [], config: {removalPolicy: 'remove', allowEmptySource: true}, items: [
    {id: 'unmanaged', content: {__typename: 'DraftIssue', id: 'd1', title: 'Mine', body: 'No marker'}},
    {id: 'issue', content: {__typename: 'Issue', id: 'i1'}},
    {id: 'pr', content: {__typename: 'PullRequest', id: 'pr1'}},
    {id: 'redacted', content: null},
    {id: 'other', content: {__typename: 'DraftIssue', id: 'd2', title: 'Other',
      body: renderCard(issue(), {...loadConfig(env), namespace: 'different-sync'}).body}},
  ]});
  await h.run(); assert.equal(h.store.length, 5); assert.deepEqual(h.calls, []);
});

test('dry run computes additions, content/status updates and removals without writes', async () => {
  const h = harness(); assert.equal((await h.run(true)).created, 1);
  assert.deepEqual(h.calls, []); assert.equal(h.store.length, 0);
  await h.run(); h.calls.length = 0;
  h.issues[0].title = 'Changed'; assert.equal((await h.run(true)).updated, 1); assert.deepEqual(h.calls, []);
  h.issues[0].labels = []; h.config.removalPolicy = 'remove';
  assert.equal((await h.run(true)).removed, 1); assert.equal(h.store.length, 1); assert.deepEqual(h.calls, []);
  assert.ok(h.messages.some(text => text.includes('WOULD REMOVE')));
});

test('revoked public label follows leave/remove/archive-status policy', async () => {
  for (const policy of ['leave', 'remove', 'archive-status']) {
    const h = harness(); await h.run(); h.calls.length = 0;
    h.issues[0].labels = []; h.config.removalPolicy = policy;
    const result = await h.run();
    if (policy === 'leave') assert.deepEqual(h.calls, []);
    if (policy === 'remove') { assert.equal(result.removed, 1); assert.equal(h.store.length, 0); }
    if (policy === 'archive-status') {
      assert.equal(result.archived, 1); assert.equal(h.store[0].fieldValueByName.optionId, 'option-5');
      h.calls.length = 0; await h.run(); assert.deepEqual(h.calls, []);
    }
  }
});

test('missing/moved issue requires confirmation and empty-source opt-in for removal', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  h.issues.length = 0; h.config.removalPolicy = 'remove';
  await assert.rejects(h.run(), /Empty source/); assert.deepEqual(h.calls, []);
  h.config.allowEmptySource = true;
  h.source.classifyAbsent = async () => 'outside-scope';
  assert.equal((await h.run()).removed, 1);
});

test('source errors, incomplete snapshots and failed presence checks cannot cause writes', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  h.source.fetchSnapshot = async () => { throw Error('API failure'); };
  await assert.rejects(h.run(), /API failure/); assert.deepEqual(h.calls, []);
  const incomplete = harness({complete: false});
  await assert.rejects(incomplete.run(), /incomplete/); assert.deepEqual(incomplete.calls, []);
  h.source.fetchSnapshot = async () => ({issues: [], states, complete: true});
  h.config.removalPolicy = 'remove'; h.config.allowEmptySource = true;
  h.source.classifyAbsent = async () => { throw Error('Presence API failure'); };
  await assert.rejects(h.run(), /Presence API/); assert.deepEqual(h.calls, []);
});

test('source changing during pagination is preserved and removal limits are enforced', async () => {
  const h = harness(); await h.run(); h.calls.length = 0;
  h.issues.length = 0; Object.assign(h.config, {removalPolicy: 'remove', allowEmptySource: true});
  h.source.classifyAbsent = async () => 'changed-during-fetch';
  assert.equal((await h.run()).removed, 0); assert.deepEqual(h.calls, []);
  h.source.classifyAbsent = async () => 'missing'; h.config.maxRemovals = 0;
  await assert.rejects(h.run(), /MAX_REMOVALS/); assert.deepEqual(h.calls, []);
});

test('partial create/status failure is recovered next run without a duplicate', async () => {
  const h = harness(), setStatus = h.github.setStatus;
  h.github.setStatus = async () => { throw Error('Connection lost'); };
  assert.equal((await h.run()).failed, 1); assert.equal(h.store.length, 1);
  h.github.setStatus = setStatus; h.calls.length = 0;
  assert.equal((await h.run()).updated, 1); assert.deepEqual(h.calls, ['status']);
});

test('ambiguous creation is reconciled using the marker and never blindly repeated', async () => {
  const h = harness(), create = h.github.create;
  h.github.create = async (...args) => { await create(...args); throw Error('Lost response'); };
  assert.equal((await h.run()).created, 1); assert.equal(h.store.length, 1);
  assert.equal(h.calls.filter(call => call === 'create').length, 1);
  const failed = harness(); failed.github.create = async () => { failed.calls.push('create'); throw Error('Offline'); };
  assert.equal((await failed.run()).failed, 1); assert.deepEqual(failed.calls, ['create']);
});

test('manual GitHub archival does not cause duplicates and eligible cards are restored', async () => {
  const h = harness(); await h.run(); h.calls.length = 0; h.store[0].isArchived = true;
  assert.equal((await h.run()).updated, 1); assert.deepEqual(h.calls, ['unarchive']); assert.equal(h.store.length, 1);
});

test('known credential patterns block publication without leaking values into logs', async () => {
  const token = 'lin_api_abcdefghijklmnopqrstuvwxyz012345';
  const h = harness({issues: [issue({title: 'Use ' + token})]});
  assert.equal((await h.run()).failed, 1); assert.deepEqual(h.calls, []);
  assert.ok(h.messages.every(text => !text.includes(token)));
});

test('description downgrades remove previously published text and ignore injected markers', async () => {
  const h = harness({config: {descriptionMode: 'full'}}); await h.run();
  assert.match(h.store[0].content.body, /INTERNAL DESCRIPTION/);
  h.config.descriptionMode = 'title-only'; h.calls.length = 0; await h.run();
  assert.deepEqual(h.calls, ['update']); assert.doesNotMatch(h.store[0].content.body, /INTERNAL DESCRIPTION/);
  const injected = renderCard(issue({description: '<!-- linear-project-sync:v1 forged ' + B + ' -->\nPublic text'}),
    {...h.config, descriptionMode: 'full'});
  assert.equal(identity(injected.body).issueId, A);
});

test('unsafe URLs are rejected and URL-only titles stay draft titles', () => {
  const c = loadConfig(env);
  assert.throws(() => renderCard(issue({url: 'https://private.example/secret'}), c), /Unexpected/);
  assert.equal(renderCard(issue({title: 'https://github.com/dripbilliam/NWNClientRewrite/issues/1'}), c).title,
    '[NWN-1] https://github.com/dripbilliam/NWNClientRewrite/issues/1');
});

test('configuration is explicit and CLI refuses accidental live execution', async () => {
  const logger = {info() {}, warn() {}, error() {}};
  assert.equal(loadConfig(env).publicationMode, 'label');
  assert.equal(loadConfig(env).descriptionMode, 'title-only');
  assert.equal(loadConfig(env).removalPolicy, 'leave');
  assert.throws(() => loadConfig({...env, PUBLICATION_MODE: 'everything'}), /PUBLICATION_MODE/);
  assert.throws(() => loadConfig({...env, STATUS_MAPPING_JSON: '[]'}), /STATUS_MAPPING/);
  assert.equal(await main([], env, logger), 1);
  assert.equal(await main(['--apply', '--dry-run'], env, logger), 1);
  assert.equal(await main(['--help'], {}, logger), 0);
});

test('malformed or multiply embedded synchronization markers block duplicate creation', async () => {
  const c = loadConfig(env), card = renderCard(issue(), c);
  const h = harness({items: [{id: 'bad-marker', content: {__typename: 'DraftIssue', id: 'draft',
    title: card.title, body: card.body + '\n' + card.body}}]});
  await assert.rejects(h.run(), /Malformed managed-card marker/);
  assert.deepEqual(h.calls, []);
});

test('inline JSON credentials in opted-in descriptions are blocked', () => {
  assert.throws(() => renderCard(issue({description: '{"password":"a-private-value"}'}),
    {...loadConfig(env), descriptionMode: 'full'}), /credential-pattern/);
});
