// Kheyrukum Free-Tier (Firebase Spark Plan) Push Notification Dispatcher
// Sends push alerts via Firebase Cloud Messaging HTTP v1 API with zero paid tiers.
// Required Supabase Edge Function Secrets:
//   - FIREBASE_SERVICE_ACCOUNT_JSON : JSON (or base64 JSON) of your Firebase Service Account key
// Automatically injected by Supabase Runtime:
//   - SUPABASE_URL
//   - SUPABASE_SERVICE_ROLE_KEY

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const DEFAULT_CHANNEL_ID = "kheyrukum_channel";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function parseServiceAccount(raw: string): ServiceAccount {
  const trimmed = raw.trim();
  const jsonText = trimmed.startsWith("{") ? trimmed : atob(trimmed);
  const parsed = JSON.parse(jsonText);
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("Invalid FIREBASE_SERVICE_ACCOUNT_JSON fields.");
  }
  return parsed as ServiceAccount;
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    }),
  );

  const unsignedJwt = `${header}.${claim}`;
  const keyData = pemToArrayBuffer(sa.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const jwt = `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResp = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const errText = await tokenResp.text();
    throw new Error(`Google OAuth2 failed (${tokenResp.status}): ${errText}`);
  }

  const tokenData = await tokenResp.json();
  return tokenData.access_token as string;
}

function stringifyDataMap(
  rawData: Record<string, unknown> | undefined,
  title: string,
  body: string,
  type: string,
): Record<string, string> {
  const result: Record<string, string> = {
    title,
    body,
    type,
  };
  if (rawData && typeof rawData === "object") {
    for (const [k, v] of Object.entries(rawData)) {
      if (v !== undefined && v !== null) {
        result[k] = typeof v === "string" ? v : JSON.stringify(v);
      }
    }
  }
  return result;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!saRaw || saRaw.trim() === "") {
      return new Response(
        JSON.stringify({
          success: false,
          configured: false,
          message:
            "FIREBASE_SERVICE_ACCOUNT_JSON secret is not configured in Supabase Edge Function secrets.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    }

    const payload = await req.json();
    const title = String(payload.title ?? "Kheyrukum Islamic Center").trim();
    const body = String(payload.body ?? "").trim();
    const type = String(payload.type ?? "general").trim();
    const targetAudience = String(payload.target_audience ?? "").trim();
    const excludeUserId = payload.exclude_user_id
      ? String(payload.exclude_user_id).trim()
      : null;
    const requestedUserIds: string[] = Array.isArray(payload.user_ids)
      ? payload.user_ids.map((u: unknown) => String(u).trim()).filter(Boolean)
      : [];

    if (!title && !body) {
      return new Response(
        JSON.stringify({ success: false, message: "Missing title or body." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const sbHeaders = {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    };

    // Resolve recipient user IDs
    const recipientIds = new Set<string>(requestedUserIds);

    const resolveRoleUsers = async (roleFilter?: string) => {
      let url =
        `${supabaseUrl}/rest/v1/profiles?select=id,is_suspended&or=(is_suspended.is.null,is_suspended.eq.false)`;
      if (roleFilter) {
        url += `&role=eq.${encodeURIComponent(roleFilter)}`;
      }
      const res = await fetch(url, { headers: sbHeaders });
      if (res.ok) {
        const rows = (await res.json()) as Array<{ id: string }>;
        for (const r of rows) {
          if (r.id) recipientIds.add(r.id);
        }
      }
    };

    if (targetAudience === "admins") {
      await resolveRoleUsers("admin");
    } else if (targetAudience === "parents") {
      await resolveRoleUsers("parent");
    } else if (targetAudience === "teachers") {
      await resolveRoleUsers("teacher");
    } else if (targetAudience === "all" && recipientIds.size === 0) {
      await resolveRoleUsers();
    }

    if (excludeUserId) {
      recipientIds.delete(excludeUserId);
    }

    if (recipientIds.size === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          message: "No eligible recipients found.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const idList = Array.from(recipientIds);
    const inClause = idList.map((id) => encodeURIComponent(id)).join(",");
    const tokensUrl =
      `${supabaseUrl}/rest/v1/user_device_tokens?select=device_token,user_id,provider` +
      `&user_id=in.(${inClause})` +
      `&provider=eq.fcm`;

    const tokensResp = await fetch(tokensUrl, { headers: sbHeaders });
    if (!tokensResp.ok) {
      const txt = await tokensResp.text();
      throw new Error(`Failed to fetch device tokens: ${txt}`);
    }

    const tokenRows = (await tokensResp.json()) as Array<{
      device_token: string;
      user_id: string;
      provider?: string;
    }>;

    const uniqueTokens = Array.from(
      new Set(
        tokenRows
          .map((r) => r.device_token)
          .filter((t) => Boolean(t) && !t.startsWith("dev_")),
      ),
    );

    if (uniqueTokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          message: "No active FCM device tokens registered for target users.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const serviceAccount = parseServiceAccount(saRaw);
    const accessToken = await getGoogleAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    const stringData = stringifyDataMap(payload.data, title, body, type);

    let sentCount = 0;
    const staleTokens: string[] = [];
    const errors: string[] = [];

    for (const token of uniqueTokens) {
      const messageBody = {
        message: {
          token,
          notification: {
            title,
            body,
          },
          data: stringData,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: DEFAULT_CHANNEL_ID,
              sound: "default",
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      };

      const fcmRes = await fetch(fcmEndpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(messageBody),
      });

      if (fcmRes.ok) {
        sentCount++;
      } else {
        const errBody = await fcmRes.text();
        errors.push(errBody.slice(0, 200));
        if (
          fcmRes.status === 404 ||
          errBody.includes("UNREGISTERED") ||
          errBody.includes("registration-token-not-registered")
        ) {
          staleTokens.push(token);
        }
      }
    }

    // Automatically prune unregistered / uninstalled FCM tokens
    for (const badToken of staleTokens) {
      await fetch(
        `${supabaseUrl}/rest/v1/user_device_tokens?device_token=eq.${encodeURIComponent(
          badToken,
        )}`,
        {
          method: "DELETE",
          headers: sbHeaders,
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: sentCount,
        total_tokens: uniqueTokens.length,
        pruned_tokens: staleTokens.length,
        errors: errors.slice(0, 5),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        success: false,
        message: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
