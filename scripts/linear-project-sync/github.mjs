import {paginate} from './api.mjs';

const pageInfo = 'pageInfo { hasNextPage endCursor }';

export class GithubProject {
  constructor(client, config) { this.client = client; this.config = config; }

  async fetchProject() {
    const c = this.config, root = c.ownerType === 'organization' ? 'organization' : 'user';
    const data = await this.client.request(
      'query SyncProject($owner: String!, $number: Int!) { ' + root + '(login: $owner) { projectV2(number: $number) { id url public closed } } }',
      {owner: c.owner, number: c.projectNumber});
    const project = data[root]?.projectV2;
    if (!project?.id) throw Error('GitHub Project unavailable; check owner type, number and token access.');
    if (project.closed) throw Error('GitHub Project is closed.');
    if (c.requirePublicProject && project.public !== true) throw Error('GitHub Project must be public; visibility is never changed automatically.');
    const fields = await paginate(async after => {
      const result = await this.client.request(
        'query SyncFields($id: ID!, $first: Int!, $after: String) { node(id: $id) { ... on ProjectV2 { fields(first: $first, after: $after) { nodes { __typename ... on ProjectV2FieldCommon { id name } ... on ProjectV2SingleSelectField { options { id name } } } ' + pageInfo + ' } } } }',
        {id: project.id, first: c.pageSize, after});
      return result.node?.fields;
    }, {name: 'GitHub project fields', maxPages: c.maxPages});
    const matches = fields.filter(field => field.name?.toLowerCase() === c.statusField.toLowerCase());
    if (matches.length !== 1 || matches[0].__typename !== 'ProjectV2SingleSelectField'
        || !Array.isArray(matches[0].options) || !matches[0].options.length
        || matches[0].options.some(option => !option.id || !option.name)) {
      throw Error('Configure a unique GitHub single-select status field and its options; fields are not created automatically.');
    }
    return {...project, statusField: matches[0]};
  }

  async fetchItems(project) {
    const c = this.config;
    return paginate(async after => {
      const data = await this.client.request(
        'query SyncItems($id: ID!, $first: Int!, $after: String, $statusName: String!) { node(id: $id) { ... on ProjectV2 { items(first: $first, after: $after, archivedStates: [ARCHIVED, NOT_ARCHIVED]) { totalCount nodes { id type isArchived content { __typename ... on DraftIssue { id title body } } fieldValueByName(name: $statusName) { ... on ProjectV2ItemFieldSingleSelectValue { optionId } } } ' + pageInfo + ' } } } }',
        {id: project.id, first: c.pageSize, after, statusName: project.statusField.name});
      return data.node?.items;
    }, {name: 'GitHub project items', maxPages: c.maxPages});
  }

  async create(project, card) {
    const data = await this.client.request(
      'mutation SyncCreate($input: AddProjectV2DraftIssueInput!) { addProjectV2DraftIssue(input: $input) { projectItem { id content { __typename ... on DraftIssue { id title body } } } } }',
      {input: {projectId: project.id, title: card.title, body: card.body}}, {mutation: true});
    const item = data.addProjectV2DraftIssue?.projectItem;
    if (!item?.id || item.content?.__typename !== 'DraftIssue' || !item.content.id) {
      throw Error('Draft creation returned an incomplete result; reconcile before retrying.');
    }
    return item;
  }

  async update(item, card) {
    const data = await this.client.request(
      'mutation SyncUpdate($input: UpdateProjectV2DraftIssueInput!) { updateProjectV2DraftIssue(input: $input) { draftIssue { id } } }',
      {input: {draftIssueId: item.content.id, title: card.title, body: card.body}}, {mutation: true});
    if (data.updateProjectV2DraftIssue?.draftIssue?.id !== item.content.id) throw Error('Draft update was not confirmed.');
  }

  async setStatus(project, item, optionId) {
    const data = await this.client.request(
      'mutation SyncStatus($input: UpdateProjectV2ItemFieldValueInput!) { updateProjectV2ItemFieldValue(input: $input) { projectV2Item { id } } }',
      {input: {projectId: project.id, itemId: item.id, fieldId: project.statusField.id,
        value: {singleSelectOptionId: optionId}}}, {mutation: true});
    if (data.updateProjectV2ItemFieldValue?.projectV2Item?.id !== item.id) throw Error('Status update was not confirmed.');
  }

  async unarchive(project, item) {
    const data = await this.client.request(
      'mutation SyncUnarchive($input: UnarchiveProjectV2ItemInput!) { unarchiveProjectV2Item(input: $input) { item { id } } }',
      {input: {projectId: project.id, itemId: item.id}}, {mutation: true});
    if (data.unarchiveProjectV2Item?.item?.id !== item.id) throw Error('Unarchive was not confirmed.');
  }

  async remove(project, item) {
    const data = await this.client.request(
      'mutation SyncRemove($input: DeleteProjectV2ItemInput!) { deleteProjectV2Item(input: $input) { deletedItemId } }',
      {input: {projectId: project.id, itemId: item.id}}, {mutation: true});
    if (data.deleteProjectV2Item?.deletedItemId !== item.id) throw Error('Project item removal was not confirmed.');
  }
}
