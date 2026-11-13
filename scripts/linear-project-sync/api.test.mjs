import test from 'node:test';
import assert from 'node:assert/strict';
import {createGraphqlClient, paginate} from './api.mjs';
import {loadConfig} from './config.mjs';
import {LinearSource} from './linear.mjs';
import {GithubProject} from './github.mjs';
import {main} from './cli.mjs';

const teamId = '11111111-1111-4111-8111-111111111111';
const projectId = '22222222-2222-4222-8222-222222222222';
const issueId = '33333333-3333-4333-8333-333333333333';
const config = () => loadConfig({LINEAR_TEAM_ID: teamId, GH_PROJECT_NUMBER: '3'});
const page = (nodes, next = false, endCursor = null) => ({nodes, pageInfo: {hasNextPage: next, endCursor}});
const response = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), {status, headers});
const logger = {info() {}, warn() {}, error() {}};

test('pagination imports every page, not merely the first API response', async () => {
  const seen = [];
  const result = await paginate(async cursor => {
    seen.push(cursor);
    return cursor === null ? page([{id: 'one'}], true, 'c1')
      : cursor === 'c1' ? page([{id: 'two'}], true, 'c2') : page([{id: 'three'}]);
  }, {name: 'test'});
  assert.deepEqual(result.map(row => row.id), ['one', 'two', 'three']);
  assert.deepEqual(seen, [null, 'c1', 'c2']);
});

test('pagination rejects missing page info, truncated totals, duplicate IDs and cursor loops', async () => {
  await assert.rejects(paginate(async () => ({nodes: []}), {name: 'test'}), /Incomplete/);
  await assert.rejects(paginate(async () => ({...page([{id: 'a'}]), totalCount: 2}), {name: 'test'}), /Truncated/);
  await assert.rejects(paginate(async () => page([{id: 'a'}], true, 'c1'), {name: 'test'}), /Duplicate result/);
  await assert.rejects(paginate(async cursor => page([{id: cursor || 'a'}], true, 'c1'), {name: 'test'}), /Invalid cursor/);
  await assert.rejects(paginate(async () => page([], true, 'c1'), {name: 'test'}), /Invalid cursor/);
});

test('a later page failure propagates rather than returning a partial list', async () => {
  await assert.rejects(paginate(async cursor => {
    if (cursor) throw Error('Second page failed');
    return page([{id: 'one'}], true, 'c1');
  }, {name: 'test'}), /Second page failed/);
});

test('GitHub total count changes and bounded page limits abort safely', async () => {
  await assert.rejects(paginate(async cursor => ({...page([{id: cursor || 'a'}], !cursor, cursor ? null : 'b'),
    totalCount: cursor ? 3 : 2}), {name: 'test'}), /changed during pagination/);
  await assert.rejects(paginate(async () => page([{id: 'a'}], true, 'c'), {name: 'test', maxPages: 1}), /MAX_PAGES/);
});

test('HTTP rate limits and transient query failures are retried with provider delays', async () => {
  const waits = []; let calls = 0;
  const client = createGraphqlClient({service: 'Linear', token: 'test-key', config: config(), logger,
    sleep: async ms => waits.push(ms),
    fetchImpl: async () => ++calls === 1 ? response({errors: [{extensions: {code: 'RATELIMITED'}}]}, 429, {'retry-after': '2'})
      : calls === 2 ? response({errors: []}, 503) : response({data: {ok: true}})});
  assert.deepEqual(await client.request('query Test { viewer { id } }'), {ok: true});
  assert.equal(calls, 3); assert.deepEqual(waits, [2000, 2000]);
});

test('network errors retry queries while authentication failures do not', async () => {
  let calls = 0;
  const client = createGraphqlClient({service: 'GitHub', token: 'test-key', config: config(), logger,
    sleep: async () => {}, fetchImpl: async () => {
      if (++calls === 1) throw Error('network');
      return response({data: {ok: true}});
    }});
  await client.request('query Test { viewer { login } }'); assert.equal(calls, 2);
  calls = 0;
  const denied = createGraphqlClient({service: 'GitHub', token: 'test-key', config: config(), logger,
    sleep: async () => {}, fetchImpl: async () => { calls++; return response({message: 'denied'}, 401); }});
  await assert.rejects(denied.request('query Test { viewer { login } }'), /credential/);
  assert.equal(calls, 1);
});

test('GraphQL errors reject even partial 200 responses and redact provider details', async () => {
  const forbidden = 'SECRET_PROVIDER_PAYLOAD';
  const client = createGraphqlClient({service: 'Linear', token: 'test-key', config: config(), logger,
    fetchImpl: async () => response({data: {issues: page([])}, errors: [{message: forbidden}]})});
  await assert.rejects(client.request('query Test { issues { nodes { id } } }'), error => {
    assert.doesNotMatch(error.message, new RegExp(forbidden)); return true;
  });
});

