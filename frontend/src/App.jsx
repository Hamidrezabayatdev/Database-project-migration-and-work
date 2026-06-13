import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Register from './pages/Register'
import Login    from './pages/Login'
import Jobs     from './pages/Jobs'
import Dashboard from './pages/Dashboard'
import Navbar   from './components/Navbar'

function RequireAuth({ children }) {
  const token = localStorage.getItem('token')
  return token ? children : <Navigate to="/login" replace />
}

function GuestOnly({ children }) {
  const token = localStorage.getItem('token')
  return !token ? children : <Navigate to="/jobs" replace />
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Public */}
        <Route path="/login"    element={<GuestOnly><Login /></GuestOnly>} />
        <Route path="/register" element={<GuestOnly><Register /></GuestOnly>} />

        {/* Protected */}
        <Route path="/jobs" element={
          <RequireAuth>
            <Navbar />
            <Jobs />
          </RequireAuth>
        } />
        <Route path="/dashboard" element={
          <RequireAuth>
            <Navbar />
            <Dashboard />
          </RequireAuth>
        } />

        {/* Default */}
        <Route path="*" element={<Navigate to="/jobs" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
