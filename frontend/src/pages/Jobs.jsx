import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import api from '../api'

function matchClass(score) {
  if (score == null) return ''
  if (score >= 70) return 'match-high'
  if (score >= 40) return 'match-medium'
  return 'match-low'
}

function formatSalary(min, max, currency) {
  if (!min && !max) return null
  const fmt = (n) => n >= 1000 ? `${(n / 1000).toFixed(0)}k` : n
  if (min && max) return `${currency} ${fmt(min)}–${fmt(max)}`
  if (min) return `${currency} ${fmt(min)}+`
  return `Up to ${currency} ${fmt(max)}`
}

export default function Jobs() {
  const [jobs, setJobs]       = useState([])
  const [loading, setLoading] = useState(true)
  const [applying, setApplying] = useState(null)   // job being applied to
  const [coverLetter, setCoverLetter] = useState('')
  const [applyError, setApplyError]   = useState('')
  const [applySuccess, setApplySuccess] = useState('')
  const [submitting, setSubmitting]   = useState(false)
  const [applied, setApplied] = useState(new Set()) // already-applied job ids

  useEffect(() => {
    api.get('/jobs')
      .then(r => setJobs(r.data))
      .catch(() => {})
      .finally(() => setLoading(false))

    // Load applied jobs from dashboard
    api.get('/me')
      .then(r => {
        const ids = r.data.applications.map(a => a.job_id ?? null)
        setApplied(new Set(ids.filter(Boolean)))
      })
      .catch(() => {})
  }, [])

  function openModal(job) {
    setApplying(job)
    setCoverLetter('')
    setApplyError('')
    setApplySuccess('')
  }

  function closeModal() {
    setApplying(null)
  }

  async function submitApplication(ev) {
    ev.preventDefault()
    setApplyError('')
    setSubmitting(true)
    try {
      const { data } = await api.post(`/jobs/${applying.job_id}/apply`, {
        cover_letter: coverLetter.trim() || null,
      })
      setApplySuccess(data.message)
      setApplied(prev => new Set([...prev, applying.job_id]))
      // Close modal after short delay
      setTimeout(closeModal, 1500)
    } catch (err) {
      setApplyError(err.response?.data?.detail || 'Application failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <main className="page-main">
        <div className="container">
          <p style={{ color: 'var(--muted)' }}>Loading jobs…</p>
        </div>
      </main>
    )
  }

  return (
    <>
      <main className="page-main">
        <div className="container">
          <div className="page-header">
            <div>
              <h1>Open Positions</h1>
              <p>{jobs.length} active jobs available</p>
            </div>
            <Link to="/dashboard" className="btn btn-ghost btn-sm">My Applications →</Link>
          </div>

          {jobs.length === 0 ? (
            <div className="empty-state">
              <h3>No active jobs right now</h3>
              <p>Check back later!</p>
            </div>
          ) : (
            <div className="jobs-grid">
              {jobs.map(job => (
                <div key={job.job_id} className="job-card">
                  <div className="job-card-header">
                    <h3>{job.title}</h3>
                    <p>{job.company}</p>
                  </div>

                  <div className="job-meta">
                    {job.city && job.country && (
                      <span className="job-meta-chip">📍 {job.city}, {job.country}</span>
                    )}
                    <span className="job-meta-chip">🕐 {job.employment_type}</span>
                    {job.required_exp_years > 0 && (
                      <span className="job-meta-chip">{job.required_exp_years}+ yrs exp</span>
                    )}
                    {job.closes_at && (
                      <span className="job-meta-chip">⏰ Closes {job.closes_at}</span>
                    )}
                  </div>

                  {formatSalary(job.salary_min, job.salary_max, job.currency) && (
                    <p className="salary">
                      💰 {formatSalary(job.salary_min, job.salary_max, job.currency)} / year
                    </p>
                  )}

                  {job.required_skills?.length > 0 && (
                    <div className="skills-list">
                      {job.required_skills.slice(0, 5).map(s => (
                        <span key={s} className="skill-chip">{s}</span>
                      ))}
                      {job.required_skills.length > 5 && (
                        <span className="skill-chip" style={{ background: '#f1f5f9', color: '#64748b' }}>
                          +{job.required_skills.length - 5}
                        </span>
                      )}
                    </div>
                  )}

                  <div style={{ marginTop: 'auto' }}>
                    {applied.has(job.job_id) ? (
                      <button className="btn btn-ghost btn-sm btn-full" disabled>
                        ✓ Applied
                      </button>
                    ) : (
                      <button
                        className="btn btn-primary btn-sm btn-full"
                        onClick={() => openModal(job)}
                      >
                        Apply Now
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Apply Modal */}
      {applying && (
        <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && closeModal()}>
          <div className="modal">
            <div className="modal-header">
              <div>
                <h2>Apply for: {applying.title}</h2>
                <p>{applying.company} · {applying.city}, {applying.country}</p>
              </div>
              <button className="modal-close" onClick={closeModal}>×</button>
            </div>

            {applySuccess && <div className="alert alert-success">{applySuccess}</div>}
            {applyError   && <div className="alert alert-error">{applyError}</div>}

            {!applySuccess && (
              <form onSubmit={submitApplication}>
                <div className="form-group">
                  <label>Cover Letter <span style={{ color: 'var(--muted)', fontWeight: 400 }}>(optional)</span></label>
                  <textarea
                    rows={5}
                    placeholder="Tell the employer why you're a great fit…"
                    value={coverLetter}
                    onChange={e => setCoverLetter(e.target.value)}
                    maxLength={2000}
                  />
                  <p style={{ fontSize: 11, color: 'var(--muted)', marginTop: 4 }}>
                    {coverLetter.length}/2000 characters
                  </p>
                </div>

                <div className="modal-footer">
                  <button type="button" className="btn btn-ghost" onClick={closeModal}>Cancel</button>
                  <button type="submit" className="btn btn-primary" disabled={submitting}>
                    {submitting ? <><span className="spinner" /> Submitting…</> : 'Submit Application'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </>
  )
}
