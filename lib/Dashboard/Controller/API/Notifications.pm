# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Notifications;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub get ($self) {
  $self->render(json => $self->notifications->get_settings);
}

sub update ($self) {
  my $settings = $self->req->json;
  $self->render(json => $self->notifications->update_settings($settings));
}

1;
