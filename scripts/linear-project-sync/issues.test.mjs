import test from 'node:test';
import assert from 'node:assert/strict';
import {loadConfig} from './config.mjs';
import {renderCard, renderIssue, identity} from './policy.mjs';
import {planIssueSync, executeIssuePlan} from './issue-sync.mjs';
import {GithubRepository} from './repository.mjs';
import {GithubProject} from './github.mjs';

const A = '00000000-0000-4000-8000-000000000001';
const B = '00000000-0000-4000-8000-000000000002';
const team = '11111111-1111-4111-8111-111111111111';
const states = [
  {id: 'todo', name: 'Todo', type: 'unstarted'},
  {id: 'progress', name: 'In Progress', type: 'started'},
  {id: 'done', name: 'Done', type: 'completed'},
  {id: 'cancel', name: 'Canceled', type: 'canceled'},
];
const baseEnv = {LINEAR_TEAM_ID: team, GH_PROJECT_NUMBER: '3', SYNC_TARGET: 'issues',
  GH_ISSUE_REPOSITORY: 'dripbilliam/NWNClientRewrite', DESCRIPTION_MODE: 'full', PUBLICATION_MODE: 'all'};
const config = () => loadConfig(baseEnv);
const linearIssue = (extra = {}) => ({id: A, identifier: 'NWN-1', title: 'Improve inventory',
  url: 'https://linear.app/nwnanalog/issue/NWN-1/improve-inventory', description: 'Public acceptance criteria.',
  labels: [], team: {id: team}, state: states[0], ...extra});
const repo = {id: 'REPOSITORY', nameWithOwner: baseEnv.GH_ISSUE_REPOSITORY, hasIssuesEnabled: true, isArchived: false};
const project = {id: 'PROJECT', statusField: {id: 'STATUS', name: 'Status',
  options: states.map(s => ({id: 'option-' + s.id, name: s.name}))}};

function harness({sourceIssues = [linearIssue()], drafts = false} = {}) {
  const c = config(), calls = [], repoIssues = [], items = [], logs = [];
  let nextIssue = 1, nextItem = 1;
  if (drafts) for (const source of sourceIssues) items.push({id: 'draft-' + source.id, isArchived: false,
    content: {__typename: 'DraftIssue', id: 'content-' + source.id, ...renderCard(source, c)},
    fieldValueByName: {optionId: 'old-status'}});
  const source = {fetchSnapshot: async () => ({issues: sourceIssues, states, complete: true}), classifyAbsent: async () => 'missing'};
  const repository = {
    fetchRepository: async () => repo,
    fetchIssues: async () => structuredClone(repoIssues),
    create: async (_repo, card) => {
      calls.push('create'); const value = {id: 'issue-' + nextIssue, number: nextIssue++, title: card.title,
        body: card.body, state: 'OPEN', stateReason: null, repository: {nameWithOwner: repo.nameWithOwner}};
      repoIssues.push(value); return structuredClone(value);
    },
    update: async (issue, card) => {
      calls.push('content'); Object.assign(repoIssues.find(row => row.id === issue.id), {title: card.title, body: card.body});
    },
    setState: async (issue, card) => {
      calls.push('state'); Object.assign(repoIssues.find(row => row.id === issue.id), {state: card.state, stateReason: card.stateReason});
    },
  };
  const github = {
    fetchProject: async () => project,
    fetchItems: async () => structuredClone(items.map(item => {
      const issue = item.content.__typename === 'Issue' && repoIssues.find(row => row.id === item.content.id);
      return issue ? {...item, content: {...issue, __typename: 'Issue'}} : item;
    })),
    addIssue: async (_project, issue) => {
      calls.push('link'); const item = {id: 'linked-' + nextItem++, isArchived: false, content: {...issue, __typename: 'Issue'}};
      items.push(item); return structuredClone(item);
    },
    setStatus: async (_project, item, optionId) => {
      calls.push('status'); items.find(row => row.id === item.id).fieldValueByName = {optionId};
    },
    unarchive: async (_project, item) => { calls.push('unarchive'); items.find(row => row.id === item.id).isArchived = false; },
    remove: async (_project, item) => { calls.push('remove'); items.splice(items.findIndex(row => row.id === item.id), 1); },
  };
  const logger = Object.fromEntries(['info', 'warn', 'error'].map(level => [level, text => logs.push(text)]));
  const context = {source, github, repository, config: c, logger};
  return {...context, sourceIssues, repoIssues, items, calls, logs,
    run: async (dryRun = false) => executeIssuePlan(await planIssueSync(context), {...context, dryRun})};
}

