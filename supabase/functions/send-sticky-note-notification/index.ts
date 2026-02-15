import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Firebase V1 API configuration
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")!;

serve(async (req) => {
  try {
    const body = await req.json();

    // Accept either { sticky_note_id } or { sticky_note_reply_id }
    // This mirrors the wallpaper pattern: receive just the ID, fetch the record
    const stickyNoteId = body.sticky_note_id;
    const stickyNoteReplyId = body.sticky_note_reply_id;

    if (!stickyNoteId && !stickyNoteReplyId) {
      throw new Error("Missing sticky_note_id or sticky_note_reply_id");
    }

    const isReply = !!stickyNoteReplyId;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let senderId: string;
    let pairId: string;
    let noteId: string;
    let messageText: string;

    if (isReply) {
      // Fetch the reply record
      const { data: reply, error: replyError } = await supabase
        .from("sticky_note_replies")
        .select("*")
        .eq("id", stickyNoteReplyId)
        .single();

      if (replyError || !reply) {
        throw new Error(`Reply not found: ${stickyNoteReplyId}`);
      }

      senderId = reply.sender_id;
      noteId = reply.note_id;
      messageText = reply.message;

      // Fetch the parent note to get pair_id
      const { data: note, error: noteError } = await supabase
        .from("sticky_notes")
        .select("pair_id")
        .eq("id", noteId)
        .single();

      if (noteError || !note) {
        throw new Error(`Parent note not found for reply: ${noteId}`);
      }
      pairId = note.pair_id;
    } else {
      // Fetch the note record
      const { data: note, error: noteError } = await supabase
        .from("sticky_notes")
        .select("*")
        .eq("id", stickyNoteId)
        .single();

      if (noteError || !note) {
        throw new Error(`Note not found: ${stickyNoteId}`);
      }

      senderId = note.sender_id;
      pairId = note.pair_id;
      noteId = note.id;
      messageText = note.message;
    }

    console.log(`Processing sticky note notification: isReply=${isReply}, pairId=${pairId}, senderId=${senderId}`);

    // Fetch users in the pair with FCM tokens
    const { data: users, error: usersError } = await supabase
      .from("users")
      .select("id, fcm_token, display_name")
      .eq("pair_id", pairId)
      .not("fcm_token", "is", null);

    if (usersError || !users || users.length === 0) {
      throw new Error("No users with FCM tokens found");
    }

    // Only notify the partner, not the sender
    const recipients = users.filter((u: any) => u.id !== senderId);
    if (recipients.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, message: "No recipients to notify" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get sender's display name
    const sender = users.find((u: any) => u.id === senderId);
    const senderName = sender?.display_name || "";
    const senderFirstName = senderName.split(" ").filter(Boolean)[0] || "Your partner";

    // Build notification content
    const title = isReply
      ? `${senderFirstName} replied to your note`
      : `${senderFirstName} left you a note`;
    const body = messageText.length > 100
      ? messageText.substring(0, 97) + "..."
      : messageText;

    // Generate Firebase access token
    const accessToken = await getFirebaseAccessToken();

    // Send FCM to each recipient
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
    const results = [];

    for (const recipient of recipients) {
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
              type: isReply ? "sticky_note_reply" : "sticky_note",
              note_id: noteId,
              sender_id: senderId,
              sender_name: senderName,
              message: messageText,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  alert: { title, body },
                  sound: "default",
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
    console.error("Error sending sticky note notification:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function getFirebaseAccessToken(): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
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

  const privateKeyPem = firebasePrivateKey.replace(/\\n/g, "\n");
  const privateKey = await importPrivateKey(privateKeyPem);
  const signature = await sign(unsignedToken, privateKey);
  const jwt = `${unsignedToken}.${signature}`;

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
