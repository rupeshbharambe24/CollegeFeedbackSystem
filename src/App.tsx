import { useEffect, useState } from 'react';
import { list } from './lib/storage';
import type { FormTemplate } from './data';

export default function App() {
  const [templates, setTemplates] = useState<FormTemplate[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    list.formTemplates()
      .then(setTemplates)
      .catch((e) => setError(e.message ?? String(e)));
  }, []);

  return (
    <main style={{ padding: 24, maxWidth: 720, margin: '0 auto' }}>
      <h1 style={{ color: 'var(--color-primary)' }}>College Feedback System</h1>
      <p style={{ color: 'var(--color-muted)' }}>
        Phase 1 foundation — Supabase Cloud connectivity check.
      </p>

      {error && (
        <div
          style={{
            background: '#fef2f2',
            color: 'var(--color-error)',
            padding: 12,
            borderRadius: 8,
            border: '1px solid #fecaca',
          }}
        >
          Failed to load templates: {error}
        </div>
      )}

      {!templates && !error && <p>Loading…</p>}

      {templates && (
        <section>
          <h2>Form templates seeded ({templates.length})</h2>
          <ul>
            {templates.map((t) => (
              <li key={t.id} style={{ marginBottom: 8 }}>
                <strong>{t.title}</strong>{' '}
                <em style={{ color: 'var(--color-muted)' }}>
                  (code: {t.code}, anonymous: {t.anonymous ? 'yes' : 'no'},
                  {' '}questions: {t.schema.questions.length})
                </em>
              </li>
            ))}
          </ul>
          <p style={{ marginTop: 24, color: 'var(--color-success)' }}>
            ✓ Foundation OK. Phase 2 (admin console) and Phase 3 (student flow) build on this.
          </p>
        </section>
      )}
    </main>
  );
}