test('migrate drafts into issues, retain columns, keep unrelated issues, and rerun without writes', async () => {
  const h = harness({drafts: true, sourceIssues: [linearIssue(), linearIssue({id: B, identifier: 'NWN-2', state: states[3]})]});
  h.repoIssues.push({id: 'manual', number: 99, title: 'Manual issue', body: 'Discussion', state: 'CLOSED'});
  const result = await h.run();
  assert.equal(result.created, 2); assert.equal(result.migrated, 2); assert.equal(result.linked, 2);
  assert.equal(h.repoIssues.length, 3); assert.equal(h.items.length, 2);
  assert.ok(h.items.every(item => item.content.__typename === 'Issue'));
  assert.equal(h.items[1].fieldValueByName.optionId, 'option-cancel');
  const canceled = h.repoIssues.find(issue => identity(issue.body)?.issueId === B);
  assert.equal(canceled.state, 'CLOSED'); assert.equal(canceled.stateReason, 'NOT_PLANNED');
  assert.match(canceled.body, /Linear status: Canceled/); assert.match(canceled.body, /Public acceptance criteria/);
  assert.equal(h.repoIssues[0].body, 'Discussion');
  h.calls.length = 0;
  assert.equal((await h.run()).unchanged, 2); assert.deepEqual(h.calls, []);
});

test('Linear content and completed/canceled/reopened states update the same issue number', async () => {
  const h = harness(); await h.run(); const number = h.repoIssues[0].number;
  h.sourceIssues[0].title = 'Renamed inventory'; h.sourceIssues[0].description = 'Updated requirements.';
  for (const [state, expected, reason] of [[states[2], 'CLOSED', 'COMPLETED'], [states[3], 'CLOSED', 'NOT_PLANNED'], [states[1], 'OPEN', null]]) {
    h.sourceIssues[0].state = state; h.calls.length = 0;
    assert.equal((await h.run()).updated, 1); assert.equal(h.repoIssues[0].number, number);
    assert.equal(h.repoIssues[0].state, expected); assert.equal(h.repoIssues[0].stateReason, reason);
    assert.match(h.repoIssues[0].body, /Updated requirements/); assert.match(h.repoIssues[0].body, new RegExp('Linear status: ' + state.name));
    assert.deepEqual(h.calls, ['content', 'state', 'status']);
  }
});

test('orphaned and closed managed issues are reused, including after board item removal', async () => {
  const h = harness(); await h.run(); h.items.length = 0; h.calls.length = 0;
  assert.equal((await h.run()).updated, 1); assert.deepEqual(h.calls, ['link', 'status']);
  assert.equal(h.repoIssues.length, 1);
  h.items[0].isArchived = true; h.calls.length = 0;
  await h.run(); assert.deepEqual(h.calls, ['unarchive']);
});

test('a lost issue-create response or project-link response never creates duplicates', async () => {
  for (const method of ['create', 'addIssue']) {
    const h = harness({drafts: true}), owner = method === 'create' ? h.repository : h.github, original = owner[method];
    owner[method] = async (...args) => { await original(...args); throw Error('Response lost'); };
    assert.equal((await h.run()).failed, 0); assert.equal(h.repoIssues.length, 1); assert.equal(h.items.length, 1);
    assert.equal(h.calls.filter(x => x === 'create').length, 1); assert.equal(h.calls.filter(x => x === 'link').length, 1);
  }
});

test('failed status or draft retirement is resumed safely without recreating the issue', async () => {
  for (const method of ['setStatus', 'remove']) {
    const h = harness({drafts: true}), original = h.github[method];
    h.github[method] = async () => { throw Error('Write failed'); };
    assert.equal((await h.run()).failed, 1); assert.equal(h.repoIssues.length, 1);
    assert.ok(h.items.some(item => item.content.__typename === 'DraftIssue'));
    h.github[method] = original; h.calls.length = 0;
    assert.equal((await h.run()).failed, 0); assert.equal(h.repoIssues.length, 1); assert.equal(h.items.length, 1);
    assert.ok(!h.calls.includes('create'));
  }
});

