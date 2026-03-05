import {mount} from '@vue/test-utils';
import {describe, it, expect, beforeEach} from 'vitest';
import {createPinia, setActivePinia} from 'pinia';
import SubmissionBuildSummary from './SubmissionBuildSummary.vue';
import {useConfigStore} from '@/stores/config';

describe('SubmissionBuildSummary.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    const configStore = useConfigStore();
    configStore.openqaUrl = 'https://openqa.test';
    configStore.openqaNotGroupGlob = '*Devel*';
  });

  const mockJobs = [
    {status: 'passed', job_group: 'G1', flavor: 'F1', version: 'V1', group_id: 1, distri: 'D1', build: 'B1'},
    {status: 'failed', job_group: 'G1', flavor: 'F1', version: 'V1', group_id: 1, distri: 'D1', build: 'B1'},
    {status: 'failed', job_group: 'G1', flavor: 'F1', version: 'V1', group_id: 1, distri: 'D1', build: 'B1'},
    {status: 'stopped', job_group: 'G2', flavor: 'F2', version: 'V2', group_id: 2, distri: 'D2', build: 'B2'},
    {status: 'waiting', job_group: 'G2', flavor: 'F2', version: 'V2', group_id: 2, distri: 'D2', build: 'B2'}
  ];

  it('renders correctly with jobs', () => {
    const wrapper = mount(SubmissionBuildSummary, {
      props: {build: 'B1', jobs: mockJobs}
    });

    expect(wrapper.text()).toContain('Build B1');
    expect(wrapper.text()).toContain('1 passed');

    const groups = wrapper.findAll('.card-body p');
    expect(groups).toHaveLength(2);

    // Group 1: G1@F1
    expect(groups[0].text()).toContain('G1@F1');
    expect(groups[0].text()).toContain('2 failed');

    // Group 2: G2@F2
    expect(groups[1].text()).toContain('G2@F2');
    expect(groups[1].text()).toContain('1 stopped');
    expect(groups[1].text()).toContain('1 waiting');
  });

  it('generates correct openQA link', () => {
    const wrapper = mount(SubmissionBuildSummary, {
      props: {build: 'B1', jobs: mockJobs}
    });

    const links = wrapper.findAll('a');
    // First link is G1@F1
    const link = links[0];
    const url = new URL(link.attributes('href'));
    expect(url.origin + url.pathname).toBe('https://openqa.test/');
    expect(url.searchParams.get('flavor')).toBe('F1');
    expect(url.searchParams.get('not_group_glob')).toBe('*Devel*');
  });
});
