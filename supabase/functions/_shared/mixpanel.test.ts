// Tests for server-side Mixpanel events.
// Run with: deno test supabase/functions/_shared/mixpanel.test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildServerEvent,
  insertIdFor,
  paymentTypeFor,
  sendServerEvents,
} from "./mixpanel.ts";

Deno.test("buildServerEvent puts the user's ad on the event and skips empty fields", () => {
  const event = buildServerEvent({
    token: "tok",
    event: "Payment Succeeded",
    userId: "user-1",
    insertId: "pay-1",
    time: 1761900000,
    properties: { payment_type: "trial", amount: 3 },
    attribution: {
      install_source: "meta",
      utm_source: "meta",
      utm_medium: "paid",
      utm_campaign: "Evos_AppInstalls_Hindi",
      utm_term: null,
      utm_content: "Evos_Reel_Hindi_30s",
      campaign_id: "120211112222333344",
      adset_id: "",
      ad_id: "120212345678901234",
    },
  });
  assertEquals(event, {
    event: "Payment Succeeded",
    properties: {
      token: "tok",
      distinct_id: "user-1",
      time: 1761900000,
      $insert_id: "pay-1",
      event_source: "server",
      install_source: "meta",
      utm_source: "meta",
      utm_medium: "paid",
      utm_campaign: "Evos_AppInstalls_Hindi",
      utm_content: "Evos_Reel_Hindi_30s",
      campaign_id: "120211112222333344",
      ad_id: "120212345678901234",
      payment_type: "trial",
      amount: 3,
    },
  });
});

Deno.test("buildServerEvent: event properties cannot overwrite token or distinct_id", () => {
  const event = buildServerEvent({
    token: "tok",
    event: "X",
    userId: "user-1",
    insertId: "i",
    time: 1,
    properties: { token: "other", distinct_id: "someone-else" },
    attribution: {},
  });
  assertEquals(event.properties.token, "tok");
  assertEquals(event.properties.distinct_id, "user-1");
});

Deno.test("paymentTypeFor: trial, auto_renewal, and retry after a failed debit", () => {
  assertEquals(paymentTypeFor("trial", null), "trial");
  assertEquals(paymentTypeFor("trial", "failed"), "trial");
  assertEquals(paymentTypeFor("monthly", null), "auto_renewal");
  assertEquals(paymentTypeFor("monthly", "success"), "auto_renewal");
  assertEquals(paymentTypeFor("monthly", "failed"), "retry");
});

Deno.test("insertIdFor keeps Mixpanel's 36-character [A-Za-z0-9-] limit", () => {
  assertEquals(insertIdFor("1234567"), "1234567");
  assertEquals(insertIdFor("ev_abc:trial"), "ev-abc-trial");
  const long = insertIdFor("x".repeat(30) + "-" + "y".repeat(30));
  assertEquals(long.length, 36);
  assertEquals(long.endsWith("y".repeat(30)), true);
});

Deno.test("sendServerEvents posts the events and reports success", async () => {
  const calls: Array<{ url: string; body: string }> = [];
  const fakeFetch = (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), body: String(init?.body) });
    return Promise.resolve(new Response("1", { status: 200 }));
  };
  const event = buildServerEvent({
    token: "tok",
    event: "E",
    userId: "u",
    insertId: "i",
    time: 1,
    properties: {},
    attribution: {},
  });
  assertEquals(await sendServerEvents([event], fakeFetch), true);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, "https://api.mixpanel.com/track");
  assertEquals(JSON.parse(calls[0].body)[0].event, "E");
});

Deno.test("sendServerEvents never throws: a network error or a refusal is false", async () => {
  const event = buildServerEvent({
    token: "tok",
    event: "E",
    userId: "u",
    insertId: "i",
    time: 1,
    properties: {},
    attribution: {},
  });
  const throwing = () => Promise.reject(new Error("offline"));
  assertEquals(await sendServerEvents([event], throwing), false);
  const refusing = () => Promise.resolve(new Response("0", { status: 200 }));
  assertEquals(await sendServerEvents([event], refusing), false);
  const failing = () => Promise.resolve(new Response("x", { status: 500 }));
  assertEquals(await sendServerEvents([event], failing), false);
});
