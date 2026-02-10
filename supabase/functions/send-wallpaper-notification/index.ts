import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Firebase V1 API configuration
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")!;

serve(async (req) => {
  try {
    const { wallpaper_id } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log(`Processing wallpaper notification for: ${wallpaper_id}`);

    // Fetch wallpaper details
    const { data: wallpaper, error: wallpaperError } = await supabase
      .from("wallpapers")
      .select("*")
      .eq("id", wallpaper_id)
      .single();

    if (wallpaperError || !wallpaper) {
      throw new Error(`Wallpaper not found: ${wallpaper_id}`);
    }

    // Fetch users in the pair with FCM tokens AND display names
    const { data: users, error: usersError } = await supabase
      .from("users")
      .select("id, fcm_token, display_name")
      .eq("pair_id", wallpaper.pair_id)
      .not("fcm_token", "is", null);

    if (usersError || !users || users.length === 0) {
      throw new Error("No users with FCM tokens found");
    }

    // Get sender's display name and first name
    const sender = users.find(u => u.id === wallpaper.sender_id);
    const senderName = sender?.display_name || "";
    const senderFirstName = senderName.split(" ").filter(Boolean)[0] || "Your partner";

    // Determine recipients based on apply_to
    let recipients = [];
    if (wallpaper.apply_to === "both") {
      recipients = users;
    } else if (wallpaper.apply_to === "partner") {
      if (wallpaper.sender_id === "00000000-0000-0000-0000-000000000000") {
        // System sender: notify both
        recipients = users;
      } else {
        // Regular sender: notify only partner
        recipients = users.filter(u => u.id !== wallpaper.sender_id);
      }
    }

    console.log(`Sending to ${recipients.length} recipients`);

    // Generate Firebase access token
    const accessToken = await getFirebaseAccessToken();

    // Send FCM to each recipient using Firebase V1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
    const results = [];

    for (const recipient of recipients) {
      const isSender = recipient.id === wallpaper.sender_id;

      const response = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: recipient.fcm_token,
            data: {
              type: "wallpaper_sync",
              wallpaper_id: wallpaper.id,
              image_url: wallpaper.image_url,
              sender_id: wallpaper.sender_id,
              pair_id: wallpaper.pair_id,
              apply_to: wallpaper.apply_to,
              source_type: wallpaper.source_type || "shared_board",
              sender_name: senderName,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  "mutable-content": 1,
                  alert: {
                    title: isSender
                      ? "Wallpaper updated"
                      : `New wallpaper from ${senderFirstName}`,
                    body: isSender
                      ? "Your wallpaper was just applied."
                      : `${senderFirstName} has sent you a new wallpaper! It will be applied when your next Shortcut automation runs.`,
                  },
                },
              },
            },
          },
        }),
      });

      const result = await response.json();
      results.push({ user_id: recipient.id, result });

      if (!response.ok) {
        console.error(`FCM error for user ${recipient.id}:`, result);
      } else {
        console.log(`FCM sent successfully to user ${recipient.id}`);
      }
    }

    return new Response(
      JSON.stringify({ success: true, sent: results.length, results }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending notifications:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function getFirebaseAccessToken(): Promise<string> {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: firebaseClientEmail,
    sub: firebaseClientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encodedHeader = base64urlEncode(JSON.stringify(header));
  const encodedPayload = base64urlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Import private key
  const privateKeyPem = firebasePrivateKey.replace(/\\n/g, "\n");
  const privateKey = await importPrivateKey(privateKeyPem);

  // Sign the token
  const signature = await sign(unsignedToken, privateKey);
  const jwt = `${unsignedToken}.${signature}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = base64Decode(pemContents);

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

async function sign(data: string, key: CryptoKey): Promise<string> {
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(data)
  );
  return base64urlEncode(signature);
}

function base64urlEncode(data: string | ArrayBuffer): string {
  let base64: string;
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    base64 = btoa(String.fromCharCode(...new Uint8Array(data)));
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function base64Decode(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
