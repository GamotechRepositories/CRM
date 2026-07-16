import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import RequireAuth from './components/RequireAuth'
import Login from './pages/Login'
import CompaniesDashboard from './pages/CompaniesDashboard'
import CompanyDashboard from './pages/CompanyDashboard'
import EmployeesPage from './pages/EmployeesPage'
import ModulePage from './pages/ModulePage'
import CreateTeamPage from './pages/CreateTeamPage'
import ClientOverviewPage from './pages/ClientOverviewPage'
import ProjectOverviewPage from './pages/ProjectOverviewPage'
import TaskOverviewPage from './pages/TaskOverviewPage'
import InvoiceOverviewPage from './pages/InvoiceOverviewPage'

const withAuth = (element) => <RequireAuth>{element}</RequireAuth>

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path='/login' element={<Login />} />
          <Route path='/' element={withAuth(<CompaniesDashboard />)} />
          <Route path='/create-team' element={withAuth(<CreateTeamPage />)} />
          <Route path='/company/:tenantId' element={withAuth(<CompanyDashboard />)} />
          <Route path='/company/:tenantId/employees' element={withAuth(<EmployeesPage />)} />
          <Route path='/company/:tenantId/employees/:employeeId' element={withAuth(<EmployeesPage />)} />
          <Route path='/company/:tenantId/clients' element={withAuth(<ModulePage moduleId='clients' />)} />
          <Route path='/company/:tenantId/clients/:clientId' element={withAuth(<ClientOverviewPage />)} />
          <Route path='/company/:tenantId/projects' element={withAuth(<ModulePage moduleId='projects' />)} />
          <Route path='/company/:tenantId/projects/:projectId' element={withAuth(<ProjectOverviewPage />)} />
          <Route path='/company/:tenantId/leads' element={withAuth(<ModulePage moduleId='leads' />)} />
          <Route path='/company/:tenantId/tasks' element={withAuth(<ModulePage moduleId='tasks' />)} />
          <Route path='/company/:tenantId/tasks/:taskId' element={withAuth(<TaskOverviewPage />)} />
          <Route path='/company/:tenantId/invoices' element={withAuth(<ModulePage moduleId='invoices' />)} />
          <Route path='/company/:tenantId/invoices/:invoiceId' element={withAuth(<InvoiceOverviewPage />)} />
          <Route path='/company/:tenantId/leaves' element={withAuth(<ModulePage moduleId='leaves' />)} />
          <Route path='/company/:tenantId/reports' element={withAuth(<ModulePage moduleId='reports' />)} />
          <Route path='/company/:tenantId/settings' element={withAuth(<ModulePage moduleId='settings' />)} />
          <Route path='*' element={<Navigate to='/' replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App
