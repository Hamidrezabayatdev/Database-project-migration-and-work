import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import api from '../api'

export default function Login() {
  const navigate = useNavigate()
  const [form, setForm]         = useState({ email: '', password: '' })
  const [errors, setErrors]     = useState({})
  const [apiError, setApiError] = useState('')
  const [loading, setLoading]   = useState(false)

  function validate() {
    const e = {}
    if (!form.email.trim())    e.email    = 'Email is required'
    if (!form.password.trim()) e.password = 'Password is required'
    return e
  }

  async function handleSubmit(ev) {
    ev.preventDefault()
    setApiError('')
    const e = validate()
    setErrors(e)
    if (Object.keys(e).length) return

    setLoading(true)
    try {
      const { data } = await api.post('/login', {
        email:    form.email.trim(),
        password: form.password,
      })
      localStorage.setItem('token', data.access_token)
      localStorage.setItem('user', JSON.stringify({ full_name: data.full_name, email: data.email }))
      navigate('/jobs')
    } catch (err) {
      setApiError(err.response?.data?.detail || 'Login failed. Check your credentials.')
    } finally {
      setLoading(false)
    }
  }

  function set(field) {
    return (ev) => {
      setForm(f => ({ ...f, [field]: ev.target.value }))
      setErrors(e => ({ ...e, [field]: '' }))
    }
  }

  return (
    <div className="page-center">
      <div className="card card-sm">
        <div className="auth-header">
          <h1>🌐 MigrateUp</h1>
          <p>Sign in to your account</p>
        </div>

        {apiError && <div className="alert alert-error">{apiError}</div>}

        <form onSubmit={handleSubmit} noValidate>
          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              placeholder="ali@example.com"
              value={form.email}
              onChange={set('email')}
              className={errors.email ? 'error-field' : ''}
              autoComplete="email"
            />
            {errors.email && <p className="field-error">{errors.email}</p>}
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              placeholder="Your password"
              value={form.password}
              onChange={set('password')}
              className={errors.password ? 'error-field' : ''}
              autoComplete="current-password"
            />
            {errors.password && <p className="field-error">{errors.password}</p>}
          </div>

          <button type="submit" className="btn btn-primary btn-full" disabled={loading}>
            {loading ? <span className="spinner" /> : 'Sign In'}
          </button>
        </form>

        <hr className="divider" />

        <div style={{ fontSize: 13, color: 'var(--muted)', marginBottom: 12 }}>
          <strong>Demo users (password: Password123!):</strong>
          <ul style={{ marginTop: 6, paddingLeft: 16 }}>
            <li>ali.rezaei@example.com</li>
            <li>leila.ahmadi@example.com</li>
            <li>reza.nouri@example.com</li>
          </ul>
        </div>

        <p style={{ textAlign: 'center', fontSize: 14 }}>
          No account? <Link to="/register" className="link">Register here</Link>
        </p>
      </div>
    </div>
  )
}
