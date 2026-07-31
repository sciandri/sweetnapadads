type PublicSupabaseEnv = {
  url: string;
  publishableKey: string;
};

type ServerSupabaseEnv = {
  url: string;
  serviceRoleKey: string;
};

function requireValue(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function requireUrl(value: string | undefined, name: string) {
  const requiredValue = requireValue(value, name);

  try {
    return new URL(requiredValue).toString().replace(/\/$/, "");
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }
}

export function validatePublicSupabaseEnv(
  url: string | undefined,
  publishableKey: string | undefined,
): PublicSupabaseEnv {
  return {
    url: requireUrl(url, "NEXT_PUBLIC_SUPABASE_URL"),
    publishableKey: requireValue(
      publishableKey,
      "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    ),
  };
}

export function validateServerSupabaseEnv(
  url: string | undefined,
  serviceRoleKey: string | undefined,
): ServerSupabaseEnv {
  return {
    url: requireUrl(url, "NEXT_PUBLIC_SUPABASE_URL"),
    serviceRoleKey: requireValue(
      serviceRoleKey,
      "SUPABASE_SERVICE_ROLE_KEY",
    ),
  };
}

export function getPublicSupabaseEnv() {
  return validatePublicSupabaseEnv(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}

export function getServerSupabaseEnv() {
  return validateServerSupabaseEnv(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}
