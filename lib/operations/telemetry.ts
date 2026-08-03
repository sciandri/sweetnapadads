const SENSITIVE_KEY = /secret|token|cookie|password|authorization|payload|body/i;

export type OperationalFields = Record<
  string,
  string | number | boolean | null | undefined
>;

export function operationalEvent(
  name: string,
  fields: OperationalFields = {},
) {
  const safeFields = Object.fromEntries(
    Object.entries(fields)
      .filter(([key, value]) => !SENSITIVE_KEY.test(key) && value !== undefined)
      .map(([key, value]) => [key, value]),
  );
  console.info(JSON.stringify({
    level: "info",
    event: name,
    ...safeFields,
    recorded_at: new Date().toISOString(),
  }));
}
