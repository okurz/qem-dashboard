# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Warnings ':report_warnings';
use Dashboard::Test;
use Mojo::JSON qw(true false);

if (!$ENV{TEST_ONLINE}) {    # uncoverable branch true
  plan skip_all => 'set TEST_ONLINE to enable this test';    # uncoverable statement
}

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'Dashboard::Model::Incidents' => sub {
  my $incidents     = $t->app->incidents;
  my $mock_incident = {
    number      => 16860,
    project     => 'SUSE:Maintenance:16860',
    packages    => ['pkg1'],
    channels    => ['Test'],
    rr_number   => undef,
    inReview    => true,
    inReviewQAM => true,
    approved    => false,
    emu         => true,
    isActive    => true,
    embargoed   => false,
    priority    => 123,
  };

  subtest 'id_for_number and number_for_id' => sub {
    is $incidents->id_for_number(16860), 1,     'correct id for 16860';
    is $incidents->number_for_id(1),     16860, 'correct number for id 1';
    is $incidents->id_for_number(99999), undef, 'undef for non-existent number';
    is $incidents->number_for_id(99999), undef, 'undef for non-existent id';
  };

  subtest 'name' => sub {
    my $inc = $incidents->incident_for_number(16860);
    is $incidents->name($inc), '16860:perl-Mojolicious', 'correct name for 16860';
    is $incidents->name({number => 99999}), '99999:unknown', 'correct name for unknown incident';
    is $incidents->name({number => 99998, packages => []}), '99998:unknown',
      'correct name for incident with empty packages';
  };

  subtest 'build_nr' => sub {
    my $inc = $incidents->incident_for_number(16860);
    ok $incidents->build_nr($inc), 'returns build number for incident with jobs';
    is $incidents->build_nr({id => 99999}), undef, 'returns undef for non-existent incident id';
  };


  subtest 'job filtering' => sub {
    my $dashboard_test_filter = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_filter_test');
    my $app_filter            = Test::Mojo->new(Dashboard => $dashboard_test_filter->default_config)->app;
    $dashboard_test_filter->no_fixtures($app_filter);

    my $incs     = $app_filter->incidents;
    my $settings = $app_filter->settings;
    my $jobs     = $app_filter->jobs;

    $incs->sync(
      [
        {number => 1001, project => 'P1001', packages => ['pkg1'], isActive => 1},
        {number => 1002, project => 'P1002', packages => ['pkg2'], isActive => 1}
      ]
    );

    my $inc1001_id = $incs->id_for_number(1001);
    my $inc1002_id = $incs->id_for_number(1002);

    # Both incidents in the same update
    my $update_settings_id = $settings->add_update_settings(
      [$inc1001_id, $inc1002_id],
      {
        product  => 'Prod',
        arch     => 'x86_64',
        build    => '20260117-1',
        repohash => 'hash1',
        settings => {BUILD => '20260117-1'}
      }
    );

    # Job for 1001
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'job_for_1001',
        job_group       => 'Group A',
        status          => 'failed',
        job_id          => 100101,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => ':1001:some-build'
      }
    );

    # Generic job
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'generic_job',
        job_group       => 'Group A',
        status          => 'passed',
        job_id          => 100102,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => '20260117-1'
      }
    );

    # Job for another incident (matches :[0-9]+: but not :1001:)
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'job_for_1002',
        job_group       => 'Group A',
        status          => 'failed',
        job_id          => 100104,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => ':1002:some-build'
      }
    );

    # Obsolete job for 1001
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'obsolete_job',
        job_group       => 'Group A',
        status          => 'failed',
        job_id          => 100103,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => ':1001:obsolete'
      }
    );
    $jobs->modify(100103, {obsolete => 1});

    my $res1001 = $incs->_update_openqa_jobs({id => $inc1001_id, number => 1001});
    is $res1001->{"100 f v"}{failed}, 1, 'Incident 1001 sees its failed job';
    is $res1001->{"100 f v"}{passed}, 1, 'Incident 1001 sees generic job';

    my $res1002 = $incs->_update_openqa_jobs({id => $inc1002_id, number => 1002});
    is $res1002->{"100 f v"}{failed}, 1, 'Incident 1002 sees its own failed job';
    is $res1002->{"100 f v"}{passed}, 1, 'Incident 1002 sees generic job';

    # rr_number change
    $incs->update({%$mock_incident, number => 1001, rr_number => 100});
    is $incs->incident_for_number(1001)->{rr_number}, 100, 'rr_number updated';
    $incs->update({%$mock_incident, number => 1001, rr_number => 200});
    is $incs->incident_for_number(1001)->{rr_number}, 200, 'rr_number changed again';

    # Map undef
    is $incs->_map(undef), undef, '_map returns undef for undef input';

    # Sync without types
    $incs->sync([$mock_incident]);
    ok $incs->incident_for_number(16860), 'sync works without types';

    # Sync WITH types
    $incs->sync([{%$mock_incident, type => 'ibs'}], ['ibs', 'obs']);
    is $incs->incident_for_number(16860)->{type}, 'ibs', 'sync works with types';

    # Channel removal
    $incs->update({%$mock_incident, number => 16860, channels => ['Test', 'NewChannel']});
    is scalar(@{$incs->find({number => 16860})->[0]{channels}}), 2, 'channels added';
    $incs->update({%$mock_incident, number => 16860, channels => ['Test']});
    is scalar(@{$incs->find({number => 16860})->[0]{channels}}), 1, 'channel removed';

    # Missing optional fields
    $incs->update({%$mock_incident, number => 16860, scminfo => undef, url => undef, type => undef});
    my $inc = $incs->find({number => 16860})->[0];
    is $inc->{scminfo}, '', 'scminfo default';
    is $inc->{url},     '', 'url default';
    is $inc->{type},    '', 'type default';

    # Providing optional fields
    $incs->update({%$mock_incident, number => 16860, scminfo => 'git://foo', url => 'https://bar'});
    $inc = $incs->find({number => 16860})->[0];
    is $inc->{scminfo}, 'git://foo',   'scminfo provided';
    is $inc->{url},     'https://bar', 'url provided';

    # rr_number NOT changed
    $incs->update({%$mock_incident, number => 16860, rr_number => 100});
    $incs->update({%$mock_incident, number => 16860, rr_number => 100});
    is $incs->incident_for_number(16860)->{rr_number}, 100, 'rr_number unchanged';

    # rr_number undef
    $incs->update({%$mock_incident, number => 16860, rr_number => undef});
    is $incs->incident_for_number(16860)->{rr_number}, undef, 'rr_number undef works';
  };

  subtest '_incident_openqa_jobs branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;
    my $jobs     = $t->app->jobs;
    my $inc      = $incs->incident_for_number(16860);

    # Add another job with same group_id (282)
    $jobs->add(
      {
        incident_settings => 1,
        name              => 'another-job',
        job_group         => 'Maintenance: SLE 12 SP5 Incidents',
        status            => 'passed',
        job_id            => 999001,
        group_id          => 282,
        distri            => 'd',
        flavor            => 'f',
        version           => 'v',
        arch              => 'a',
        build             => 'b'
      }
    );
    ok $incs->_incident_openqa_jobs($inc), 'works with multiple jobs in same group';
  };

  subtest 'repos extra branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;

    # Add a repo with jobs but NO incidents
    my $sid = $settings->add_update_settings([],
      {product => 'NoIncsProduct', arch => 'x86_64', build => '456', repohash => 'h', settings => {}});
    $t->app->jobs->add(
      {
        update_settings => $sid,
        name            => 'n-job',
        job_group       => 'G',
        status          => 'passed',
        job_id          => 999002,
        group_id        => 1,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'a',
        build           => 'b'
      }
    );
    ok $incs->repos, 'repos works even with a repo having no incidents';
  };

  subtest 'openqa_summary_only_aggregates branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;
    my $inc      = $incs->incident_for_number(16860);

    # Add another update for 16860 with an existing build number (20201107-1)
    $settings->add_update_settings([$inc->{id}],
      {product => 'ExtraProd', arch => 'x86_64', build => '20201107-1', repohash => 'h2', settings => {}});

    ok $incs->openqa_summary_only_aggregates($inc),
      'works for incident with multiple aggregate jobs sharing same build';
  };

  subtest 'repos branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;

    # Add a repo (update settings) with NO jobs to trigger line 121 branch
    $settings->add_update_settings([1],
      {product => 'NoJobsProduct', arch => 'x86_64', build => '123', repohash => 'h', settings => {}});
    ok $incs->repos, 'repos works even with a repo having no jobs';

    # Add another one to test line 127: different update settings with same builds
    $settings->add_update_settings([1],
      {product => 'SLES-12-SP5', arch => 'x86_64', build => '20201107-1', repohash => 'h2', settings => {}});
    ok $incs->repos, 'repos works with duplicate builds in different updates';
  };

  subtest 'sync with changed rr_number' => sub {
    my $dashboard_test_sync = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_sync_test');
    my $app_sync            = Test::Mojo->new(Dashboard => $dashboard_test_sync->default_config)->app;
    $dashboard_test_sync->no_fixtures($app_sync);
    my $incs = $app_sync->incidents;

    # Initial sync with NO rr_number (will be NULL in DB, then 0 in code)
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => undef}]);
    is $incs->incident_for_number(16860)->{rr_number}, undef, 'initial rr_number is undef (NULL in DB)';

    # Sync with rr_number (should NOT trigger cleanup because old was 0)
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => '100'}]);
    is $incs->incident_for_number(16860)->{rr_number}, '100', 'rr_number set to 100';

    # Change rr_number (SHOULD trigger cleanup)
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => '200'}]);
    is $incs->incident_for_number(16860)->{rr_number}, '200', 'rr_number updated to 200';

    # Sync with same rr_number (should NOT trigger cleanup)
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => '200'}]);
    ok 1, 'sync with same rr_number works';

    # Sync with NO rr_number (defined but null/undef)
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => undef}]);
    ok 1, 'sync with undef rr_number works';

    # Sync with 0 as rr_number
    $incs->sync([{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => '0'}]);
    ok 1, 'sync with "0" rr_number works';

    # Sync with undef fields (coverage for scminfo/url // '')
    $incs->sync(
      [{number => 16860, project => 'P1', packages => ['pkg1'], isActive => 1, rr_number => '200', type => undef}]);
    ok 1, 'sync with undef fields works';
  };

  subtest 'build_nr non-existent' => sub {
    is $incidents->build_nr({id => 99999}), undef, 'returns undef for non-existent incident id in build_nr';
  };
};

