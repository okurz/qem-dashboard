import {describe, it, expect, beforeEach, vi} from 'vitest';
import {createPinia, setActivePinia} from 'pinia';
import {useConfigStore} from './config';

describe('config store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.stubGlobal('fetch', vi.fn());
  });

  it('initial state', () => {
    const store = useConfigStore();
    expect(store.isLoaded).toBe(false);
    expect(store.bootId).toBe('');
  });

  it('fetchConfig', async () => {
    const mockConfig = {
      bootId: 'test-boot',
      openqaUrl: 'https://openqa.test',
      openqaNotGroupGlob: '*Devel*',
      obsUrl: 'https://obs.test',
      smeltUrl: 'https://smelt.test',
      giteaFallbackPriority: 550
    };

    fetch.mockResolvedValue({
      json: () => Promise.resolve(mockConfig)
    });

    const store = useConfigStore();
    await store.fetchConfig();

    expect(store.bootId).toBe('test-boot');
    expect(store.openqaUrl).toBe('https://openqa.test');
    expect(store.isLoaded).toBe(true);
  });
});
