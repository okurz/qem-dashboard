# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Model::Notifications;
use Mojo::Base -base, -signatures;

has 'pg';

sub get_settings ($self) {
  my $settings = $self->pg->db->query('SELECT * FROM notification_settings LIMIT 1')->hash;
  return $settings if $settings;
  $self->pg->db->query('INSERT INTO notification_settings (enabled) VALUES (TRUE)');
  return $self->pg->db->query('SELECT * FROM notification_settings LIMIT 1')->hash;
}

sub update_settings ($self, $settings) {
  my $db       = $self->pg->db;
  my $existing = $db->query('SELECT id FROM notification_settings LIMIT 1')->hash;
  if ($existing) {
    my @set;
    my @values;
    for my $key (qw(enabled check_interval_seconds last_checked)) {
      if (exists $settings->{$key}) {
        push @set,    "$key = ?";
        push @values, $settings->{$key};
      }
    }
    return undef unless @set;
    push @values, $existing->{id};
    $db->query("UPDATE notification_settings SET " . join(', ', @set) . " WHERE id = ?", @values);
  }
  else {
    $db->query(
      'INSERT INTO notification_settings (enabled, check_interval_seconds) VALUES (?, ?)',
      $settings->{enabled}                // 1,
      $settings->{check_interval_seconds} // 60
    );
  }
  return $self->get_settings;
}

sub record_check ($self) {
  $self->pg->db->query('UPDATE notification_settings SET last_checked = NOW() WHERE id = 1');
}

1;
