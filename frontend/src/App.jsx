import { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './AuthContext';
import { apiBaseUrl } from './api-config';
import AuthPage from './components/AuthPage';
import KanbanBoard from './components/KanbanBoard';
import EditPanel from './components/EditPanel';
import HowToUse from './components/HowToUse';
import './App.css';

// DEBUG: Log that App.jsx was loaded
console.log('[App.jsx] Module loaded at', new Date().toISOString());

const API_URL = `${apiBaseUrl}/api`;

function Dashboard() {
  const { user, token, logout } = useAuth();
  const [selectedProject, setSelectedProject] = useState(null);
  const [search, setSearch] = useState('');
  const [showHowToUse, setShowHowToUse] = useState(false);
  const [filterStatus, setFilterStatus] = useState({
    not_started: true,
    in_progress: true,
    blocked: true,
    done: true,
  });
  const queryClient = useQueryClient();

  // Fetch all projects
  const { data: projects = [], isLoading } = useQuery({
    queryKey: ['projects'],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/projects`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error('Failed to fetch projects');
      return res.json();
    },
    staleTime: 1000 * 60 * 5,
    enabled: !!token,
  });

  // Filter & search
  const filteredProjects = useMemo(() => {
    return projects.filter(p => {
      const matchesStatus = filterStatus[p.status];
      const matchesSearch = p.name.toLowerCase().includes(search.toLowerCase()) ||
                           p.description?.toLowerCase().includes(search.toLowerCase());
      return matchesStatus && matchesSearch;
    });
  }, [projects, filterStatus, search]);

  // Group by status
  const projectsByStatus = useMemo(() => {
    const grouped = {
      not_started: [],
      in_progress: [],
      blocked: [],
      done: [],
    };
    filteredProjects.forEach(p => {
      if (grouped[p.status]) grouped[p.status].push(p);
    });
    return grouped;
  }, [filteredProjects]);

  // Create project mutation
  const createMutation = useMutation({
    mutationFn: async (data) => {
      const res = await fetch(`${API_URL}/projects`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        const error = await res.text();
        throw new Error(`Failed to create project: ${error}`);
      }
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
      alert('Project created!');
    },
    onError: (error) => {
      alert('Error: ' + error.message);
      console.error('Create project error:', error);
    },
  });

  const handleCreateProject = () => {
    const name = prompt('Project name:');
    if (!name) return;

    const dateStarted = new Date().toISOString().split('T')[0];
    console.log('Creating project:', { name, date_started: dateStarted });
    createMutation.mutate({
      name,
      date_started: dateStarted,
      status: 'not_started',
    });
  };

  const toggleFilter = (status) => {
    setFilterStatus(prev => ({
      ...prev,
      [status]: !prev[status],
    }));
  };

  if (isLoading) {
    return <div className="app loading">Loading projects...</div>;
  }

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-content">
          <h1>Project Dashboard</h1>
          <div className="header-controls">
            <input
              type="text"
              placeholder="Search projects..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="search-input"
            />
            <div className="filters">
              <label className="filter-toggle">
                <input
                  type="checkbox"
                  checked={filterStatus.not_started}
                  onChange={() => toggleFilter('not_started')}
                />
                Not Started
              </label>
              <label className="filter-toggle">
                <input
                  type="checkbox"
                  checked={filterStatus.in_progress}
                  onChange={() => toggleFilter('in_progress')}
                />
                In Progress
              </label>
              <label className="filter-toggle">
                <input
                  type="checkbox"
                  checked={filterStatus.blocked}
                  onChange={() => toggleFilter('blocked')}
                />
                Blocked
              </label>
              <label className="filter-toggle">
                <input
                  type="checkbox"
                  checked={filterStatus.done}
                  onChange={() => toggleFilter('done')}
                />
                Done
              </label>
            </div>
            <button onClick={handleCreateProject} className="btn-primary">
              + New Project
            </button>
            <div className="header-info">
              <span className="user-name">👤 {user?.username}</span>
              <button onClick={() => setShowHowToUse(true)} className="btn-help">
                ?
              </button>
              <button onClick={logout} className="btn-logout">
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="app-main">
        <KanbanBoard
          projectsByStatus={projectsByStatus}
          onSelectProject={setSelectedProject}
        />
      </main>

      {selectedProject && (
        <EditPanel
          project={selectedProject}
          onClose={() => setSelectedProject(null)}
          token={token}
        />
      )}

      {showHowToUse && (
        <HowToUse onClose={() => setShowHowToUse(false)} />
      )}
    </div>
  );
}

function App() {
  const { user, loading } = useAuth();

  console.log('App rendered - loading:', loading, 'user:', user);

  if (loading) {
    return <div className="app loading">Loading...</div>;
  }

  if (!user) {
    return <AuthPage />;
  }

  return <Dashboard />;
}

export default App;
