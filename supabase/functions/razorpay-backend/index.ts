import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import crypto from "node:crypto";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = await req.json();
    const { action } = body;

    const keyId = Deno.env.get("RAZORPAY_KEY_ID") || "rzp_test_TAiZywLMiBlJuG";
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "ehrQ4edUdNzEZqtTE334Lcsf";

    if (action === "create-order") {
      const { amount, product, duration } = body;
      const receiptId = `rcpt_${Math.random().toString(36).substring(2, 12)}`;

      const res = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Basic " + btoa(`${keyId}:${keySecret}`),
        },
        body: JSON.stringify({
          amount: Math.round(amount * 100), // in paise
          currency: "INR",
          receipt: receiptId,
          notes: { product, duration }
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        return new Response(JSON.stringify({ success: false, error: data.error }), {
          status: res.status,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({ success: true, order: data }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    if (action === "verify-payment") {
      const { orderId, paymentId, signature, product, duration, amount, userId } = body;

      // Verify signature on Deno backend using HMAC-SHA256
      const expected = crypto
        .createHmac("sha256", keySecret)
        .update(`${orderId}|${paymentId}`)
        .digest("hex");

      if (expected !== signature) {
        return new Response(JSON.stringify({ success: false, error: "Signature Mismatch" }), {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      // Initialize Supabase Client
      const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      // Call database transaction RPC
      const { data: rpcRes, error: rpcErr } = await supabase.rpc("verify_and_activate_vip_rpc", {
        p_order_id: orderId,
        p_payment_id: paymentId,
        p_signature: signature,
        p_product: product,
        p_duration: duration,
        p_amount: amount,
        p_user_id: userId,
      });

      if (rpcErr) {
        return new Response(JSON.stringify({ success: false, error: rpcErr.message }), {
          status: 500,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: false, error: "Invalid Action" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ success: false, error: e.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
