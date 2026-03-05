import {describe, it, expect, beforeEach} from 'vitest';
import {createPinia, setActivePinia} from 'pinia';
import {useModalStore} from './modal';

describe('modal store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('initial state', () => {
    const store = useModalStore();
    expect(store.title).toBe('');
    expect(store.submissions).toEqual([]);
  });

  it('showSubmissions action', () => {
    const store = useModalStore();
    const mockSubmissions = [{number: 123}];
    store.showSubmissions('Test Title', mockSubmissions);
    expect(store.title).toBe('Test Title');
    expect(store.submissions).toEqual(mockSubmissions);
  });
});
