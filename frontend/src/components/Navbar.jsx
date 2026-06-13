import { Link, useNavigate, useLocation } from 'react-router-dom'

export default function Navbar() {
  const navigate  = useNavigate()
  const location  = useLocation()
  const raw       = localStorage.getItem('user')
  const user      = raw ? JSON.parse(raw) : null

  function logout() {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    navigate('/login')
  }

  return (
    <nav className="navbar">
      <div className="navbar-inner">
        <Link to="/jobs" className="navbar-brand">🌐 MigrateUp</Link>

        <div className="navbar-right">
          <Link
            to="/jobs"
            className="btn btn-ghost btn-sm"
            style={{ borderColor: location.pathname === '/jobs' ? 'var(--primary)' : undefined,
                     color:       location.pathname === '/jobs' ? 'var(--primary)' : undefined }}
          >
            Jobs
          </Link>
          <Link
            to="/dashboard"
            className="btn btn-ghost btn-sm"
            style={{ borderColor: location.pathname === '/dashboard' ? 'var(--primary)' : undefined,
                     color:       location.pathname === '/dashboard' ? 'var(--primary)' : undefined }}
          >
            My Dashboard
          </Link>
          {user && <span className="navbar-user">{user.full_name}</span>}
          <button className="btn btn-ghost btn-sm" onClick={logout}>Logout</button>
        </div>
      </div>
    </nav>
  )
}
