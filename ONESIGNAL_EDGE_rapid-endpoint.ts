import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "14ed4064-0bcf-4a8a-b6c7-41741b57a283";
const REST_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!REST_KEY) {
      return new Response(JSON.stringify({ error: "ONESIGNAL_REST_API_KEY manquant dans les secrets Supabase" }), {
        status: 500,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    const { user_ids, title, body, url } = await req.json();
    if (!user_ids?.length) {
      return new Response(JSON.stringify({ error: "user_ids requis" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    const payload = {
      app_id: APP_ID,
      include_aliases: { external_id: user_ids.map(String) },
      target_channel: "push",
      headings: { en: title || "Pressing Connecté", fr: title || "Pressing Connecté" },
      contents: { en: body || "", fr: body || "" },
      url: url || "https://pressing-web.netlify.app/",
    };
    const res = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Key " + REST_KEY,
      },
      body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    return new Response(JSON.stringify({ ok: res.ok, status: res.status, data }), {
      status: res.ok ? 200 : 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
