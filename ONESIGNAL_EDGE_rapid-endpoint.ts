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
      return new Response(JSON.stringify({ error: "ONESIGNAL_REST_API_KEY manquant" }), {
        status: 500,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    const bodyIn = await req.json();
    const user_ids = bodyIn.user_ids || [];
    const title = bodyIn.title || "Pressing Connecté";
    const body = bodyIn.body || "";
    const url = bodyIn.url || "https://pressing-web.netlify.app/";

    if (!user_ids.length) {
      return new Response(JSON.stringify({ error: "user_ids requis" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const payload = {
      app_id: APP_ID,
      include_aliases: { external_id: user_ids.map(String) },
      target_channel: "push",
      headings: { en: title, fr: title },
      contents: { en: body, fr: body },
      url,
      // Priorité max — évite les notifs "silencieuses"
      priority: 10,
      ttl: 2419200,
      isAnyWeb: true,
      chrome_web_icon: "https://pressing-web.netlify.app/icon-192.png",
      firefox_icon: "https://pressing-web.netlify.app/icon-192.png",
      chrome_web_badge: "https://pressing-web.netlify.app/icon-192.png",
    };

    // Essai Authorization: Key ... puis Basic ...
    let res = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Key " + REST_KEY,
      },
      body: JSON.stringify(payload),
    });
    let data = await res.json().catch(() => ({}));

    if (!res.ok && (res.status === 401 || res.status === 403)) {
      res = await fetch("https://api.onesignal.com/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Basic " + REST_KEY,
        },
        body: JSON.stringify(payload),
      });
      data = await res.json().catch(() => ({}));
    }

    return new Response(JSON.stringify({
      ok: res.ok,
      status: res.status,
      recipients: data.recipients,
      id: data.id,
      errors: data.errors,
      data,
    }), {
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
