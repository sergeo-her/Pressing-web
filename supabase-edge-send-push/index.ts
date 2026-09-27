// Supabase Edge Function: send-push
// Déploiement :
//   supabase functions deploy send-push
// Secrets :
//   supabase secrets set VAPID_PUBLIC_KEY="..." VAPID_PRIVATE_KEY="..."
//
// Appel :
//   POST /functions/v1/send-push
//   { "user_ids": ["uuid"], "title": "...", "body": "...", "url": "/" }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:admin@pressing-connecte.app";

webpush.setVapidDetails(SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { user_ids, title, body, url } = await req.json();
    if (!user_ids?.length || !title) {
      return new Response(JSON.stringify({ error: "user_ids et title requis" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const { data: subs, error } = await supabase
      .from("push_subscriptions")
      .select("*")
      .in("user_id", user_ids);

    if (error) throw error;

    const payload = JSON.stringify({
      title,
      body: body || "",
      url: url || "/",
      tag: "pressing-connecte",
    });

    const results = [];
    for (const s of subs || []) {
      try {
        await webpush.sendNotification(
          {
            endpoint: s.endpoint,
            keys: { p256dh: s.p256dh, auth: s.auth },
          },
          payload
        );
        results.push({ endpoint: s.endpoint.slice(-20), ok: true });
      } catch (e: any) {
        if (e.statusCode === 404 || e.statusCode === 410) {
          await supabase.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
        }
        results.push({ endpoint: s.endpoint.slice(-20), ok: false, err: String(e.message || e) });
      }
    }

    return new Response(JSON.stringify({ sent: results.length, results }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