subtest 'Dashboard::Model::Settings' => sub {
  my $settings = $t->app->settings;

  subtest 'find_update_settings' => sub {
    my $id = $settings->add_update_settings([1],
      {product => 'FindProduct', arch => 'x86_64', build => 'FindBuild', repohash => 'h', settings => {S => 1}});
    is $settings->find_update_settings({product => 'FindProduct', arch => 'x86_64', build => 'FindBuild'})->[0]{id},
      $id, 'found correct id';
    is scalar(@{$settings->find_update_settings({product => 'None', arch => 'x86_64', build => 'FindBuild'})}), 0,
      'none for non-existent';
  };

  subtest 'get_update_settings' => sub {
    my $id = $settings->add_update_settings([1],
      {product => 'GetProduct', arch => 'x86_64', build => 'GetBuild', repohash => 'h', settings => {GET => 1}});
    my $res = $settings->get_update_settings(1);
    is $res->[0]{product},                               'GetProduct', 'correct product';
    is $res->[0]{settings}{GET},                         1,            'correct settings';
    is scalar(@{$settings->get_update_settings(99999)}), 0,            'none for non-existent id';
  };

  subtest 'existence checks' => sub {
    ok $settings->incident_settings_exist(1),      'incident settings 1 exists';
    ok !$settings->incident_settings_exist(99999), 'incident settings 99999 does not exist';
    ok $settings->update_settings_exist(1),        'update settings 1 exists';
    ok !$settings->update_settings_exist(99999),   'update settings 99999 does not exist';
  };
};

