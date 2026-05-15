import './ProjectCard.css';

function getHealthColor(project) {
  if (!project.updated_at && !project.accomplishments?.length) {
    return 'red'; // Never updated
  }

  const lastUpdate = project.accomplishments?.length > 0
    ? project.accomplishments[0].date_logged
    : project.updated_at;

  if (!lastUpdate) return 'red';

  const daysSinceUpdate = Math.floor(
    (new Date() - new Date(lastUpdate)) / (1000 * 60 * 60 * 24)
  );

  if (daysSinceUpdate <= 5) return 'green';
  if (daysSinceUpdate <= 9) return 'yellow';
  return 'red';
}

function ProjectCard({ project, onClick }) {
  const health = getHealthColor(project);
  const lastAccomplishment = project.accomplishments?.[0];
  const daysSince = lastAccomplishment
    ? Math.floor((new Date() - new Date(lastAccomplishment.date_logged)) / (1000 * 60 * 60 * 24))
    : null;

  return (
    <div
      className={`project-card health-${health}`}
      onClick={onClick}
      role="button"
      tabIndex="0"
    >
      <div className="card-health-indicator"></div>
      <h3 className="card-title">{project.name}</h3>
      {project.description && (
        <p className="card-description">{project.description}</p>
      )}
      {project.next_action && (
        <div className="card-next-action">
          <strong>Next:</strong> {project.next_action}
        </div>
      )}
      {project.tags.length > 0 && (
        <div className="card-tags">
          {project.tags.map(tag => (
            <span key={tag} className="tag">{tag}</span>
          ))}
        </div>
      )}
      {daysSince !== null && (
        <div className="card-meta">
          Updated {daysSince === 0 ? 'today' : `${daysSince}d ago`}
        </div>
      )}
    </div>
  );
}

export default ProjectCard;
