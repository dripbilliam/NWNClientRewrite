import {paginate} from './api.mjs';
import {UUID} from './config.mjs';

const pageInfo = 'pageInfo { hasNextPage endCursor }';
const issueFields = [
  'id identifier title url archivedAt team { id } project { id }',
  'state { id name type }',
  'description @include(if: $withDescription)',
  'labels(first: 100) { nodes { id name } ' + pageInfo + ' }',
].join('\n');

export function inScope(issue, config) {
  return (!config.teamId || issue.team?.id === config.teamId)
    && (!config.projectId || issue.project?.id === config.projectId);
}

export class LinearSource {
  constructor(client, config) { this.client = client; this.config = config; }

  async fetchSnapshot() {
    const c = this.config;
    let teamIds = c.teamId ? [c.teamId] : [];
    if (c.teamId) {
      const data = await this.client.request('query SyncTeam($id: String!) { team(id: $id) { id } }', {id: c.teamId});
      if (data.team?.id !== c.teamId) throw Error('Configured Linear team is unavailable.');
    }
    if (c.projectId) {
      const teams = await paginate(async after => {
        const data = await this.client.request(
          'query SyncProjectTeams($id: String!, $first: Int!, $after: String) { project(id: $id) { id teams(first: $first, after: $after) { nodes { id } ' + pageInfo + ' } } }',
          {id: c.projectId, first: c.pageSize, after});
        if (data.project?.id !== c.projectId) throw Error('Configured Linear project is unavailable.');
        return data.project.teams;
      }, {name: 'Linear project teams', maxPages: c.maxPages});
      if (c.teamId && !teams.some(team => team.id === c.teamId)) {
        throw Error('Configured Linear team is not accessible in this project.');
      }
      if (!c.teamId) teamIds = teams.map(team => team.id);
    }
    if (!teamIds.length) throw Error('Linear scope exposes no teams; check access before synchronizing.');
    const states = await paginate(async after => {
      const data = await this.client.request(
        'query SyncStates($filter: WorkflowStateFilter!, $first: Int!, $after: String) { workflowStates(filter: $filter, includeArchived: true, first: $first, after: $after) { nodes { id name type } ' + pageInfo + ' } }',
        {filter: {team: {id: {in: teamIds}}}, first: c.pageSize, after});
      return data.workflowStates;
    }, {name: 'Linear workflow states', maxPages: c.maxPages});
    const filter = {};
    if (c.teamId) filter.team = {id: {eq: c.teamId}};
    if (c.projectId) filter.project = {id: {eq: c.projectId}};
    const issues = await paginate(async after => {
      const data = await this.client.request(
        'query SyncIssues($filter: IssueFilter!, $first: Int!, $after: String, $withDescription: Boolean!) { issues(filter: $filter, includeArchived: true, first: $first, after: $after, orderBy: createdAt) { nodes { ' + issueFields + ' } ' + pageInfo + ' } }',
        {filter, first: c.pageSize, after, withDescription: c.descriptionMode !== 'title-only'});
      return data.issues;
    }, {name: 'Linear issues', maxPages: c.maxPages});
    for (const issue of issues) {
      if (!UUID.test(issue.id) || !inScope(issue, c) || !issue.state?.id
          || typeof issue.title !== 'string' || typeof issue.identifier !== 'string'
          || typeof issue.url !== 'string') {
        throw Error('Incomplete or out-of-scope Linear issue; synchronization aborted.');
      }
      const firstLabels = issue.labels;
      issue.labels = await paginate(async after => {
        if (after === null) return firstLabels;
        const data = await this.client.request(
          'query SyncIssueLabels($id: String!, $first: Int!, $after: String) { issue(id: $id) { labels(first: $first, after: $after) { nodes { id name } ' + pageInfo + ' } } }',
          {id: issue.id, first: c.pageSize, after});
        return data.issue?.labels;
      }, {name: 'Linear issue labels', maxPages: c.maxPages});
      if (issue.labels.some(label => typeof label.name !== 'string')) throw Error('Incomplete Linear label data.');
    }
    return {issues, states, complete: true};
  }

  async classifyAbsent(id) {
    // A second, unscoped, error-free lookup distinguishes a moved ticket from
    // an absent one. An API error is never interpreted as a deletion.
    const rows = await paginate(async after => {
      const data = await this.client.request(
        'query SyncPresence($filter: IssueFilter!, $after: String) { issues(filter: $filter, includeArchived: true, first: 2, after: $after) { nodes { id team { id } project { id } } ' + pageInfo + ' } }',
        {filter: {id: {eq: id}}, after});
      return data.issues;
    }, {name: 'Linear presence check', maxPages: 2});
    if (!rows.length) return 'missing';
    if (rows.length !== 1 || rows[0].id !== id) throw Error('Inconsistent Linear presence check.');
    return inScope(rows[0], this.config) ? 'changed-during-fetch' : 'outside-scope';
  }
}
