import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { updateClinicProfile } from '../api/clinicApi';
import '../styles/Settings.scss';

const Settings = () => {
  const { currentUser } = useAuth();
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    address: '',
    opening: '09:00',
    closing: '17:00'
  });
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (currentUser?.clinic) {
      setFormData({
        name: currentUser.clinic.name || '',
        phone: currentUser.clinic.phone || '',
        address: currentUser.clinic.address || '',
        opening: currentUser.clinic.operatingHours?.opening || '09:00',
        closing: currentUser.clinic.operatingHours?.closing || '17:00'
      });
    }
  }, [currentUser]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await updateClinicProfile({
        name: formData.name,
        phone: formData.phone,
        address: formData.address,
        operatingHours: {
          opening: formData.opening,
          closing: formData.closing
        }
      });
      setSuccess(true);
      setError('');
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update profile');
    }
  };

  return (
    <div className="settings-container">
      <h1>Clinic Settings</h1>
      
      {success && (
        <div className="success-message">
          Settings updated successfully!
        </div>
      )}
      
      {error && (
        <div className="error-message">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>Clinic Name</label>
          <input
            type="text"
            name="name"
            value={formData.name}
            onChange={handleChange}
            required
          />
        </div>

        <div className="form-group">
          <label>Phone Number</label>
          <input
            type="tel"
            name="phone"
            value={formData.phone}
            onChange={handleChange}
            required
          />
        </div>

        <div className="form-group">
          <label>Address</label>
          <textarea
            name="address"
            value={formData.address}
            onChange={handleChange}
            required
            rows="3"
          />
        </div>

        <div className="time-inputs">
          <div className="form-group">
            <label>Opening Time</label>
            <input
              type="time"
              name="opening"
              value={formData.opening}
              onChange={handleChange}
              required
            />
          </div>

          <div className="form-group">
            <label>Closing Time</label>
            <input
              type="time"
              name="closing"
              value={formData.closing}
              onChange={handleChange}
              required
            />
          </div>
        </div>

        <button type="submit" className="save-button">
          Save Changes
        </button>
      </form>
    </div>
  );
};

export default Settings;