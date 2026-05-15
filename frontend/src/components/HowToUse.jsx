import './HowToUse.css';

function HowToUse({ onClose }) {
  return (
    <div className="tutorial-overlay" onClick={onClose}>
      <div className="tutorial-panel" onClick={(e) => e.stopPropagation()}>
        <button className="tutorial-close" onClick={onClose}>×</button>

        <div className="tutorial-content">
          <h1>How to Use Project Dashboard</h1>

          <section>
            <h2>📌 Quick Start</h2>
            <ol>
              <li><strong>Create a project:</strong> Click "+ New Project" and type the name</li>
              <li><strong>Click the card:</strong> Opens the edit panel with full details</li>
              <li><strong>Track progress:</strong> Add accomplishments with dates</li>
              <li><strong>Watch the color:</strong> Card color updates automatically (green = active, yellow = stale, red = needs attention)</li>
            </ol>
          </section>

          <section>
            <h2>🎯 Understanding the Kanban Board</h2>
            <div className="tutorial-grid">
              <div className="tutorial-card">
                <h3>Not Started</h3>
                <p>New projects go here. Move to "In Progress" when you start working.</p>
              </div>
              <div className="tutorial-card">
                <h3>In Progress</h3>
                <p>Projects you're actively working on. Add accomplishments regularly to keep it green.</p>
              </div>
              <div className="tutorial-card">
                <h3>Blocked</h3>
                <p>Projects waiting on something. Document what's blocking in the notes.</p>
              </div>
              <div className="tutorial-card">
                <h3>Done</h3>
                <p>Completed projects. Archive or move back if work starts again.</p>
              </div>
            </div>
          </section>

          <section>
            <h2>🟢🟡🔴 Health Colors Explained</h2>
            <div className="tutorial-colors">
              <div className="color-item">
                <div className="color-dot green"></div>
                <div>
                  <strong>Green:</strong> Updated in last 5 days. You're actively working!
                </div>
              </div>
              <div className="color-item">
                <div className="color-dot yellow"></div>
                <div>
                  <strong>Yellow:</strong> Not updated in 6–9 days OR marked as Blocked. Check in soon.
                </div>
              </div>
              <div className="color-item">
                <div className="color-dot red"></div>
                <div>
                  <strong>Red:</strong> Not updated in 10+ days OR no accomplishments logged. Needs attention.
                </div>
              </div>
            </div>
          </section>

          <section>
            <h2>✏️ Editing Projects</h2>
            <p>Click any project card to open the edit panel. You can update:</p>
            <ul>
              <li><strong>Status:</strong> Move between Not Started / In Progress / Blocked / Done</li>
              <li><strong>Next Action:</strong> What's the next step? (shows on card)</li>
              <li><strong>Accomplishments:</strong> What you've done with dates (updates health color)</li>
              <li><strong>Tags:</strong> Organize by category</li>
              <li><strong>Links:</strong> Store resources, docs, GitHub links</li>
              <li><strong>Notes:</strong> Any additional context</li>
            </ul>
            <p style={{ marginTop: '12px', fontSize: '12px', color: 'var(--text-secondary)' }}>
              💾 <strong>Auto-save:</strong> Everything saves instantly — no "Save" button needed.
            </p>
          </section>

          <section>
            <h2>🔍 Search & Filter</h2>
            <ul>
              <li><strong>Search box:</strong> Find projects by name or description</li>
              <li><strong>Status filters:</strong> Show/hide columns (checkboxes below the header)</li>
            </ul>
          </section>

          <section>
            <h2>📝 Best Practices</h2>
            <ul>
              <li><strong>Add accomplishments weekly:</strong> Even small updates keep the color green</li>
              <li><strong>Use consistent tags:</strong> Pick a naming convention (e.g., all lowercase)</li>
              <li><strong>Set clear next actions:</strong> Vague tasks pile up. Be specific.</li>
              <li><strong>Review daily:</strong> Spend 2 minutes in the morning to set priorities</li>
              <li><strong>Move to Done:</strong> Celebrate completions! It feels good.</li>
            </ul>
          </section>

          <section>
            <h2>👥 Multi-User Setup</h2>
            <p>This dashboard supports multiple users. Each person:</p>
            <ul>
              <li>Has their own login (username + password)</li>
              <li>Sees only their own projects (completely isolated)</li>
              <li>Can run on the same computer or different computers</li>
            </ul>
            <p style={{ marginTop: '12px', fontSize: '12px', color: 'var(--text-secondary)' }}>
              Sign out (top right) to switch users or create a new account.
            </p>
          </section>

          <section>
            <h2>💡 Tips & Tricks</h2>
            <ul>
              <li>Use the "Next Action" field as a quick reminder for yourself</li>
              <li>Add links to GitHub, docs, or research — they're clickable</li>
              <li>Filter by status to focus on what needs attention today</li>
              <li>The search box works on both project name and description</li>
              <li>Blocked projects turn yellow automatically — great for visibility</li>
            </ul>
          </section>

          <section>
            <h2>❓ Questions?</h2>
            <p>Check the README.md file in your project folder for:</p>
            <ul>
              <li>How to back up your data</li>
              <li>How to customize colors and spacing</li>
              <li>Troubleshooting guide</li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
}

export default HowToUse;
