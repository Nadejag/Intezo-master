// src/pages/Doctors.js
import React, { useState, useEffect } from 'react';
import api, { getDoctors, createDoctor, updateDoctor, deleteDoctor, getDoctorQueueStatus } from '../api/clinicApi';
import '../styles/Doctors.scss';
import { useNavigate } from 'react-router-dom';

const Doctors = () => {
    const [doctors, setDoctors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [showForm, setShowForm] = useState(false);
    const [editingDoctor, setEditingDoctor] = useState(null);
    const [formData, setFormData] = useState({
        name: '',
        specialty: '',
        consultationFee: '',
        availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        availableHours: {
            start: '09:00',
            end: '17:00'
        }
    });
    const navigate = useNavigate();

    const toggleAvailability = async (doctorId, isAvailable) => {
        try {
            const response = await api.patch(`/doctors/${doctorId}/availability`, {
                isAvailable
            });

            if (response.data.success) {
                fetchDoctors();
                alert(`Doctor ${isAvailable ? 'made available' : 'made unavailable'} successfully`);
            }
        } catch (err) {
            setError('Failed to update doctor availability');
            console.error('Error updating doctor availability:', err);
        }
    };

    const viewDoctorDashboard = (doctorId) => {
        navigate(`/doctor-dashboard/${doctorId}`);
    };

    useEffect(() => {
        fetchDoctors();
    }, []);

    const fetchDoctors = async () => {
        try {
            setLoading(true);
            const response = await getDoctors();
            const doctorsData = response.data;
            
            // Fetch queue status for each doctor
            const doctorsWithQueueData = await Promise.all(
                doctorsData.map(async (doctor) => {
                    try {
                        const queueResponse = await getDoctorQueueStatus(doctor._id);
                        return {
                            ...doctor,
                            queueData: {
                                currentServing: queueResponse.data.currentNumber || 0,
                                totalWaiting: queueResponse.data.totalWaiting || 0
                            }
                        };
                    } catch (err) {
                        console.error(`Error fetching queue status for doctor ${doctor._id}:`, err);
                        return {
                            ...doctor,
                            queueData: {
                                currentServing: 0,
                                totalWaiting: 0
                            }
                        };
                    }
                })
            );
            
            setDoctors(doctorsWithQueueData);
            setError('');
        } catch (err) {
            setError('Failed to fetch doctors');
            console.error('Error fetching doctors:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleInputChange = (e) => {
        const { name, value } = e.target;
        if (name === 'startTime' || name === 'endTime') {
            setFormData(prev => ({
                ...prev,
                availableHours: {
                    ...prev.availableHours,
                    [name === 'startTime' ? 'start' : 'end']: value
                }
            }));
        } else {
            setFormData(prev => ({
                ...prev,
                [name]: value
            }));
        }
    };

    const handleDayToggle = (day) => {
        setFormData(prev => {
            const days = [...prev.availableDays];
            if (days.includes(day)) {
                return {
                    ...prev,
                    availableDays: days.filter(d => d !== day)
                };
            } else {
                return {
                    ...prev,
                    availableDays: [...days, day]
                };
            }
        });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            if (editingDoctor) {
                await updateDoctor(editingDoctor._id, formData);
            } else {
                await createDoctor(formData);
            }
            setShowForm(false);
            setEditingDoctor(null);
            setFormData({
                name: '',
                specialty: '',
                consultationFee: '',
                availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
                availableHours: {
                    start: '09:00',
                    end: '17:00'
                }
            });
            fetchDoctors();
        } catch (err) {
            setError('Failed to save doctor');
            console.error('Error saving doctor:', err);
        }
    };

    const handleEdit = (doctor) => {
        setEditingDoctor(doctor);
        setFormData({
            name: doctor.name,
            specialty: doctor.specialty,
            consultationFee: doctor.consultationFee,
            availableDays: doctor.availableDays,
            availableHours: doctor.availableHours
        });
        setShowForm(true);
    };

    const handleDelete = async (id) => {
        if (window.confirm('Are you sure you want to delete this doctor?')) {
            try {
                await deleteDoctor(id);
                fetchDoctors();
            } catch (err) {
                setError('Failed to delete doctor');
                console.error('Error deleting doctor:', err);
            }
        }
    };

    const cancelForm = () => {
        setShowForm(false);
        setEditingDoctor(null);
        setFormData({
            name: '',
            specialty: '',
            consultationFee: '',
            availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            availableHours: {
                start: '09:00',
                end: '17:00'
            }
        });
    };

    if (loading) {
        return <div className="loading">Loading doctors...</div>;
    }

    return (
        <div className="doctors-page">
            <div className="page-header">
                <h1>Doctors Management</h1>
                <button
                    className="btn btn-primary"
                    onClick={() => setShowForm(true)}
                >
                    Add New Doctor
                </button>
            </div>

            {error && <div className="error-message">{error}</div>}

            {showForm && (
                <div className="doctor-form-overlay">
                    <div className="doctor-form">
                        <h2>{editingDoctor ? 'Edit Doctor' : 'Add New Doctor'}</h2>
                        <form onSubmit={handleSubmit}>
                            <div className="form-group">
                                <label>Name</label>
                                <input
                                    type="text"
                                    name="name"
                                    value={formData.name}
                                    onChange={handleInputChange}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Specialty</label>
                                <input
                                    type="text"
                                    name="specialty"
                                    value={formData.specialty}
                                    onChange={handleInputChange}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Consultation Fee</label>
                                <input
                                    type="number"
                                    name="consultationFee"
                                    value={formData.consultationFee}
                                    onChange={handleInputChange}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Available Days</label>
                                <div className="days-checkboxes">
                                    {['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map(day => (
                                        <label key={day} className="checkbox-label">
                                            <input
                                                type="checkbox"
                                                checked={formData.availableDays.includes(day)}
                                                onChange={() => handleDayToggle(day)}
                                            />
                                            {day}
                                        </label>
                                    ))}
                                </div>
                            </div>

                            <div className="form-group time-range">
                                <label>Available Hours</label>
                                <div className="time-inputs">
                                    <input
                                        type="time"
                                        name="startTime"
                                        value={formData.availableHours.start}
                                        onChange={handleInputChange}
                                    />
                                    <span>to</span>
                                    <input
                                        type="time"
                                        name="endTime"
                                        value={formData.availableHours.end}
                                        onChange={handleInputChange}
                                    />
                                </div>
                            </div>

                            <div className="form-actions">
                                <button type="submit" className="btn btn-primary">
                                    {editingDoctor ? 'Update' : 'Add'} Doctor
                                </button>
                                <button type="button" className="btn btn-secondary" onClick={cancelForm}>
                                    Cancel
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            <div className="doctors-list">
                {doctors.length === 0 ? (
                    <div className="empty-state">
                        <p>No doctors found. Add your first doctor to get started.</p>
                    </div>
                ) : (
                    doctors.map(doctor => (
                        <div key={doctor._id} className="doctor-card">
                            <div className="doctor-info">
                                <h3>{doctor.name}</h3>
                                <p className="specialty">{doctor.specialty}</p>
                                <p className="fee">Fee: <strong>${doctor.consultationFee}</strong></p>
                                <p className="availability">
                                    Available: {doctor.availableDays.join(', ')} from {doctor.availableHours.start} to {doctor.availableHours.end}
                                </p>
                                <div className="status-container">
                                    <span className={`status ${doctor.isActive ? 'active' : 'inactive'}`}>
                                        {doctor.isActive ? 'Active' : 'Inactive'}
                                    </span>
                                    <span className={`availability-status ${doctor.isAvailable ? 'available' : 'unavailable'}`}>
                                        {doctor.isAvailable ? 'Available' : 'Unavailable'}
                                    </span>
                                </div>
                                <div className="queue-info">
                                    <h4>Current Queue</h4>
                                    <div className="queue-stats">
                                        <div className="stat current-serving">
                                            <span className="value">{doctor.queueData.currentServing}</span>
                                            <span className="label">Serving</span>
                                        </div>
                                        <div className="stat waiting">
                                            <span className="value">{doctor.queueData.totalWaiting}</span>
                                            <span className="label">Waiting</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div className="doctor-actions">
                                <button
                                    className="btn btn-info"
                                    onClick={() => viewDoctorDashboard(doctor._id)}
                                >
                                    View Dashboard
                                </button>
                                <button
                                    className={`btn ${doctor.isAvailable ? 'btn-warning' : 'btn-success'}`}
                                    onClick={() => toggleAvailability(doctor._id, !doctor.isAvailable)}
                                >
                                    {doctor.isAvailable ? 'Make Unavailable' : 'Make Available'}
                                </button>
                                <button
                                    className="btn btn-secondary"
                                    onClick={() => handleEdit(doctor)}
                                >
                                    Edit
                                </button>
                                <button
                                    className="btn btn-danger"
                                    onClick={() => handleDelete(doctor._id)}
                                >
                                    Delete
                                </button>
                            </div>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};

export default Doctors;