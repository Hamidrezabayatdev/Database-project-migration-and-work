import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import api from '../api'

function StatusBadge({ status }) {
  return <span className={`badge badge-${status}`}>{status}</span>
}

function MatchScore({ score }) {
  if (score == null) return <span style={{ color: 'var(--muted)' }}>—</span>
  const cls = score >= 70 ? 'match-high' : score >= 40 ? 'match-medium' : 'match-low'
  return <span className={`match-score ${cls}`}>{score.toFixed(0)}%</span>
}

export default function Dashboard() {
  const [data, setData]     = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/me')
      .then(r => setData(r.data))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <main className="page-main">
        <div className="container">
          <p style={{ color: 'var(--muted)' }}>Loading dashboard…</p>
        </div>
      </main>
    )
  }

  if (!data) {
    return (
      <main className="page-main">
        <div className="container">
          <div className="alert alert-error">Could not load dashboard. Please try again.</div>
        </div>
      </main>
    )
  }

  const { profile, applications, notifications } = data
  const pct = profile.profile_completeness_pct ?? 0

  return (
    <main className="page-main">
      <div className="container">
        <div className="page-header">
          <div>
            <h1>My Dashboard</h1>
            <p>Welcome back, {profile.full_name || 'User'}</p>
          </div>
          <Link to="/jobs" className="btn btn-primary btn-sm">Browse Jobs →</Link>
        </div>

        <div className="dashboard-grid">
          {/* Left column — Profile card */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="card">
              <h3 style={{ fontSize: 15, fontWeight: 600, marginBottom: 16 }}>Profile</h3>

              <div style={{ marginBottom: 12 }}>
                <p style={{ fontSize: 18, fontWeight: 700 }}>{profile.full_name || '—'}</p>
                {profile.nationality && (
                  <p style={{ fontSize: 13, color: 'var(--muted)' }}>🌍 {profile.nationality}</p>
                )}
              </div>

              <div className="stat-bar-wrap">
                <div className="stat-bar-label">
                  <span style={{ fontSize: 13 }}>Profile Completeness</span>
                  <strong style={{ fontSize: 13 }}>{pct}%</strong>
                </div>
                <div className="stat-bar">
                  <div
                    className="stat-bar-fill"
                    style={{
                      width: `${pct}%`,
                      background: pct >= 80 ? 'var(--success)' : pct >= 60 ? 'var(--primary)' : 'var(--warning)',
                    }}
                  />
                </div>
              </div>

              {pct < 60 && (
                <p style={{ fontSize: 12, color: 'var(--error)', marginTop: 8 }}>
                  ⚠️ Complete at least 60% to apply for jobs
                </p>
              )}

              {profile.bio && (
                <p style={{ fontSize: 13, color: 'var(--muted)', marginTop: 12, lineHeight: 1.5 }}>
                  {profile.bio}
                </p>
              )}
            </div>

            {/* Stats */}
            <div className="card">
              <h3 style={{ fontSize: 15, fontWeight: 600, marginBottom: 14 }}>Activity</h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                {[
                  { label: 'Total Applied',  value: applications.length },
                  { label: 'In Review',      value: applications.filter(a => a.status === 'reviewing').length },
                  { label: 'Interviews',     value: applications.filter(a => a.status === 'interview').length },
                  { label: 'Offers',         value: applications.filter(a => a.status === 'offer').length },
                ].map(stat => (
                  <div key={stat.label} style={{ textAlign: 'center' }}>
                    <p style={{ fontSize: 28, fontWeight: 700, color: 'var(--primary)' }}>{stat.value}</p>
                    <p style={{ fontSize: 12, color: 'var(--muted)' }}>{stat.label}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Notifications */}
            <div className="card">
              <h3 style={{ fontSize: 15, fontWeight: 600, marginBottom: 14 }}>Notifications</h3>
              {notifications.length === 0 ? (
                <p style={{ fontSize: 13, color: 'var(--muted)' }}>No notifications yet.</p>
              ) : (
                notifications.map(n => (
                  <div key={n.notif_id} className="notif-item">
                    <p className="title" style={{ fontWeight: n.is_read ? 400 : 600 }}>
                      {!n.is_read && <span style={{ color: 'var(--primary)', marginRight: 4 }}>●</span>}
                      {n.title}
                    </p>
                    {n.message && <p className="msg">{n.message}</p>}
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Right column — Applications table */}
          <div className="card" style={{ padding: 0 }}>
            <div style={{ padding: '20px 24px 12px' }}>
              <h3 style={{ fontSize: 15, fontWeight: 600 }}>My Applications</h3>
            </div>

            {applications.length === 0 ? (
              <div className="empty-state">
                <h3>No applications yet</h3>
                <p>Head to the Jobs page to apply for your first position.</p>
                <Link to="/jobs" className="btn btn-primary btn-sm" style={{ marginTop: 14 }}>
                  Browse Jobs
                </Link>
              </div>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Job Title</th>
                      <th>Company</th>
                      <th>Status</th>
                      <th>Match</th>
                      <th>Applied</th>
                    </tr>
                  </thead>
                  <tbody>
                    {applications.map(app => (
                      <tr key={app.app_id}>
                        <td style={{ fontWeight: 500 }}>{app.job_title}</td>
                        <td style={{ color: 'var(--muted)' }}>{app.company}</td>
                        <td><StatusBadge status={app.status} /></td>
                        <td><MatchScore score={app.match_score} /></td>
                        <td style={{ color: 'var(--muted)', fontSize: 13 }}>
                          {app.applied_at ? new Date(app.applied_at).toLocaleDateString() : '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  )
}
