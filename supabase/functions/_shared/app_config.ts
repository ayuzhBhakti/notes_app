import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { CashfreeEnvironment } from "./cashfree.ts";

export interface AppConfigEntry {
  key: string;
  value: string;
}

export type AppConfigMap = Record<string, string>;

/**
 * What the payment functions need from the `app_config` table. Read with the service role, so it
 * includes the rows the app itself can never see (the Cashfree id and secret).
 */
export interface ResolvedAppConfig {
  appName: string;
  cashfreeAppId: string;
  cashfreeSecretKey: string;
  cashfreeEnvironment: CashfreeEnvironment;
  cashfreeTrialAmount: number;
  cashfreeRecurringAmount: number;
  cashfreePlanId: string;
  planName: string;
  customerEmailDomain: string;
}

export function createServiceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

function parseEnvironment(value: string | null | undefined): CashfreeEnvironment {
  return value?.toLowerCase() === "production" ? "production" : "sandbox";
}

function pickString(...values: Array<string | null | undefined>): string {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed;
  }
  return "";
}

function pickNumber(value: string, fallback: number): number {
  if (!value) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export async function loadConfigMap(
  client: SupabaseClient = createServiceClient(),
): Promise<AppConfigMap> {
  const { data, error } = await client.from("app_config").select("key, value");
  if (error) {
    throw new Error(`Failed to read app_config: ${error.message}`);
  }

  const map: AppConfigMap = {};
  for (const row of (data ?? []) as AppConfigEntry[]) {
    map[row.key] = row.value ?? "";
  }
  return map;
}

/** The table row wins; the function secret of the same name is the fallback. */
function resolve(map: AppConfigMap, key: string): string {
  return pickString(map[key], Deno.env.get(key.toUpperCase()));
}

export async function loadAppConfig(
  client: SupabaseClient = createServiceClient(),
): Promise<ResolvedAppConfig> {
  const map = await loadConfigMap(client);

  const cashfreeAppId = resolve(map, "cashfree_app_id");
  const cashfreeSecretKey = resolve(map, "cashfree_secret_key");
  if (!cashfreeAppId || !cashfreeSecretKey) {
    throw new Error(
      "Cashfree credentials missing. Set cashfree_app_id and cashfree_secret_key in app_config, or CASHFREE_APP_ID and CASHFREE_SECRET_KEY as Edge Function secrets.",
    );
  }

  const appName = resolve(map, "app_name") || "Evos";
  return {
    appName,
    cashfreeAppId,
    cashfreeSecretKey,
    // Anything other than the exact word "production" is sandbox, so a typo can never take
    // real money.
    cashfreeEnvironment: parseEnvironment(resolve(map, "cashfree_environment")),
    cashfreeTrialAmount: pickNumber(resolve(map, "cashfree_trial_amount"), 3),
    cashfreeRecurringAmount: pickNumber(resolve(map, "cashfree_recurring_amount"), 299),
    cashfreePlanId: resolve(map, "cashfree_plan_id"),
    planName: resolve(map, "plan_name") || `${appName} Premium Monthly`,
    customerEmailDomain: resolve(map, "customer_email_domain"),
  };
}
