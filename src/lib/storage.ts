import { supabase } from './supabase';
import type {
  Department, AcademicYear, Division, Subject, Teacher,
  Offering, OfferingSubject, FormTemplate, Campaign, Submission,
  FormTemplateCode,
} from '../data';

async function unwrap<T>(
  p: PromiseLike<{ data: T | null; error: { message: string } | null }>,
): Promise<T> {
  const { data, error } = await p;
  if (error) throw new Error(error.message);
  return (data ?? []) as unknown as T;
}

// -- Reads ----------------------------------------------------------------
// Phase 2/3 screens use these directly.
export const list = {
  departments:      () => unwrap<Department[]>(supabase.from('departments').select('*').eq('is_archived', false)),
  academicYears:    () => unwrap<AcademicYear[]>(supabase.from('academic_years').select('*').order('label', { ascending: false })),
  divisions:        () => unwrap<Division[]>(supabase.from('divisions').select('*').eq('is_archived', false)),
  subjects:         () => unwrap<Subject[]>(supabase.from('subjects').select('*').eq('is_archived', false)),
  teachers:         () => unwrap<Teacher[]>(supabase.from('teachers').select('*').eq('is_archived', false)),
  offerings:        () => unwrap<Offering[]>(supabase.from('offerings').select('*')),
  offeringSubjects: () => unwrap<OfferingSubject[]>(supabase.from('offering_subjects').select('*')),
  formTemplates:    () => unwrap<FormTemplate[]>(supabase.from('form_templates').select('*').order('code')),
  campaigns:        () => unwrap<Campaign[]>(supabase.from('campaigns').select('*').order('opens_at', { ascending: false })),
  submissions:      () => unwrap<Submission[]>(supabase.from('submissions').select('*').eq('is_hidden', false)),
};

// -- Public RPCs (no auth required) ---------------------------------------
export async function lookupAccessCode(code: string) {
  const { data, error } = await supabase.rpc('lookup_access_code', { p_code: code });
  if (error) throw error;
  return data;
}

export async function resolveOfferingForPrn(code: string, prn: string) {
  const { data, error } = await supabase.rpc('resolve_offering_for_prn', { p_code: code, p_prn: prn });
  if (error) throw error;
  return data;
}

export async function submitFeedback(args: {
  code: string;
  prn: string;
  templateCode: FormTemplateCode;
  offeringSubjectId: string | null;
  identity: unknown;
  answers: unknown;
  remarks: unknown;
}): Promise<string> {
  const { data, error } = await supabase.rpc('submit_feedback', {
    p_code:                args.code,
    p_prn:                 args.prn,
    p_template_code:       args.templateCode,
    p_offering_subject_id: args.offeringSubjectId,
    p_identity:            args.identity,
    p_answers:             args.answers,
    p_remarks:             args.remarks,
  });
  if (error) throw error;
  return data as string;
}

// -- Admin RPC (auth required) --------------------------------------------
export async function cloneOffering(args: {
  sourceOfferingId: string;
  targetDivisionId: string;
  targetSemester: number;
  targetAcademicYearId: string;
}): Promise<string> {
  const { data, error } = await supabase.rpc('clone_offering', {
    p_source_offering_id:      args.sourceOfferingId,
    p_target_division_id:      args.targetDivisionId,
    p_target_semester:         args.targetSemester,
    p_target_academic_year_id: args.targetAcademicYearId,
  });
  if (error) throw error;
  return data as string;
}
