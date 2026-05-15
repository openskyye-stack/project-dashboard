import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiBaseUrl } from '../api-config';
import './EditPanel.css';

const API_URL = `${apiBaseUrl}/api`;

function EditPanel({ project, onClose, token }) {
  const [formData, setFormData] = useState({
    name: project.name,
    description: project.description || '',
    status: project.status,
    next_action: project.next_action || '',
    notes: project.notes || '',
  });

  const [tagInput, setTagInput] = useState('');
  const [tags, setTags] = useState(project.tags || []);
  const [accomplishments, setAccomplishments] = useState(project.accomplishments || []);
  const [newAccEntry, setNewAccEntry] = useState('');
  const [newAccDate, setNewAccDate] = useState(new Date().toISOString().split('T')[0]);
  const [links, setLinks] = useState(project.links || []);
  const [newLinkTitle, setNewLinkTitle] = useState('');
  const [newLinkUrl, setNewLinkUrl] = useState('');

  const queryClient = useQueryClient();

  const updateMutation = useMutation({
    mutationFn: async (data) => {
      const res = await fetch(`${API_URL}/projects/${project.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(data),
      });
      if (!res.ok) throw new Error('Failed to update project');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch(`${API_URL}/projects/${project.id}`, {
        method: 'DELETE',
      });
      if (!res.ok) throw new Error('Failed to delete project');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
      onClose();
    },
  });

  const accMutation = useMutation({
    mutationFn: async (data) => {
      const res = await fetch(`${API_URL}/projects/${project.id}/accomplishments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(data),
      });
      if (!res.ok) throw new Error('Failed to add accomplishment');
      return res.json();
    },
    onSuccess: (newAcc) => {
      setAccomplishments([newAcc, ...accomplishments]);
      setNewAccEntry('');
      setNewAccDate(new Date().toISOString().split('T')[0]);
      updateMutation.mutate(formData);
    },
  });

  const deleteAccMutation = useMutation({
    mutationFn: async (accId) => {
      const res = await fetch(`${API_URL}/accomplishments/${accId}`, {
        method: 'DELETE',
      });
      if (!res.ok) throw new Error('Failed to delete accomplishment');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
    },
  });

  const tagsMutation = useMutation({
    mutationFn: async (newTags) => {
      const res = await fetch(`${API_URL}/projects/${project.id}/tags`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ tags: newTags }),
      });
      if (!res.ok) throw new Error('Failed to update tags');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
    },
  });

  const linksMutation = useMutation({
    mutationFn: async (newLinks) => {
      const res = await fetch(`${API_URL}/projects/${project.id}/links`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ links: newLinks }),
      });
      if (!res.ok) throw new Error('Failed to update links');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['projects'] });
    },
  });

  const handleSave = () => {
    updateMutation.mutate(formData);
  };

  const handleAddTag = () => {
    if (!tagInput.trim()) return;
    const newTags = [...tags, tagInput.trim()];
    setTags(newTags);
    setTagInput('');
    tagsMutation.mutate(newTags);
  };

  const handleRemoveTag = (tagToRemove) => {
    const newTags = tags.filter(t => t !== tagToRemove);
    setTags(newTags);
    tagsMutation.mutate(newTags);
  };

  const handleAddAccomplishment = () => {
    if (!newAccEntry.trim()) return;
    accMutation.mutate({
      entry: newAccEntry.trim(),
      date_logged: newAccDate,
    });
  };

  const handleDeleteAccomplishment = (accId) => {
    setAccomplishments(accomplishments.filter(a => a.id !== accId));
    deleteAccMutation.mutate(accId);
  };

  const handleAddLink = () => {
    if (!newLinkUrl.trim()) return;
    const newLinks = [...links, { title: newLinkTitle || newLinkUrl, url: newLinkUrl }];
    setLinks(newLinks);
    setNewLinkTitle('');
    setNewLinkUrl('');
    linksMutation.mutate(newLinks);
  };

  const handleRemoveLink = (linkId) => {
    const newLinks = links.filter(l => l.id !== linkId);
    setLinks(newLinks);
    linksMutation.mutate(newLinks);
  };

  return (
    <div className="edit-panel-overlay" onClick={onClose}>
      <div className="edit-panel" onClick={(e) => e.stopPropagation()}>
        <button className="close-btn" onClick={onClose}>×</button>

        <div className="panel-content">
          <h2>Edit Project</h2>

          <div className="form-group">
            <label>Name</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              onBlur={handleSave}
            />
          </div>

          <div className="form-group">
            <label>Description</label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              onBlur={handleSave}
              rows="3"
            />
          </div>

          <div className="form-group">
            <label>Status</label>
            <select
              value={formData.status}
              onChange={(e) => {
                setFormData({ ...formData, status: e.target.value });
                setTimeout(handleSave, 0);
              }}
            >
              <option value="not_started">Not Started</option>
              <option value="in_progress">In Progress</option>
              <option value="blocked">Blocked</option>
              <option value="done">Done</option>
            </select>
          </div>

          <div className="form-group">
            <label>Next Action</label>
            <input
              type="text"
              value={formData.next_action}
              onChange={(e) => setFormData({ ...formData, next_action: e.target.value })}
              onBlur={handleSave}
              placeholder="What's the next step?"
            />
          </div>

          <div className="form-group">
            <label>Notes</label>
            <textarea
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              onBlur={handleSave}
              rows="3"
              placeholder="Any additional notes..."
            />
          </div>

          <div className="form-group">
            <label>Tags</label>
            <div className="tags-input-group">
              <input
                type="text"
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleAddTag()}
                placeholder="Add a tag..."
              />
              <button onClick={handleAddTag} className="btn-sm">Add</button>
            </div>
            <div className="tags-list">
              {tags.map(tag => (
                <div key={tag} className="tag-chip">
                  {tag}
                  <button onClick={() => handleRemoveTag(tag)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>Links & Resources</label>
            <div className="links-input-group">
              <input
                type="text"
                value={newLinkTitle}
                onChange={(e) => setNewLinkTitle(e.target.value)}
                placeholder="Link title (optional)"
              />
              <input
                type="url"
                value={newLinkUrl}
                onChange={(e) => setNewLinkUrl(e.target.value)}
                placeholder="https://..."
              />
              <button onClick={handleAddLink} className="btn-sm">Add Link</button>
            </div>
            <div className="links-list">
              {links.map(link => (
                <div key={link.id} className="link-item">
                  <a href={link.url} target="_blank" rel="noopener noreferrer">
                    {link.title}
                  </a>
                  <button onClick={() => handleRemoveLink(link.id)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label>Accomplishments & Progress</label>
            <div className="acc-input-group">
              <input
                type="date"
                value={newAccDate}
                onChange={(e) => setNewAccDate(e.target.value)}
              />
              <input
                type="text"
                value={newAccEntry}
                onChange={(e) => setNewAccEntry(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleAddAccomplishment()}
                placeholder="What was accomplished?"
              />
              <button onClick={handleAddAccomplishment} className="btn-sm">Add</button>
            </div>
            <div className="accomplishments-list">
              {accomplishments.map(acc => (
                <div key={acc.id} className="accomplishment-item">
                  <div className="acc-date">{new Date(acc.date_logged).toLocaleDateString()}</div>
                  <div className="acc-entry">{acc.entry}</div>
                  <button onClick={() => handleDeleteAccomplishment(acc.id)}>×</button>
                </div>
              ))}
            </div>
          </div>

          <div className="panel-actions">
            <button onClick={onClose} className="btn-secondary">Close</button>
            <button
              onClick={() => {
                if (confirm('Delete this project?')) {
                  deleteMutation.mutate();
                }
              }}
              className="btn-danger"
            >
              Delete Project
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default EditPanel;
