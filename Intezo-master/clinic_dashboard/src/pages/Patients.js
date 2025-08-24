import React, { useState, useEffect, useCallback } from 'react';
import Sidebar from '../components/Layout/Sidebar';
import { useAuth } from '../context/AuthContext';
import {
    addPatientToQueue,
    updatePatient,
    getPatientHistory,
    getClinicStatus,
    getQueueAnalytics
} from '../api/clinicApi';
import '../styles/Patients.scss';

const Patients = () => {
    const { currentUser } = useAuth();
    const [upcomingPatients, setUpcomingPatients] = useState([]);
    const [servedPatients, setServedPatients] = useState([]);
    const [cancelledPatients, setCancelledPatients] = useState([]);
    const [loading, setLoading] = useState(true);
    const [sidebarOpen, setSidebarOpen] = useState(false);
    const [showAddForm, setShowAddForm] = useState(false);
    const [showEditForm, setShowEditForm] = useState(false);
    const [showHistory, setShowHistory] = useState(false);
    const [selectedPatient, setSelectedPatient] = useState(null);
    const [patientHistory, setPatientHistory] = useState([]);
    const [formData, setFormData] = useState({
        name: '',
        phone: '',
    });
    const [formErrors, setFormErrors] = useState({});
    const [submitting, setSubmitting] = useState(false);
    const [nextAvailableNumber, setNextAvailableNumber] = useState(0);
    const [clinicStatus, setClinicStatus] = useState({
        isOpen: false,
        operatingHours: { opening: '09:00', closing: '17:00' }
    });
    const [activeTab, setActiveTab] = useState('waiting');
    const [searchTerm, setSearchTerm] = useState('');

    const fetchClinicStatus = useCallback(async () => {
        try {
            const response = await getClinicStatus();
            setClinicStatus(response.data);
        } catch (err) {
            console.error('Error fetching clinic status:', err);
        }
    }, []);

    const fetchQueueAnalytics = useCallback(async () => {
        try {
            if (currentUser?.clinic?._id) {
                const { data } = await getQueueAnalytics();

                setUpcomingPatients(data.waiting || []);
                setServedPatients(data.served || []);
                setCancelledPatients(data.cancelled || []);

                // Calculate next available number
                const currentNumber = 0;
                const lastQueueNumber = data.waiting?.length > 0
                    ? Math.max(...data.waiting.map(p => p.number))
                    : currentNumber;

                setNextAvailableNumber(lastQueueNumber + 1);
                setLoading(false); // Set loading to false after data is fetched
            }
        } catch (error) {
            console.error('Error fetching queue analytics:', error);
            setLoading(false);
        }
    }, [currentUser]);

    useEffect(() => {
        fetchQueueAnalytics();
        fetchClinicStatus();
    }, [fetchQueueAnalytics, fetchClinicStatus]);

    const toggleSidebar = () => {
        setSidebarOpen(!sidebarOpen);
    };

    const validateForm = () => {
        const errors = {};

        if (!formData.name.trim()) {
            errors.name = 'Name is required';
        }

        if (!formData.phone.trim()) {
            errors.phone = 'Phone number is required';
        } else if (!/^(\+92|92|0)?3\d{9}$/.test(formData.phone.replace(/\D/g, ''))) {
            errors.phone = 'Please enter a valid Pakistani phone number';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleInputChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({
            ...prev,
            [name]: value
        }));

        if (formErrors[name]) {
            setFormErrors(prev => ({
                ...prev,
                [name]: ''
            }));
        }
    };

    const handleAddPatient = async (e) => {
        e.preventDefault();

        if (!validateForm()) return;

        setSubmitting(true);

        try {
            const patientResponse = await addPatientToQueue({
                name: formData.name,
                phone: formData.phone,
                clinicId: currentUser.clinic._id
            });

            fetchQueueAnalytics();

            setFormData({
                name: '',
                phone: '',
            });
            setShowAddForm(false);
            setSubmitting(false);

            alert(`Patient added successfully! Queue number: ${patientResponse.data.queueNumber}`);

        } catch (error) {
            console.error('Error adding patient:', error);
            setSubmitting(false);
            alert(error.response?.data?.error || 'Failed to add patient. Please try again.');
        }
    };

    const handleEditPatient = (patient) => {
        setSelectedPatient(patient);
        setFormData({
            name: patient.name,
            phone: patient.phone,
        });
        setShowEditForm(true);
    };

    const handleUpdatePatient = async (e) => {
        e.preventDefault();

        if (!validateForm()) return;

        setSubmitting(true);

        try {
            await updatePatient(selectedPatient._id, {
                name: formData.name,
                phone: formData.phone,
            });

            fetchQueueAnalytics();
            setShowEditForm(false);
            setSubmitting(false);
            setSelectedPatient(null);

            alert('Patient updated successfully!');

        } catch (error) {
            console.error('Error updating patient:', error);
            setSubmitting(false);
            alert(error.response?.data?.error || 'Failed to update patient. Please try again.');
        }
    };

    const handleViewHistory = async (patient) => {
        setSelectedPatient(patient);
        try {
            const history = await getPatientHistory(patient._id);
            setPatientHistory(history.data);
            setShowHistory(true);
        } catch (error) {
            console.error('Error fetching patient history:', error);
            alert('Failed to load patient history.');
        }
    };

    const handleMarkAsServed = async (patient) => {
        try {
            // You'll need to create this API endpoint
            // await markPatientAsServed(patient._id);
            alert(`Patient ${patient.name} marked as served`);
            fetchQueueAnalytics();
        } catch (error) {
            console.error('Error marking as served:', error);
            alert('Failed to mark patient as served');
        }
    };

    const handleCancelPatient = async (patient) => {
        try {
            // You'll need to create this API endpoint
            // await cancelPatient(patient._id);
            alert(`Patient ${patient.name} cancelled`);
            fetchQueueAnalytics();
        } catch (error) {
            console.error('Error cancelling patient:', error);
            alert('Failed to cancel patient');
        }
    };

    const getPatientsByStatus = () => {
        switch (activeTab) {
            case 'waiting':
                return upcomingPatients;
            case 'served':
                return servedPatients;
            case 'cancelled':
                return cancelledPatients;
            default:
                return upcomingPatients;
        }
    };

    const getFilteredPatients = () => {
        const patients = getPatientsByStatus();
        if (!searchTerm) return patients;
        
        return patients.filter(patient => 
            patient.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            patient.phone?.includes(searchTerm) ||
            patient.number?.toString().includes(searchTerm)
        );
    };

    const getStatusCount = (status) => {
        switch (status) {
            case 'waiting':
                return upcomingPatients.length;
            case 'served':
                return servedPatients.length;
            case 'cancelled':
                return cancelledPatients.length;
            default:
                return 0;
        }
    };

    if (loading) {
        return (
            <div className="patients-container">
                <Sidebar isOpen={sidebarOpen} toggleSidebar={toggleSidebar} />
                <div className="patients-content">
                    <div className="loading">Loading patients...</div>
                </div>
            </div>
        );
    }

    return (
        <div className="patients-container">
            <Sidebar isOpen={sidebarOpen} toggleSidebar={toggleSidebar} />
            <div className="patients-content">

                <div className="patients-header">
                    <button className="sidebar-toggle" onClick={toggleSidebar}>
                        ☰
                    </button>
                    <h1>Patient Management</h1>
                    <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                        <button
                            className="refresh-btn"
                            onClick={fetchQueueAnalytics}
                            title="Refresh data"
                        >
                            ↻ Refresh
                        </button>
                        <button
                            className={`add-patient-btn ${!clinicStatus.isOpen ? 'disabled' : ''}`}
                            onClick={() => clinicStatus.isOpen && setShowAddForm(true)}
                            disabled={!clinicStatus.isOpen}
                        >
                            {clinicStatus.isOpen ? '+ Add Patient to Queue' : 'Clinic Closed'}
                        </button>
                    </div>
                </div>

                {/* Status Tabs */}
                <div className="status-tabs">
                    <button
                        className={`tab ${activeTab === 'waiting' ? 'active' : ''}`}
                        onClick={() => setActiveTab('waiting')}
                    >
                        Waiting ({getStatusCount('waiting')})
                    </button>
                    <button
                        className={`tab ${activeTab === 'served' ? 'active' : ''}`}
                        onClick={() => setActiveTab('served')}
                    >
                        Served ({getStatusCount('served')})
                    </button>
                    <button
                        className={`tab ${activeTab === 'cancelled' ? 'active' : ''}`}
                        onClick={() => setActiveTab('cancelled')}
                    >
                        Cancelled ({getStatusCount('cancelled')})
                    </button>
                </div>

                {/* Add Patient Modal */}
                {showAddForm && (
                    <div className="modal-overlay">
                        <div className="modal-content">
                            <div className="modal-header">
                                <h2>Add Patient to Queue</h2>
                                <button
                                    className="close-modal"
                                    onClick={() => setShowAddForm(false)}
                                >
                                    ×
                                </button>
                            </div>

                            <form onSubmit={handleAddPatient} className="patient-form">
                                <div className="form-group">
                                    <label htmlFor="name">Full Name *</label>
                                    <input
                                        type="text"
                                        id="name"
                                        name="name"
                                        value={formData.name}
                                        onChange={handleInputChange}
                                        className={formErrors.name ? 'error' : ''}
                                        placeholder="Enter patient's full name"
                                    />
                                    {formErrors.name && (
                                        <span className="error-text">{formErrors.name}</span>
                                    )}
                                </div>

                                <div className="form-group">
                                    <label htmlFor="phone">Phone Number *</label>
                                    <input
                                        type="tel"
                                        id="phone"
                                        name="phone"
                                        value={formData.phone}
                                        onChange={handleInputChange}
                                        className={formErrors.phone ? 'error' : ''}
                                        placeholder="e.g., 03001234567"
                                    />
                                    {formErrors.phone && (
                                        <span className="error-text">{formErrors.phone}</span>
                                    )}
                                </div>

                                <div className="queue-info">
                                    <div className="info-item">
                                        <span className="label">Next Available Number:</span>
                                        <span className="value badge">{nextAvailableNumber}</span>
                                    </div>
                                    <div className="info-item">
                                        <span className="label">Total Waiting:</span>
                                        <span className="value">{getStatusCount('waiting')}</span>
                                    </div>
                                </div>

                                <div className="form-actions">
                                    <button
                                        type="button"
                                        className="btn-secondary"
                                        onClick={() => setShowAddForm(false)}
                                        disabled={submitting}
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        type="submit"
                                        className="btn-primary"
                                        disabled={submitting}
                                    >
                                        {submitting ? 'Adding...' : `Add to Queue (#${nextAvailableNumber})`}
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                )}

                {/* Edit Patient Modal */}
                {showEditForm && (
                    <div className="modal-overlay">
                        <div className="modal-content">
                            <div className="modal-header">
                                <h2>Edit Patient</h2>
                                <button
                                    className="close-modal"
                                    onClick={() => setShowEditForm(false)}
                                >
                                    ×
                                </button>
                            </div>

                            <form onSubmit={handleUpdatePatient} className="patient-form">
                                <div className="form-group">
                                    <label htmlFor="edit-name">Full Name *</label>
                                    <input
                                        type="text"
                                        id="edit-name"
                                        name="name"
                                        value={formData.name}
                                        onChange={handleInputChange}
                                        className={formErrors.name ? 'error' : ''}
                                        placeholder="Enter patient's full name"
                                    />
                                    {formErrors.name && (
                                        <span className="error-text">{formErrors.name}</span>
                                    )}
                                </div>

                                <div className="form-group">
                                    <label htmlFor="edit-phone">Phone Number *</label>
                                    <input
                                        type="tel"
                                        id="edit-phone"
                                        name="phone"
                                        value={formData.phone}
                                        onChange={handleInputChange}
                                        className={formErrors.phone ? 'error' : ''}
                                        placeholder="e.g., 03001234567"
                                    />
                                    {formErrors.phone && (
                                        <span className="error-text">{formErrors.phone}</span>
                                    )}
                                </div>

                                <div className="form-actions">
                                    <button
                                        type="button"
                                        className="btn-secondary"
                                        onClick={() => setShowEditForm(false)}
                                        disabled={submitting}
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        type="submit"
                                        className="btn-primary"
                                        disabled={submitting}
                                    >
                                        {submitting ? 'Updating...' : 'Update Patient'}
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                )}

                {/* History Modal */}
                {showHistory && (
                    <div className="modal-overlay">
                        <div className="modal-content">
                            <div className="modal-header">
                                <h2>Patient History - {selectedPatient?.name}</h2>
                                <button
                                    className="close-modal"
                                    onClick={() => setShowHistory(false)}
                                >
                                    ×
                                </button>
                            </div>

                            <div className="history-content">
                                {patientHistory.length > 0 ? (
                                    <div className="history-list">
                                        {patientHistory.map((visit, index) => (
                                            <div key={index} className="history-item">
                                                <div className="visit-info">
                                                    <span className="visit-number">#{visit.number}</span>
                                                    <span className={`status-badge ${visit.status}`}>
                                                        {visit.status}
                                                    </span>
                                                </div>
                                                <div className="visit-details">
                                                    <span className="visit-date">
                                                        {new Date(visit.servedAt || visit.bookedAt).toLocaleDateString()}
                                                    </span>
                                                    <span className="visit-time">
                                                        {new Date(visit.servedAt || visit.bookedAt).toLocaleTimeString()}
                                                    </span>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                ) : (
                                    <p className="no-history">No history found for this patient.</p>
                                )}
                            </div>
                        </div>
                    </div>
                )}

                <div className="patients-grid">
                    <div className="patients-card">
                        <div className="card-header">
                            <h2>
                                {activeTab === 'waiting' && 'Patients in Queue'}
                                {activeTab === 'served' && 'Served Patients'}
                                {activeTab === 'cancelled' && 'Cancelled Patients'}
                                ({getStatusCount(activeTab)})
                            </h2>
                            <div className="search-box">
                                <input
                                    type="text"
                                    placeholder="Search patients..."
                                    className="search-input"
                                    value={searchTerm}
                                    onChange={(e) => setSearchTerm(e.target.value)}
                                />
                            </div>
                        </div>

                        <div className="patients-list">
                            {getFilteredPatients().map(patient => (
                                <div key={patient._id} className="patient-item">
                                    <div className="patient-info">
                                        <h3>{patient.name || 'Anonymous'}</h3>
                                        <p>Phone: {patient.phone || 'N/A'}</p>
                                        {patient.number && (
                                            <p className="queue-number">Queue #: {patient.number}</p>
                                        )}
                                        <span className={`status-badge ${patient.status}`}>
                                            {patient.status}
                                        </span>
                                        {patient.servedAt && (
                                            <p className="served-time">
                                                Served: {new Date(patient.servedAt).toLocaleTimeString()}
                                            </p>
                                        )}
                                        {patient.cancelledAt && (
                                            <p className="cancelled-time">
                                                Cancelled: {new Date(patient.cancelledAt).toLocaleTimeString()}
                                            </p>
                                        )}
                                    </div>
                                    <div className="patient-actions">
                                        <button
                                            className="btn-primary"
                                            onClick={() => handleViewHistory(patient)}
                                        >
                                            View History
                                        </button>
                                        {activeTab === 'waiting' && (
                                            <>
                                                <button
                                                    className="btn-secondary"
                                                    onClick={() => handleEditPatient(patient)}
                                                >
                                                    Edit
                                                </button>
                                                <button
                                                    className="btn-success"
                                                    onClick={() => handleMarkAsServed(patient)}
                                                >
                                                    Mark Served
                                                </button>
                                                <button
                                                    className="btn-danger"
                                                    onClick={() => handleCancelPatient(patient)}
                                                >
                                                    Cancel
                                                </button>
                                            </>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>

                        {getFilteredPatients().length === 0 && (
                            <div className="empty-state">
                                <p>
                                    {activeTab === 'waiting' && 'No patients currently in queue'}
                                    {activeTab === 'served' && 'No patients served yet'}
                                    {activeTab === 'cancelled' && 'No cancelled patients'}
                                </p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Patients;