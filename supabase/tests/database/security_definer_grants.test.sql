begin;

select plan(6);

select ok(
  not has_function_privilege(
    'anon',
    'public.commit_historical_import(uuid,jsonb)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the historical import commit boundary'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.commit_historical_import(uuid,jsonb)',
    'EXECUTE'
  ),
  'authenticated commissioners can reach the guarded import boundary'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.commit_historical_import(uuid,jsonb)',
    'EXECUTE'
  ),
  'service operations retain access to the import boundary'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.get_commissioner_message_context(uuid,integer)',
    'EXECUTE'
  ),
  'anonymous users cannot execute the commissioner message context boundary'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.get_commissioner_message_context(uuid,integer)',
    'EXECUTE'
  ),
  'authenticated commissioners can reach the guarded message boundary'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.get_commissioner_message_context(uuid,integer)',
    'EXECUTE'
  ),
  'service operations retain access to the message boundary'
);

select * from finish();
rollback;
