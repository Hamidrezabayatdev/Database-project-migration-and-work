import { useState, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import api from '../api'

export default function Register() {
  const navigate = useNavigate()
  const [countries, setCountries] = useState([])
  const [loading, setLoading]     = useState(false)
  const [apiError, setApiError]   = useState('')
  const [form, setForm] = useState({
    first_name: '',
    last_name:  '',
    email:      '',
    password:   '',
    confirm:    '',
    nationality_country_id: '',
  })
  const [errors, setErrors] = useState({})

  useEffect(() => {
    api.get('/countries').then(r => setCountries(r.data)).catch(() => {})
  }, [])

  function validate() {
    const e = {}
    if (!form.first_name.trim()) e.first_name = 'First name is required'
    if (!form.last_name.trim())  e.last_name  = 'Last name is required'
    if (!form.email.trim())      e.email      = 'Email is required'
    else if (!/\S+@\S+\.\S+/.test(form.email)) e.email = 'Enter a valid email'
    if (!form.password)          e.password   = 'Password is required'
    else if (form.password.length < 6) e.password = 'Password must be at least 6 characters'
    if (form.password !== form.confirm) e.confirm = 'Passwords do not match'
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
      const payload = {
        first_name:  form.first_name.trim(),
        last_name:   form.last_name.trim(),
        email:       form.email.trim(),
        password:    form.password,
        nationality_country_id: form.nationality_country_id || null,
      }
      const { data } = await api.post('/register', payload)
      localStorage.setItem('token', data.access_token)
      localStorage.setItem('user', JSON.stringify({ full_name: data.full_name, email: data.email }))
      navigate('/jobs')
    } catch (err) {
      setApiError(err.response?.data?.detail || 'Registration failed. Please try again.')
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
          <h1>Create your account</h1>
          <p>Join MigrateUp and find your next opportunity</p>
        </div>

        {apiError && <div className="alert alert-error">{apiError}</div>}

        <form onSubmit={handleSubmit} noValidate>
          <div className="form-row">
            <div className="form-group">
              <label>First Name</label>
              <input
                type="text"
                placeholder="Ali"
                value={form.first_name}
                onChange={set('first_name')}
                className={errors.first_name ? 'error-field' : ''}
              />
              {errors.first_name && <p className="field-error">{errors.first_name}</p>}
            </div>
            <div className="form-group">
              <label>Last Name</label>
              <input
                type="text"
                placeholder="Rezaei"
                value={form.last_name}
                onChange={set('last_name')}
                className={errors.last_name ? 'error-field' : ''}
              />
              {errors.last_name && <p className="field-error">{errors.last_name}</p>}
            </div>
          </div>

          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              placeholder="ali@example.com"
              value={form.email}
              onChange={set('email')}
              className={errors.email ? 'error-field' : ''}
            />
            {errors.email && <p className="field-error">{errors.email}</p>}
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              placeholder="At least 6 characters"
              value={form.password}
              onChange={set('password')}
              className={errors.password ? 'error-field' : ''}
            />
            {errors.password && <p className="field-error">{errors.password}</p>}
          </div>

          <div className="form-group">
            <label>Confirm Password</label>
            <input
              type="password"
              placeholder="Repeat password"
              value={form.confirm}
              onChange={set('confirm')}
              className={errors.confirm ? 'error-field' : ''}
            />
            {errors.confirm && <p className="field-error">{errors.confirm}</p>}
          </div>

          <div className="form-group">
            <label>Nationality <span style={{ color: 'var(--muted)', fontWeight: 400 }}>(optional)</span></label>
            <select value={form.nationality_country_id} onChange={set('nationality_country_id')}>
              <option value="">Select country…</option>
              {countries.map(c => (
                <option key={c.country_id} value={c.country_id}>{c.name}</option>
              ))}
            </select>
          </div>

          <button type="submit" className="btn btn-primary btn-full" disabled={loading}>
            {loading ? <span className="spinner" /> : 'Create Account'}
          </button>
        </form>

        <hr className="divider" />
        <p style={{ textAlign: 'center', fontSize: 14 }}>
          Already have an account? <Link to="/login" className="link">Sign in</Link>
        </p>
      </div>
    </div>
  )
}
