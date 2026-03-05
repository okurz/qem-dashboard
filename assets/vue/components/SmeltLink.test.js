import {mount} from '@vue/test-utils';
import {describe, it, expect, beforeEach} from 'vitest';
import {createPinia, setActivePinia} from 'pinia';
import SmeltLink from './SmeltLink.vue';
import {useConfigStore} from '@/stores/config';

describe('SmeltLink.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    const configStore = useConfigStore();
    configStore.smeltUrl = 'https://smelt.test';
  });

  it('renders a link to smelt', () => {
    const incident = {number: 12345, packages: ['test-package']};
    const wrapper = mount(SmeltLink, {
      props: {incident}
    });

    const link = wrapper.find('a');
    expect(link.attributes('href')).toBe('https://smelt.test/incident/12345');
    expect(link.text()).toBe('12345:test-package');
  });
});