test('long reset windows fail cleanly instead of sleeping past workflow limits', async () => {
  let waited = false;
  const client = createGraphqlClient({service: 'GitHub', token: 'test-key', config: config(), logger,
    sleep: async () => { waited = true; },
    fetchImpl: async () => response({errors: [{type: 'RATE_LIMITED'}]}, 403, {'retry-after': '3600'})});
  await assert.rejects(client.request('query Test { viewer { login } }'), /API error/);
  assert.equal(waited, false);
});

test('mutations are never blindly retried after timeout, 5xx or rate-limit response', async () => {
  for (const failure of ['network', 'server', 'rate']) {
    let calls = 0;
    const client = createGraphqlClient({service: 'GitHub', token: 'test-key', config: config(), logger,
      sleep: async () => { throw Error('Unexpected retry'); },
      fetchImpl: async () => {
        calls++;
        if (failure === 'network') throw Error('lost reply');
        return response({errors: [{type: 'RATE_LIMITED'}]}, failure === 'rate' ? 429 : 503);
      }});
    await assert.rejects(client.request('mutation Test { ignored }'), /API error/);
    assert.equal(calls, 1);
  }
});

test('read-only transports reject mutations before making any HTTP request', async () => {
  for (const service of ['Linear', 'GitHub']) {
    let calls = 0;
    const client = createGraphqlClient({service, token: 'test-key', config: config(), readOnly: true,
      fetchImpl: async () => { calls++; return response({data: {}}); }});
    await assert.rejects(client.request('mutation Test { ignored }'), /Read-only/);
    await assert.rejects(client.request('query Test { ignored }', {}, {mutation: true}), /Read-only/);
    assert.equal(calls, 0);
  }
});

test('Linear uses raw API-key auth; GitHub uses bearer auth and rejects redirects', async () => {
  for (const service of ['Linear', 'GitHub']) {
    const client = createGraphqlClient({service, token: 'test-key', config: config(),
      fetchImpl: async (url, options) => {
        assert.equal(options.headers.Authorization, service === 'Linear' ? 'test-key' : 'Bearer test-key');
        assert.equal(options.redirect, 'error');
        assert.equal(url, service === 'Linear' ? 'https://api.linear.app/graphql' : 'https://api.github.com/graphql');
        return response({data: {ok: true}});
      }});
    await client.request('query Test { ignored }');
  }
});

function linearIssue(overrides = {}) {
  return {id: issueId, title: 'Public title', identifier: 'NWN-1',
    url: 'https://linear.app/nwnanalog/issue/NWN-1/title', archivedAt: null,
    team: {id: teamId}, project: null, state: {id: 'todo', name: 'Todo', type: 'unstarted'},
    labels: page([{id: 'internal', name: 'internal'}], true, 'label-cursor'), ...overrides};
}

