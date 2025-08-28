// src/api/clinicApi.js
import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000/api';

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
});

// Add request interceptor to include auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    const clinicUser = JSON.parse(localStorage.getItem('clinicUser') || '{}');
    
    // Use token from either source
    const authToken = token || clinicUser.token;
    if (authToken) {
      config.headers.Authorization = `Bearer ${authToken}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Add response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      localStorage.removeItem('clinicUser');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Clinic API functions
export const registerClinic = (data) => {
  return api.post('/clinics/register', data);
};

export const loginClinic = (email, password) => {
  return api.post('/clinics/login', { email, password });
};

export const getClinicProfile = () => {
  return api.get('/clinics/profile');
};

export const updateClinicProfile = (data) => {
  return api.put('/clinics/profile', data);
};

export const toggleClinicStatus = () => {
  return api.post('/clinics/toggle-status');
};

export const getClinicStatus = () => {
  return api.get('/clinics/status');
};

export const getQueueAnalytics = () => {
  return api.get('/clinics/analytics');
};

export const debugQueueStatus = () => {
  return api.get('/clinics/debug-queue');
};

// Queue API functions - Updated for doctor-specific queues
export const getDoctorQueue = (clinicId, doctorId) => {
  return api.get(`/queues/${clinicId}/${doctorId}`);
};

export const getPublicDoctorQueue = (clinicId, doctorId) => {
  return api.get(`/queues/public/${clinicId}/${doctorId}`);
};

export const updateCurrentNumber = (data) => {
  return api.post('/queues/next', data);
};

export const updateToSpecificNumber = (doctorId, newNumber) => {
  return api.post('/queues/next', { 
    doctorId, 
    action: 'specific', 
    newNumber 
  });
};

export const callNextPatient = (doctorId) => {
  return api.post('/queues/next', { 
    doctorId, 
    action: 'next' 
  });
};

// Doctor API functions
export const getDoctors = () => {
  return api.get('/doctors');
};

export const getDoctor = (id) => {
  return api.get(`/doctors/${id}`);
};

export const createDoctor = (doctorData) => {
  return api.post('/doctors', doctorData);
};

export const updateDoctor = (id, doctorData) => {
  return api.put(`/doctors/${id}`, doctorData);
};

export const deleteDoctor = (id) => {
  return api.delete(`/doctors/${id}`);
};

export const toggleDoctorAvailability = (id, isAvailable) => {
  return api.patch(`/doctors/${id}/availability`, { isAvailable });
};

export const getDoctorQueueStatus = (doctorId) => {
  return api.get(`/doctor/${doctorId}/queue-status`);
};

// Patient API functions
export const updatePatient = (patientId, data) => {
  return api.put(`/patients/${patientId}`, data);
};

export const getPatientHistory = (patientId) => {
  return api.get(`/patients/${patientId}/history`);
};

export const addPatientToQueue = (data) => {
  return api.post('/patient/register-and-queue', data);
};

export const bookDoctorQueue = (clinicId, doctorId, patientData) => {
  return api.post('/queue/book', {
    clinicId,
    doctorId,
    ...patientData
  });
};

// Public API functions (no auth required)
export const getPublicClinics = () => {
  return api.get('/clinics/public');
};

export const getPublicDoctors = (clinicId) => {
  return api.get(`/doctors/public/${clinicId}`);
};

export const getClinicPublicStatus = (clinicId) => {
  return api.get(`/clinic/${clinicId}/status`);
};

export default api;