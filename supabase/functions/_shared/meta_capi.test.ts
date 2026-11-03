// Tests for the server-side Meta (Facebook) Conversions API Purchase event.
// Run with: deno test --allow-net supabase/functions/_shared/meta_capi.test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sendMetaPurchaseEvent, trackMetaPurchase } from "./meta_capi.ts";

const baseInput = {
  accessToken: "tok",
  datasetId: "dataset_1",
  anonId: "anon-guid-1",
  amount: 299,
  currency: "INR",
  eventId: "pay_123",
  eventTime: 1761900000,
};

Deno.test("sendMetaPurchaseEvent posts the Purchase event and reports success", async () => {
  const calls: Array<{ url: string; body: string }> = [];
  const fakeFetch = (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), body: String(init?.body) });
    return Promise.resolve(
      new Response(JSON.stringify({ events_received: 1 }), { status: 200 }),
    );
  };

  const sent = await sendMetaPurchaseEvent(baseInput, fakeFetch);

  assertEquals(sent, true);
  assertEquals(calls.length, 1);
  assertEquals(
    calls[0].url,
    "https://graph.facebook.com/v21.0/dataset_1/events?access_token=tok",
  );
  const body = JSON.parse(calls[0].body);
  assertEquals(body.data[0].event_name, "Purchase");
  assertEquals(body.data[0].event_id, "pay_123");
  assertEquals(body.data[0].action_source, "app");
  assertEquals(body.data[0].user_data, { anon_id: "anon-guid-1" });
  assertEquals(body.data[0].custom_data, { currency: "INR", value: "299.00" });
  assertEquals(body.data[0].app_data.advertiser_tracking_enabled, 0);
  assertEquals(body.data[0].app_data.application_tracking_enabled, 1);
  assertEquals(body.data[0].app_data.extinfo.length, 16);
  assertEquals(body.data[0].app_data.extinfo[0], "a2");
  // OS version (slot 4): Meta's validator refuses a blank one (error_subcode 2804043,
  // confirmed live 2026-11-02 against a real test event).
  assertEquals(body.data[0].app_data.extinfo[4], "13");
});

Deno.test("sendMetaPurchaseEvent never sends without an access token, dataset id or anon id", async () => {
  let calls = 0;
  const fakeFetch = () => {
    calls += 1;
    return Promise.resolve(new Response("{}", { status: 200 }));
  };

  assertEquals(
    await sendMetaPurchaseEvent({ ...baseInput, accessToken: "" }, fakeFetch),
    false,
  );
  assertEquals(
    await sendMetaPurchaseEvent({ ...baseInput, datasetId: "" }, fakeFetch),
    false,
  );
  assertEquals(
    await sendMetaPurchaseEvent({ ...baseInput, anonId: null }, fakeFetch),
    false,
  );
  assertEquals(calls, 0);
});

Deno.test("sendMetaPurchaseEvent never throws: a network error or a refusal is false", async () => {
  const throwing = () => Promise.reject(new Error("offline"));
  assertEquals(await sendMetaPurchaseEvent(baseInput, throwing), false);

  const refusing = () =>
    Promise.resolve(new Response(JSON.stringify({ error: "bad token" }), { status: 401 }));
  assertEquals(await sendMetaPurchaseEvent(baseInput, refusing), false);

  const emptyAck = () =>
    Promise.resolve(new Response(JSON.stringify({ events_received: 0 }), { status: 200 }));
  assertEquals(await sendMetaPurchaseEvent(baseInput, emptyAck), false);
});

Deno.test("trackMetaPurchase does nothing, and never throws, without config", async () => {
  let calls = 0;
  const fakeFetch = () => {
    calls += 1;
    return Promise.resolve(new Response("{}", { status: 200 }));
  };
  await trackMetaPurchase("fn", { ...baseInput, accessToken: "" }, fakeFetch);
  await trackMetaPurchase("fn", { ...baseInput, datasetId: "" }, fakeFetch);
  assertEquals(calls, 0);
});

Deno.test("trackMetaPurchase sends the event when configured", async () => {
  const calls: string[] = [];
  const fakeFetch = (url: string | URL | Request) => {
    calls.push(String(url));
    return Promise.resolve(
      new Response(JSON.stringify({ events_received: 1 }), { status: 200 }),
    );
  };
  await trackMetaPurchase("fn", baseInput, fakeFetch);
  assertEquals(calls.length, 1);
});
