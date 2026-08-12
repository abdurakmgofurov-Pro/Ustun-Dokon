// Supabase Edge Function: manage-employee
// Faqat admin foydalanuvchi yangi xodim yaratishi yoki xodimni butunlay
// o'chirib tashlashi mumkin. Bu funksiya service_role kalitidan FAQAT
// shu yerda, server tomonida foydalanadi — u hech qachon Flutter ilovaga
// yoki brauzerga chiqmaydi.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Chaqiruvchi (caller) kim ekanini uning o'z tokeni bilan aniqlaymiz
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } =
      await callerClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Tizimga kirilmagan" }, 401);
    }

    // service_role bilan admin ekanini tekshiramiz va amalni bajaramiz
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: callerProfile, error: profileErr } = await adminClient
      .from("profiles")
      .select("role, is_active")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (profileErr || !callerProfile || callerProfile.role !== "admin" ||
      !callerProfile.is_active) {
      return json({ error: "Faqat admin bu amalni bajara oladi" }, 403);
    }

    const body = await req.json();

    if (body.action === "create") {
      const { email, password, full_name, role } = body;
      if (!email || !password || !full_name) {
        return json({ error: "Barcha maydonlarni to'ldiring" }, 400);
      }
      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name,
          role: role === "admin" ? "admin" : "sotuvchi",
        },
      });
      if (error) return json({ error: error.message }, 400);
      return json({ user: data.user });
    }

    if (body.action === "delete") {
      const { user_id } = body;
      if (!user_id) return json({ error: "user_id kerak" }, 400);
      if (user_id === userData.user.id) {
        return json({ error: "O'zingizni o'chira olmaysiz" }, 400);
      }
      const { error } = await adminClient.auth.admin.deleteUser(user_id);
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }

    return json({ error: "Noma'lum amal" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