test('source reads all issue/label pages, discovers real statuses and omits private descriptions', async () => {
  const seen = [];
  const client = {request: async (query, variables) => {
    seen.push({query, variables}); assert.doesNotMatch(query, /\bmutation\b/);
    assert.doesNotMatch(query, /\bcomments\b|\battachments\b|\bassignee\b/);
    if (query.includes('SyncTeam')) return {team: {id: teamId}};
    if (query.includes('SyncStates')) return {workflowStates: page([{id: 'todo', name: 'Todo', type: 'unstarted'}])};
    if (query.includes('SyncIssueLabels')) return {issue: {labels: page([{id: 'pub', name: 'public'}])}};
    if (query.includes('SyncIssues')) {
      assert.equal(variables.withDescription, false);
      assert.deepEqual(variables.filter, {team: {id: {eq: teamId}}});
      assert.match(query, /includeArchived: true/); assert.doesNotMatch(query, /createdAt:\s*\{/);
      assert.match(query, /orderBy: createdAt/);
      return {issues: variables.after ? page([linearIssue({id: '44444444-4444-4444-8444-444444444444'})])
        : page([linearIssue()], true, 'issue-cursor')};
    }
    throw Error('Unexpected query');
  }};
  const snapshot = await new LinearSource(client, config()).fetchSnapshot();
  assert.equal(snapshot.complete, true); assert.equal(snapshot.issues.length, 2);
  assert.deepEqual(snapshot.issues[0].labels.map(label => label.name), ['internal', 'public']);
  assert.ok(seen.some(row => row.query.includes('SyncStates')));
});

test('project-only scope discovers all project teams and paginates their workflow states', async () => {
  const c = loadConfig({LINEAR_PROJECT_ID: projectId, GH_PROJECT_NUMBER: '3'});
  const secondTeam = '55555555-5555-4555-8555-555555555555';
  const client = {request: async (query, variables) => {
    if (query.includes('SyncProjectTeams')) return {project: {id: projectId,
      teams: variables.after ? page([{id: secondTeam}]) : page([{id: teamId}], true, 'teams-cursor')}};
    if (query.includes('SyncStates')) {
      assert.deepEqual(variables.filter.team.id.in, [teamId, secondTeam]);
      return {workflowStates: variables.after ? page([{id: 'done', name: 'Done', type: 'completed'}])
        : page([{id: 'todo', name: 'Todo', type: 'unstarted'}], true, 'states-cursor')};
    }
    if (query.includes('SyncIssues')) {
      assert.deepEqual(variables.filter, {project: {id: {eq: projectId}}});
      return {issues: page([])};
    }
    throw Error('Unexpected query');
  }};
  const snapshot = await new LinearSource(client, c).fetchSnapshot();
  assert.equal(snapshot.states.length, 2); assert.deepEqual(snapshot.issues, []);
});

test('source rejects truncated nested labels instead of treating them as nonpublic', async () => {
  const client = {request: async query => {
    if (query.includes('SyncTeam')) return {team: {id: teamId}};
    if (query.includes('SyncStates')) return {workflowStates: page([])};
    if (query.includes('SyncIssues')) return {issues: page([linearIssue({labels: {nodes: []}})])};
    throw Error('Unexpected query');
  }};
  await assert.rejects(new LinearSource(client, config()).fetchSnapshot(), /Incomplete/);
});

test('absence checks distinguish missing, outside scope, concurrent change and API failure', async () => {
  for (const [rows, expected] of [
    [[], 'missing'],
    [[{id: issueId, team: {id: 'different'}, project: null}], 'outside-scope'],
    [[{id: issueId, team: {id: teamId}, project: null}], 'changed-during-fetch'],
  ]) {
    const source = new LinearSource({request: async () => ({issues: page(rows)})}, config());
    assert.equal(await source.classifyAbsent(issueId), expected);
  }
  await assert.rejects(new LinearSource({request: async () => { throw Error('API failed'); }}, config()).classifyAbsent(issueId), /API failed/);
});

test('GitHub fields/items paginate, include archived cards and read status directly by name', async () => {
  const calls = [];
  const adapter = new GithubProject({request: async (query, variables) => {
    calls.push({query, variables});
    if (query.includes('SyncProject(')) return {user: {projectV2: {id: 'p', public: true, closed: false}}};
    if (query.includes('SyncFields')) return {node: {fields: variables.after
      ? page([{id: 'status', name: 'Status', __typename: 'ProjectV2SingleSelectField', options: [{id: 'todo', name: 'Todo'}]}])
      : page([{id: 'title', name: 'Title', __typename: 'ProjectV2Field'}], true, 'fields-cursor')}};
    if (query.includes('SyncItems')) {
      assert.match(query, /archivedStates: \[ARCHIVED, NOT_ARCHIVED\]/);
      assert.match(query, /fieldValueByName/); assert.equal(variables.statusName, 'Status');
      return {node: {items: {...(variables.after ? page([{id: 'two', isArchived: true}]) : page([{id: 'one'}], true, 'items-cursor')),
        totalCount: 2}}};
    }
    throw Error('Unexpected query');
  }}, config());
  const project = await adapter.fetchProject();
  assert.equal((await adapter.fetchItems(project)).length, 2);
  assert.equal(calls.length, 5);
});

test('a missing/private project and renamed/missing status field fail before mutations', async () => {
  const missing = new GithubProject({request: async () => ({user: {projectV2: null}})}, config());
  await assert.rejects(missing.fetchProject(), /unavailable/);
  const privateProject = new GithubProject({request: async () => ({user: {projectV2: {id: 'p', public: false}}})}, config());
  await assert.rejects(privateProject.fetchProject(), /must be public/);
  const noStatus = new GithubProject({request: async query => query.includes('SyncProject(')
    ? {user: {projectV2: {id: 'p', public: true}}} : {node: {fields: page([])}}}, config());
  await assert.rejects(noStatus.fetchProject(), /single-select status/);
});

test('draft updates use DraftIssue IDs; statuses/removals use ProjectV2Item IDs', async () => {
  const calls = [], item = {id: 'ITEM-ID', content: {id: 'DRAFT-ID'}};
  const adapter = new GithubProject({request: async (query, variables, options) => {
    assert.equal(options.mutation, true); calls.push({query, variables});
    if (query.includes('SyncUpdate')) return {updateProjectV2DraftIssue: {draftIssue: {id: 'DRAFT-ID'}}};
    if (query.includes('SyncStatus')) return {updateProjectV2ItemFieldValue: {projectV2Item: {id: 'ITEM-ID'}}};
    if (query.includes('SyncRemove')) return {deleteProjectV2Item: {deletedItemId: 'ITEM-ID'}};
    throw Error('Unexpected mutation');
  }}, config());
  const project = {id: 'PROJECT-ID', statusField: {id: 'FIELD-ID'}};
  await adapter.update(item, {title: 'Public', body: 'Body'});
  await adapter.setStatus(project, item, 'OPTION-ID');
  await adapter.remove(project, item);
  assert.equal(calls[0].variables.input.draftIssueId, 'DRAFT-ID');
  assert.deepEqual(calls[1].variables.input, {projectId: 'PROJECT-ID', itemId: 'ITEM-ID', fieldId: 'FIELD-ID',
    value: {singleSelectOptionId: 'OPTION-ID'}});
  assert.equal(calls[2].variables.input.itemId, 'ITEM-ID');
  assert.ok(calls.every(call => !/\bcreateIssue\b|\baddProjectV2ItemById\b/.test(call.query)));
});

test('HTML authentication errors fail once and never log the response body', async () => {
  let calls = 0;
  const client = createGraphqlClient({service: 'GitHub', token: 'test-key', config: config(), logger,
    sleep: async () => { throw Error('Unexpected retry'); },
    fetchImpl: async () => { calls++; return new Response('<h1>PRIVATE ERROR</h1>', {status: 401}); }});
  await assert.rejects(client.request('query Test { viewer { login } }'), error => {
    assert.match(error.message, /credential/); assert.doesNotMatch(error.message, /PRIVATE ERROR/); return true;
  });
  assert.equal(calls, 1);
});

test('CLI dry run performs the complete read-only pipeline with mocked HTTP', async () => {
  const originalFetch = globalThis.fetch, requests = [], logs = [];
  globalThis.fetch = async (url, options) => {
    const {query, variables} = JSON.parse(options.body); requests.push({url, query, variables});
    assert.doesNotMatch(query, /^\s*mutation/);
    if (query.includes('SyncTeam')) return response({data: {team: {id: teamId}}});
    if (query.includes('SyncStates')) return response({data: {workflowStates: page([{id: 'todo', name: 'Todo', type: 'unstarted'}])}});
    if (query.includes('SyncIssues')) return response({data: {issues: page([linearIssue({labels: page([{id: 'public', name: 'public'}])})])}});
    if (query.includes('SyncProject(')) return response({data: {user: {projectV2: {id: 'p', public: true, closed: false}}}});
    if (query.includes('SyncFields')) return response({data: {node: {fields: page([{id: 'status', name: 'Status',
      __typename: 'ProjectV2SingleSelectField', options: [{id: 'todo', name: 'Todo'}]}])}}});
    if (query.includes('SyncItems')) return response({data: {node: {items: {...page([]), totalCount: 0}}}});
    throw Error('Unexpected request');
  };
  try {
    const result = await main(['--dry-run', '--verbose'], {LINEAR_TEAM_ID: teamId, GH_PROJECT_NUMBER: '3',
      LINEAR_API_KEY: 'unit-test-linear-key', GH_PROJECT_TOKEN: 'unit-test-github-key'},
    Object.fromEntries(['info', 'warn', 'error'].map(level => [level, text => logs.push(text)])));
    assert.equal(result, 0); assert.equal(requests.length, 6);
    assert.ok(logs.some(text => text.includes('WOULD CREATE NWN-1 -> Todo')));
    assert.ok(logs.some(text => text.includes('"created":1')));
  } finally { globalThis.fetch = originalFetch; }
});

test('draft creation and unarchival use the verified project-specific mutations', async () => {
  const calls = [];
  const adapter = new GithubProject({request: async (query, variables, options) => {
    calls.push({query, variables}); assert.equal(options.mutation, true);
    if (query.includes('SyncCreate')) return {addProjectV2DraftIssue: {projectItem: {id: 'ITEM',
      content: {__typename: 'DraftIssue', id: 'DRAFT', title: variables.input.title, body: variables.input.body}}}};
    if (query.includes('SyncUnarchive')) return {unarchiveProjectV2Item: {item: {id: 'ITEM'}}};
    throw Error('Unexpected mutation');
  }}, config());
  const item = await adapter.create({id: 'PROJECT'}, {title: '[NWN-1] Public title', body: 'Public body'});
  assert.equal(item.content.id, 'DRAFT');
  assert.equal(calls[0].variables.input.projectId, 'PROJECT');
  await adapter.unarchive({id: 'PROJECT'}, item);
  assert.deepEqual(calls[1].variables.input, {projectId: 'PROJECT', itemId: 'ITEM'});
});
