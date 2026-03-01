import {defineStore} from 'pinia';
import {requestNotificationPermission, showNotification, getNotificationPermission} from '../services/notifications.js';

export const useNotificationsStore = defineStore('notifications', {
  state: () => ({
    permission: 'default',
    enabled: false,
    lastChecked: null,
    lastSeenIncidentIds: [],
    checkIntervalSeconds: 60,
    isLoading: false
  }),
  actions: {
    async requestPermission() {
      this.permission = await requestNotificationPermission();
      return this.permission;
    },
    async checkPermission() {
      this.permission = getNotificationPermission();
      return this.permission;
    },
    async loadSettings() {
      try {
        const data = await fetch('/app/api/notification_settings').then(res => res.json());
        this.enabled = data.enabled ?? false;
        this.checkIntervalSeconds = data.check_interval_seconds ?? 60;
        this.lastChecked = data.last_checked ? new Date(data.last_checked).getTime() : null;
      } catch (e) {
        console.error('Failed to load notification settings:', e);
      }
    },
    async saveSettings(settings) {
      try {
        const response = await fetch('/app/api/notification_settings', {
          method: 'PUT',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify(settings)
        });
        if (!response.ok) {
          console.error('Failed to save settings, status:', response.status);
          return;
        }
        const data = await response.json();
        this.enabled = data.enabled ?? this.enabled;
        this.checkIntervalSeconds = data.check_interval_seconds ?? this.checkIntervalSeconds;
      } catch (e) {
        console.error('Failed to save notification settings:', e);
      }
    },
    async enable() {
      await this.requestPermission();
      if (this.permission === 'granted') {
        await this.saveSettings({enabled: true});
      }
    },
    async disable() {
      await this.saveSettings({enabled: false});
    },
    async checkForNewFailures(currentBlocked) {
      if (!this.enabled || this.permission !== 'granted') return;
      const newIncidents = currentBlocked.filter(b => !this.lastSeenIncidentIds.includes(b.incident?.id));
      if (newIncidents.length > 0) {
        const titles = newIncidents.map(n => n.incident?.number || n.incident?.id).join(', ');
        showNotification('New Blocking Failures', {
          body: `Incident(s) ${titles} now have blocking failures`,
          icon: '/favicon-32x32.png'
        });
      }
      this.lastSeenIncidentIds = currentBlocked.map(b => b.incident?.id);
      this.lastChecked = Date.now();
      await this.saveSettings({last_checked: new Date().toISOString()});
    },
    initFromBlocked(blocked) {
      this.lastSeenIncidentIds = blocked.map(b => b.incident?.id);
    }
  }
});
