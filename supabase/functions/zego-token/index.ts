import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import crypto from "node:crypto";
import { Buffer } from "node:buffer";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function makeNonce(): number {
  const min = -Math.pow(2, 31); // -2^31
  const max = Math.pow(2, 31) - 1; // 2^31 - 1
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// AES encryption using GCM mode
function aesGcmEncrypt(plainText: string, key: string) {
  const keyBuf = Buffer.from(key, "utf8");
  if (![16, 24, 32].includes(keyBuf.length)) {
    throw new Error("Invalid Secret length. Key must be 16, 24, or 32 bytes.");
  }
  
  // Random 12-byte initialization vector (IV)
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", keyBuf, nonce);
  
  const encrypted = Buffer.concat([
    cipher.update(plainText, "utf8"),
    cipher.final(),
    cipher.getAuthTag(), // Galois authentication tag appended
  ]);
  
  return { encryptBuf: encrypted, nonce };
}

function generateToken04(
  appId: number,
  userId: string,
  secret: string,
  effectiveTimeInSeconds: number,
  payload?: string
): string {
  if (!appId || typeof appId !== "number") {
    throw new Error("appID invalid");
  }
  if (!userId || typeof userId !== "string" || userId.length > 64) {
    throw new Error("userId invalid");
  }
  if (!secret || typeof secret !== "string" || secret.length !== 32) {
    throw new Error("secret must be a 32 byte string");
  }
  if (!(effectiveTimeInSeconds > 0)) {
    throw new Error("effectiveTimeInSeconds invalid");
  }

  const VERSION_FLAG = "04";
  const createTime = Math.floor(Date.now() / 1000);
  const tokenInfo = {
    app_id: appId,
    user_id: userId,
    nonce: makeNonce(),
    ctime: createTime,
    expire: createTime + effectiveTimeInSeconds,
    payload: payload || "",
  };

  const plainText = JSON.stringify(tokenInfo);
  const { encryptBuf, nonce } = aesGcmEncrypt(plainText, secret);

  // Buffer formatting: Expire (8) + IV Length (2) + IV + Ciphertext Length (2) + Ciphertext + Encryption Mode (1)
  const b1 = new Uint8Array(8);
  const b2 = new Uint8Array(2);
  const b3 = new Uint8Array(2);
  const b4 = new Uint8Array(1);

  new DataView(b1.buffer).setBigInt64(0, BigInt(tokenInfo.expire), false); // Big-Endian
  new DataView(b2.buffer).setUint16(0, nonce.byteLength, false); // Big-Endian
  new DataView(b3.buffer).setUint16(0, encryptBuf.byteLength, false); // Big-Endian
  new DataView(b4.buffer).setUint8(0, 1); // 1 = AesEncryptMode.GCM

  const buf = Buffer.concat([
    Buffer.from(b1),
    Buffer.from(b2),
    Buffer.from(nonce),
    Buffer.from(b3),
    Buffer.from(encryptBuf),
    Buffer.from(b4),
  ]);

  return VERSION_FLAG + buf.toString("base64");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { userId, payload } = await req.json();
    if (!userId) {
      return new Response(JSON.stringify({ error: "userId is required" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Retrieve credentials from Deno environment variables or fallback to provided credentials
    const appId = Number(Deno.env.get("ZEGO_APP_ID") || "393055653");
    const serverSecret = Deno.env.get("ZEGO_SERVER_SECRET") || "83f462c738fa0d1499c1aa1c377ef3ac";
    const effectiveTime = Number(Deno.env.get("ZEGO_TOKEN_EXPIRY") || "7200"); // Default to 2 hours

    const createTime = Math.floor(Date.now() / 1000);
    const expire = createTime + effectiveTime;
    const token = generateToken04(appId, userId, serverSecret, effectiveTime, payload);

    return new Response(JSON.stringify({ token, appId, expire }), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
