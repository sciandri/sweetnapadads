-- Close inherited anonymous execution on security-definer functions.
-- Authenticated RPCs retain only the roles required by their internal
-- commissioner/service authorization checks. The platform event trigger runs
-- as its owner and does not need API-role execution grants.

revoke execute on function public.commit_historical_import(uuid, jsonb)
from public, anon;
grant execute on function public.commit_historical_import(uuid, jsonb)
to authenticated, service_role;

revoke execute on function public.get_commissioner_message_context(uuid, integer)
from public, anon;
grant execute on function public.get_commissioner_message_context(uuid, integer)
to authenticated, service_role;

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute
      'revoke execute on function public.rls_auto_enable() '
      'from public, anon, authenticated, service_role';
  end if;
end;
$$;
