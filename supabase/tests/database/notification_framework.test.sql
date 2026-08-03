begin;

select plan(17);

select has_table('public', 'league_notifications', 'notification table should exist');
select has_table('public', 'notification_delivery_events', 'delivery evidence table should exist');
select has_function(
  'public',
  'publish_league_notification',
  array['uuid', 'uuid', 'notification_kind', 'notification_audience', 'text', 'text', 'text'],
  'atomic notification publisher should exist'
);
select ok(
  not has_table_privilege('authenticated', 'public.league_notifications', 'insert')
  and has_table_privilege('authenticated', 'public.league_notifications', 'select'),
  'authenticated users should read through RLS but not bypass the publisher'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

select is(
  public.publish_league_notification(
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'announcement',
    'all_members',
    'Draft night reminder',
    'Bring your dues and arrive fifteen minutes before the draft starts.',
    'notification:test:draft-night'
  ) ->> 'status',
  'published',
  'commissioner should publish one in-app notification'
);
select is((select count(*) from public.league_notifications), 1::bigint, 'commissioner should read the published notification');
select is((select count(*) from public.notification_delivery_events), 1::bigint, 'one active seeded member should receive delivery evidence');
select is((select status::text from public.notification_delivery_events), 'delivered', 'in-app publication should be immediately delivered');

select is(
  public.publish_league_notification(
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'announcement',
    'all_members',
    'Draft night reminder',
    'Bring your dues and arrive fifteen minutes before the draft starts.',
    'notification:test:draft-night'
  ) ->> 'status',
  'already_published',
  'exact notification retries should be idempotent'
);

select throws_ok(
  $$ select public.publish_league_notification(
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'announcement', 'all_members', 'Changed title',
    'Bring your dues and arrive fifteen minutes before the draft starts.',
    'notification:test:draft-night'
  ) $$,
  '23505',
  'notification source key was reused with different content',
  'changed retry content should fail closed'
);

select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
select is((select count(*) from public.league_notifications), 0::bigint, 'outsider should not read league notifications');
select throws_ok(
  $$ select public.publish_league_notification(
    'd0000000-0000-4000-8000-000000000002', null,
    'system', 'all_members', 'Unauthorized',
    'An outsider must never publish this notification.',
    'notification:test:outsider'
  ) $$,
  '42501',
  'only an active commissioner may publish notifications',
  'outsider publication should fail inside PostgreSQL'
);

reset role;
select throws_ok(
  $$ update public.league_notifications set title = 'Mutated' $$,
  '55000',
  'notification evidence is immutable',
  'published notifications should be immutable'
);
select throws_ok(
  $$ delete from public.notification_delivery_events $$,
  '55000',
  'notification evidence is immutable',
  'delivery evidence should be immutable'
);
select is((select count(*) from public.league_notifications), 1::bigint, 'failed changes should preserve one notification');
select is((select count(*) from public.notification_delivery_events), 1::bigint, 'failed changes should preserve one delivery event');
select is((select count(*) from public.notification_delivery_events where stable_error_code is null), 1::bigint, 'successful delivery should not carry an error code');

select * from finish();
rollback;
