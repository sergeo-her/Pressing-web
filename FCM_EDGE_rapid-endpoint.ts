import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") || "pressingconnect-b6f08";
const SA_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") || "";

async function getAccessToken() {
  if (!SA_JSON) throw new Error("FCM_SERVICE_ACCOUNT_JSON manquant");
  const sa = JSON.parse(SA_JSON);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const payload = btoa(JSON.stringify(claim))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const data = new TextEncoder().encode(`${header}.${payload}`);

  // Import PEM private key
  const pem = sa.private_key as string;
  const pemBody = pem.replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, data);
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const jwt = `${header}.${payload}.${sig}`;

  const tokRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tok = await tokRes.json();
  if (!tok.access_token) throw new Error("OAuth token failed: " + JSON.stringify(tok));
  return tok.access_token as string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { user_ids, title, body, url } = await req.json();
    if (!user_ids?.length) {
      return new Response(JSON.stringify({ error: "user_ids requis" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: rows, error } = await sb
      .from("fcm_tokens")
      .select("token")
      .in("user_id", user_ids);
    if (error) throw error;
    const tokens = [...new Set((rows || []).map((r: { token: string }) => r.token).filter(Boolean))];
    if (!tokens.length) {
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "no tokens" }), {
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const access = await getAccessToken();
    let sent = 0;
    const errors: string[] = [];
    for (const token of tokens) {
      const message = {
        message: {
          token,
          notification: {
            title: title || "Pressing Connecté",
            body: body || "",
          },
          webpush: {
            headers: { Urgency: "high" },
            notification: {
              icon: "https://pressing-web.netlify.app/icon-192.png",
              badge: "https://pressing-web.netlify.app/icon-192.png",
            },
            fcmOptions: {
              link: url || "https://pressing-web.netlify.app/",
            },
          },
          data: {
            title: title || "Pressing Connecté",
            body: body || "",
            url: url || "https://pressing-web.netlify.app/",
          },
        },
      };
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: "Bearer " + access,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        },
      );
      if (res.ok) sent++;
      else {
        const t = await res.text();
        errors.push(t.slice(0, 200));
        // token invalide → supprimer
        if (res.status === 404 || /UNREGISTERED|INVALID/i.test(t)) {
          await sb.from("fcm_tokens").delete().eq("token", token);
        }
      }
    }

    return new Response(JSON.stringify({ ok: true, sent, total: tokens.length, errors: errors.slice(0, 3) }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message || String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
