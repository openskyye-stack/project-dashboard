import ProjectCard from './ProjectCard';
import './KanbanBoard.css';

const STATUSES = [
  { key: 'not_started', label: 'Not Started' },
  { key: 'in_progress', label: 'In Progress' },
  { key: 'blocked', label: 'Blocked' },
  { key: 'done', label: 'Done' },
];

function KanbanBoard({ projectsByStatus, onSelectProject }) {
  return (
    <div className="kanban">
      {STATUSES.map(status => (
        <div key={status.key} className={`kanban-column kanban-column-${status.key}`}>
          <h2 className="column-title">{status.label}</h2>
          <div className="column-cards">
            {projectsByStatus[status.key].map(project => (
              <ProjectCard
                key={project.id}
                project={project}
                onClick={() => onSelectProject(project)}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

export default KanbanBoard;