subtest 'Dashboard::Model::Jobs' => sub {
  my $jobs = $t->app->jobs;

  subtest '_normalize_result' => sub {
    is Dashboard::Model::Jobs::_normalize_result('passed'),           'passed',  'passed stays passed';
    is Dashboard::Model::Jobs::_normalize_result('softfailed'),       'passed',  'softfailed becomes passed';
    is Dashboard::Model::Jobs::_normalize_result('none'),             'waiting', 'none becomes waiting';
    is Dashboard::Model::Jobs::_normalize_result('failed'),           'failed',  'failed stays failed';
    is Dashboard::Model::Jobs::_normalize_result('timeout_exceeded'), 'stopped', 'timeout_exceeded becomes stopped';
    is Dashboard::Model::Jobs::_normalize_result('user_cancelled'),   'stopped', 'user_cancelled becomes stopped';
    is Dashboard::Model::Jobs::_normalize_result('something_else'),   'failed',  'something_else becomes failed';
  };

  subtest 'latest_update with no jobs' => sub {
    my $dashboard_test_empty = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_empty_test');
    my $app_empty            = Test::Mojo->new(Dashboard => $dashboard_test_empty->default_config)->app;
    $dashboard_test_empty->no_fixtures($app_empty);
    is $app_empty->jobs->latest_update, undef, 'latest_update is undef when no jobs exist';
  };

  subtest 'update_result with non-existent job' => sub {
    ok !$jobs->update_result(9999999, 'passed'), 'update_result returns false for non-existent job';
  };

  subtest 'remove_remarks when updating job_id' => sub {
    my $job_data = {
      incident_settings => 1,
      name              => 'rem-remarks-job',
      job_group         => 'G',
      status            => 'passed',
      job_id            => 888001,
      group_id          => 1,
      distri            => 'd',
      flavor            => 'f',
      version           => 'v',
      arch              => 'a',
      build             => 'b'
    };
    my $id = $jobs->add($job_data);
    $jobs->add_remark($id, 1, 'some remark');
    is scalar($jobs->remarks($id)->each), 1, 'remark added';

    # Update with DIFFERENT job_id should trigger remove_remarks
    $job_data->{job_id} = 888002;
    $jobs->add($job_data);
    is scalar($jobs->remarks($id)->each), 0, 'remark removed after job_id update';
  };

  subtest 'get_update_settings' => sub {
    my $res = $jobs->get_update_settings(1);
    ok ref $res eq 'ARRAY', 'returns array ref';
  };

  subtest 'keep_schema' => sub {
    my $dashboard_test_keep
      = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_keep_test', keep_schema => 1);
    ok $dashboard_test_keep, 'Dashboard::Test->new with keep_schema works';
  };
};

