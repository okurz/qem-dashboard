import {mount} from '@vue/test-utils';
import {describe, it, expect, beforeEach} from 'vitest';
import {createPinia, setActivePinia} from 'pinia';
import RequestLink from './RequestLink.vue';
import {useConfigStore} from '@/stores/config';

describe('RequestLink.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    const configStore = useConfigStore();
    configStore.obsUrl = 'https://obs.test';
  });

  it('renders a link to OBS request for IBS incidents with rr_number', () => {
    const incident = {number: 12345, rr_number: 67890, packages: ['test-pkg'], type: 'ibs'};
    const wrapper = mount(RequestLink, {
      props: {incident}
    });

    const link = wrapper.find('a');
    expect(link.attributes('href')).toBe('https://obs.test/request/show/67890');
    expect(link.text()).toContain('67890:test-pkg');
    expect(wrapper.find('i').classes()).toContain('fa-box-open');
  });

  it('renders a link to the incident URL for git type incidents', () => {
    const incident = {number: 12345, url: 'https://git.test', packages: ['git-pkg'], type: 'git'};
    const wrapper = mount(RequestLink, {
      props: {incident}
    });

    const link = wrapper.find('a');
    expect(link.attributes('href')).toBe('https://git.test');
    expect(link.text()).toContain('git-pkg');
    expect(wrapper.find('i').classes()).toContain('fa-code-branch');
  });

  it('renders a link to the incident URL when rr_number is missing', () => {
    const incident = {number: 12345, url: 'https://fallback.test', packages: [], type: 'ibs'};
    const wrapper = mount(RequestLink, {
      props: {incident}
    });

    const link = wrapper.find('a');
    expect(link.attributes('href')).toBe('https://fallback.test');
    expect(link.text()).toContain('Source');
  });
});