test('failed state/link writes preserve the old draft and stop further issue creation', async () => {
  for (const method of ['setState', 'addIssue']) {
    const h = harness({drafts: true, sourceIssues: [linearIssue({state: states[2]}), linearIssue({id: B, identifier: 'NWN-2'})]});
    const owner = method === 'setState' ? h.repository : h.github;
    owner[method] = async () => { throw Error('Write failed'); };
    assert.equal((await h.run()).failed, 1); assert.equal(h.repoIssues.length, 1);
    assert.equal(h.items.filter(item => item.content.__typename === 'DraftIssue').length, 2);
    assert.ok(!h.calls.includes('remove'));
  }
});

test('blocked descriptions and unknown workflow states preserve existing drafts', async () => {
  const h = harness({drafts: true});
  h.sourceIssues[0].description = 'password=an-example-sensitive-value';
  assert.equal((await h.run()).failed, 1); assert.deepEqual(h.calls, []); assert.equal(h.items.length, 1);
  h.sourceIssues[0].description = ''; h.sourceIssues[0].state = {id: 'unknown', name: 'New state', type: 'started'};
  assert.equal((await h.run()).skipped, 1); assert.deepEqual(h.calls, []);
});

test('malformed/duplicate identities and cross-repository board issues never get adopted', async () => {
  const malformed = harness(); malformed.repoIssues.push({id: 'bad', body: '<!-- linear-project-sync:broken -->'});
  await assert.rejects(malformed.run(), /Malformed/); assert.deepEqual(malformed.calls, []);
  const duplicate = harness(); await duplicate.run(); duplicate.calls.length = 0;
  duplicate.repoIssues.push({...duplicate.repoIssues[0], id: 'copy'});
  assert.equal((await duplicate.run()).duplicates, 1); assert.deepEqual(duplicate.calls, []);
  const other = harness(); other.items.push({id: 'foreign', content: {__typename: 'Issue', id: 'foreign',
    ...renderIssue(linearIssue(), config()), repository: {nameWithOwner: 'other/repo'}}});
  await assert.rejects(other.run(), /another repository/); assert.deepEqual(other.calls, []);
  other.items[0].content.repository.nameWithOwner = repo.nameWithOwner;
  await assert.rejects(other.run(), /missing from the complete repository inventory/);
});

test('incomplete source/repository fetches cannot publish or retire drafts', async () => {
  const h = harness({drafts: true}); h.source.fetchSnapshot = async () => ({complete: false});
  await assert.rejects(h.run(), /incomplete/); assert.deepEqual(h.calls, []);
  const failed = harness({drafts: true}); failed.repository.fetchIssues = async () => { throw Error('Later page failed'); };
  await assert.rejects(failed.run(), /Later page/); assert.deepEqual(failed.calls, []);
});

test('readonly planning covers migration and retirement without mutating either destination', async () => {
  const h = harness({drafts: true}); const result = await h.run(true);
  assert.equal(result.created, 1); assert.equal(result.migrated, 1); assert.deepEqual(h.calls, []); assert.equal(h.repoIssues.length, 0);
  await h.run(); h.sourceIssues.length = 0; h.config.removalPolicy = 'remove'; h.config.allowEmptySource = true;
  h.calls.length = 0; assert.equal((await h.run(true)).removed, 1); assert.deepEqual(h.calls, []);
  assert.equal((await h.run()).removed, 1); assert.equal(h.repoIssues.length, 1); // Never delete repository issues.
});

test('issue-mode configuration requires a repository and does not change draft-mode defaults', () => {
  assert.equal(loadConfig({LINEAR_TEAM_ID: team, GH_PROJECT_NUMBER: '3'}).target, 'drafts');
  assert.throws(() => loadConfig({...baseEnv, GH_ISSUE_REPOSITORY: ''}), /GH_ISSUE_REPOSITORY/);
  assert.throws(() => loadConfig({...baseEnv, GH_ISSUE_REPOSITORY: 'owner/repo/extra'}), /GH_ISSUE_REPOSITORY/);
});

test('bare CD-key-shaped strings cannot be published in issue titles or descriptions', () => {
  const fixture = Array(7).fill('ABCDE').join('-');
  for (const extra of [{title: fixture}, {description: 'Do not publish ' + fixture}]) {
    assert.throws(() => renderIssue(linearIssue(extra), config()), /credential-pattern/);
  }
});

