import { supabase } from './supabase';

export type Role = 'super_admin' | 'department_admin';

export interface AdminProfile {
  userId: string;
  role: Role;
  departmentId: string | null;
}

export async function signIn(email: string, password: string): Promise<void> {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

export async function signOut(): Promise<void> {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentProfile(): Promise<AdminProfile | null> {
  const { data: session } = await supabase.auth.getSession();
  if (!session.session) return null;

  const { data, error } = await supabase
    .from('user_profiles')
    .select('user_id, role, department_id')
    .eq('user_id', session.session.user.id)
    .single();

  if (error) return null;
  return {
    userId: data.user_id,
    role: data.role,
    departmentId: data.department_id,
  };
}

export function onAuthChange(cb: (profile: AdminProfile | null) => void): () => void {
  const { data } = supabase.auth.onAuthStateChange(async () => {
    cb(await getCurrentProfile());
  });
  return () => data.subscription.unsubscribe();
}
