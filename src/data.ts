// Phase 1: TypeScript shapes for entities. All data is loaded from Supabase via storage.ts.

export type FormTemplateCode = 'ambience' | 'curriculum' | 'faculty' | 'library';
export type Role             = 'super_admin' | 'department_admin';
export type OfferingStatus   = 'draft' | 'published' | 'archived';
export type CampaignStatus   = 'draft' | 'open' | 'closed' | 'archived';

export interface Department {
  id: string;
  name: string;
  code: string;
  is_fy_pool: boolean;
  is_archived: boolean;
}

export interface AcademicYear {
  id: string;
  label: string;
  start_date: string;
  end_date: string;
  is_current: boolean;
}

export interface Division {
  id: string;
  department_id: string;
  year_of_study: 1 | 2 | 3 | 4;
  name: string;
  is_archived: boolean;
}

export interface Subject {
  id: string;
  owner_department_id: string;
  name: string;
  code: string | null;
  is_fy_common: boolean;
  is_archived: boolean;
}

export interface Teacher {
  id: string;
  department_id: string;
  name: string;
  email: string | null;
  is_archived: boolean;
}

export interface Offering {
  id: string;
  division_id: string;
  semester: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8;
  academic_year_id: string;
  status: OfferingStatus;
}

export interface OfferingSubject {
  id: string;
  offering_id: string;
  subject_id: string;
  teacher_id: string | null;
}

export interface FormQuestion {
  id: string;
  text: string;
  options?: string[];
}

export interface FormSchema {
  scaleLabels: string[];
  questions: FormQuestion[];
  remarkPrompts: { id: string; label: string }[];
  identityFields: string[];
  specialQuestions?: Array<{
    id: string;
    label: string;
    type: 'choice';
    options: string[];
  }>;
}

export interface FormTemplate {
  id: string;
  code: FormTemplateCode;
  title: string;
  anonymous: boolean;
  requires_per_subject: boolean;
  schema: FormSchema;
}

export interface Campaign {
  id: string;
  template_id: string;
  name: string;
  scope_department_id: string | null;
  opens_at: string;
  closes_at: string;
  status: CampaignStatus;
}

export interface Submission {
  id: string;
  campaign_id: string;
  offering_id: string;
  offering_subject_id: string | null;
  template_id: string;
  identity: unknown | null;
  answers: unknown;
  remarks: unknown | null;
  submitted_at: string;
  is_hidden: boolean;
}
