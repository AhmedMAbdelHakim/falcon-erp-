import { createClient } from '@supabase/supabase-js'
import type { Database } from '../types/database.generated'

const configuredUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const configuredKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()

export const isSupabaseConfigured = Boolean(configuredUrl && configuredKey)

// The inert local fallback keeps the configuration error screen renderable. It is
// never treated as a working backend and contains no credential or remote URL.
export const supabase = createClient<Database>(
  configuredUrl || 'http://127.0.0.1:54321',
  configuredKey || 'missing-public-browser-key',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)
