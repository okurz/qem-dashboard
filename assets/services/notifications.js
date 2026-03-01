export function requestNotificationPermission() {
  if (!('Notification' in window)) {
    return Promise.resolve('unsupported');
  }
  if (Notification.permission === 'granted') {
    return Promise.resolve('granted');
  }
  if (Notification.permission !== 'denied') {
    return Notification.requestPermission();
  }
  return Promise.resolve(Notification.permission);
}

export function showNotification(title, options) {
  if (!('Notification' in window) || Notification.permission !== 'granted') {
    return null;
  }
  return new Notification(title, options);
}

export function getNotificationPermission() {
  if (!('Notification' in window)) {
    return 'unsupported';
  }
  return Notification.permission;
}