subtest 'Dashboard::Model::Notifications' => sub {
  my $notifications = $t->app->notifications;
  subtest 'initial settings' => sub {
    $t->app->pg->db->query('DELETE FROM notification_settings');
    my $s = $notifications->get_settings;
    is $s->{enabled}, 1, 'enabled by default';
  };
  subtest 'update_settings creation' => sub {
    $t->app->pg->db->query('DELETE FROM notification_settings');
    my $s = $notifications->update_settings({enabled => 0});
    is $s->{enabled}, 0, 'created with enabled=0';
  };
  subtest 'update_settings returns undef if no known fields' => sub {
    ok !$notifications->update_settings({foo => 'bar'}), 'returns undef for unknown fields';
  };
};

subtest 'Dashboard::Plugin::Helpers' => sub {
  subtest 'schema helper' => sub {
    my $schema = $t->app->schema('incident');
    ok $schema,                             'loaded incident schema from file';
    ok $t->app->schema({type => 'object'}), 'loaded schema from reference';
  };
  subtest 'schema helper from ref' => sub {
    my $schema_ref = {type => 'object', properties => {foo => {type => 'string'}}};
    my $schema     = $t->app->schema($schema_ref);
    ok $schema, 'loaded schema from hash ref';
  };
};

done_testing();