test('repository adapter paginates open and closed issues and confirms issue-specific mutations', async () => {
  const calls = [], response = {id: 'I', number: 1, title: 'Public', body: 'Body', state: 'OPEN', repository: {nameWithOwner: repo.nameWithOwner}};
  const repository = new GithubRepository({request: async (query, variables, options) => {
    calls.push({query, variables, options});
    if (query.includes('SyncRepository(')) return {repository: repo};
    if (query.includes('SyncRepositoryIssues(')) {
      assert.match(query, /states: \[OPEN, CLOSED\]/);
      return {node: {issues: {totalCount: 2, nodes: [{...response, id: variables.after ? 'I2' : 'I1'}],
        pageInfo: {hasNextPage: !variables.after, endCursor: variables.after ? null : 'next'}}}};
    }
    if (query.includes('SyncCreateIssue(')) return {createIssue: {issue: response}};
    if (query.includes('SyncUpdateIssue(')) return {updateIssue: {issue: {id: 'I'}}};
    if (query.includes('reopenIssue(')) return {reopenIssue: {issue: {id: 'I', state: 'OPEN', stateReason: null}}};
    if (query.includes('closeIssue(')) return {closeIssue: {issue: {id: 'I', state: 'CLOSED', stateReason: variables.input.stateReason}}};
    throw Error('Unexpected query');
  }}, config());
  await repository.fetchRepository(); assert.equal((await repository.fetchIssues(repo)).length, 2);
  await repository.create(repo, response); await repository.update(response, response);
  await repository.setState(response, {state: 'CLOSED', stateReason: 'NOT_PLANNED'});
  await repository.setState(response, {state: 'OPEN', stateReason: null});
  assert.ok(calls.slice(3).every(call => call.options.mutation));
  assert.deepEqual(calls.find(call => call.query.includes('SyncCreateIssue(')).variables.input,
    {repositoryId: repo.id, title: response.title, body: response.body});
  assert.equal(calls.find(call => call.query.includes('closeIssue(')).variables.input.stateReason, 'NOT_PLANNED');
});

test('repository close-reason changes use a confirmed reopen/close if required', async () => {
  const calls = [];
  const repository = new GithubRepository({request: async query => {
    const field = query.includes('reopenIssue(') ? 'reopenIssue' : 'closeIssue'; calls.push(field);
    return {[field]: {issue: {id: 'I', state: field === 'reopenIssue' ? 'OPEN' : 'CLOSED',
      stateReason: calls.length === 1 ? 'COMPLETED' : field === 'closeIssue' ? 'NOT_PLANNED' : null}}};
  }}, config());
  await repository.setState({id: 'I'}, {state: 'CLOSED', stateReason: 'NOT_PLANNED'});
  assert.deepEqual(calls, ['closeIssue', 'reopenIssue', 'closeIssue']);
});

test('changing a closed issue from completed to canceled works when redundant closes are rejected', async () => {
  let state = 'CLOSED'; const calls = [];
  const repository = new GithubRepository({request: async (query, variables) => {
    const field = query.includes('reopenIssue(') ? 'reopenIssue' : 'closeIssue'; calls.push(field);
    if (field === 'closeIssue' && state === 'CLOSED') throw Error('Already closed');
    state = field === 'reopenIssue' ? 'OPEN' : 'CLOSED';
    return {[field]: {issue: {id: 'I', state, stateReason: state === 'CLOSED' ? variables.input.stateReason : null}}};
  }}, config());
  await repository.setState({id: 'I', state: 'CLOSED', stateReason: 'COMPLETED'}, {state: 'CLOSED', stateReason: 'NOT_PLANNED'});
  assert.deepEqual(calls, ['reopenIssue', 'closeIssue']);
});

test('repository inventories reject incomplete issue bodies instead of duplicating a hidden marker', async () => {
  const repository = new GithubRepository({request: async () => ({node: {issues: {
    nodes: [{id: 'I', number: 1, title: 'Existing', state: 'OPEN', repository: {nameWithOwner: repo.nameWithOwner}}],
    pageInfo: {hasNextPage: false, endCursor: null}, totalCount: 1}}})}, config());
  await assert.rejects(repository.fetchIssues(repo), /Incomplete GitHub repository issue inventory/);
});

test('project links use issue content IDs and validate the returned Issue', async () => {
  const github = new GithubProject({request: async (query, variables, options) => {
    assert.match(query, /addProjectV2ItemById/); assert.equal(options.mutation, true);
    assert.deepEqual(variables.input, {projectId: 'PROJECT', contentId: 'I'});
    return {addProjectV2ItemById: {item: {id: 'ITEM', content: {__typename: 'Issue', id: 'I'}}}};
  }}, config());
  assert.equal((await github.addIssue(project, {id: 'I'})).id, 'ITEM');
});
