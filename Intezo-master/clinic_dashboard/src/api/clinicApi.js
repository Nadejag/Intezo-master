import axios from 'axios';

// Create the axios instance first
const api = axios.create({
  baseURL: "http://localhost:3000/api", // Replace with your actual API base URL
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  },
  withCredentials: true
});

// Then add interceptors
api.interceptors.request.use(config => {
  const user = JSON.parse(localStorage.getItem('clinicUser') || '{}');
  if (user.token) {
    config.headers.Authorization = `Bearer ${user.token}`;
  }
  return config;
});

export const updatePatient = (patientId, data) => {
  return api.put(`/patients/${patientId}`, data);
};

export const getPatientHistory = (patientId) => {
  return api.get(`/patients/${patientId}/history`);
};

export const addPatientToQueue = (data) => {
  return api.post('/patients/register-and-queue', data);
};

export const registerClinic = (data) => {
  return api.post('/clinics/register', data);
};

export const loginClinic = (email, password) => {
  return api.post('/clinics/login', { email, password });
};

export const getClinicProfile = () => {
  return api.get('/clinics/profile');
};

export const getQueueDashboard = (clinicId) => {
  return api.get(`/queues/${clinicId}`);
};

export const updateClinicProfile = (data) => {
  return api.put('/clinics/profile', data);
};
 
export const updateCurrentNumber = (clinicId) => {
  return api.post('/queues/next', { clinicId, action: 'next' });
};

// Keep the specific number function if needed
export const updateToSpecificNumber = (clinicId, newNumber) => {
  return api.post('/queues/next', { clinicId, action: 'specific', newNumber });
};

// Add these functions to clinicApi.js

export const toggleClinicStatus = () => {
  return api.post('/clinics/toggle-status');
};

export const getClinicStatus = () => {
  return api.get('/clinics/status');
};

// In clinicApi.js - Update the getQueueAnalytics function
export const getQueueAnalytics = async () => {
  return api.get('/clinics/analytics');
};