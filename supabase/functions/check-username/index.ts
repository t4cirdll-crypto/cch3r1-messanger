// Supabase Edge Function: check-username
//
// Проверяет, свободен ли указанный никнейм.
// Вызов:  POST /functions/v1/check-username
// Тело:   { "username": "alex_01" }
// Ответ:  { "available": true | false, "normalized": "alex_01" }
//
// Функция НЕ требует JWT (см. deploy --no-verify-jwt), чтобы её можно было
// вызывать с экрана регистрации до создания пользователя.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
      ...(init.headers ?? {}),
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, { status: 405 });
  }

  let payload: { username?: unknown };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, { status: 400 });
  }

  const raw = typeof payload.username === 'string' ? payload.username : '';
  const normalized = raw.trim().toLowerCase();

  if (!USERNAME_RE.test(normalized)) {
    return json(
      {
        available: false,
        normalized,
        error: 'invalid_format',
        message:
          'Ник должен содержать 3–20 символов: латиница, цифры, подчёркивание.',
      },
      { status: 200 },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'server_misconfigured' }, { status: 500 });
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await client
    .from('profiles')
    .select('id')
    .eq('username', normalized)
    .limit(1)
    .maybeSingle();

  if (error) {
    return json({ error: 'database_error', details: error.message }, { status: 500 });
  }

  return json({ available: data === null, normalized });
});
