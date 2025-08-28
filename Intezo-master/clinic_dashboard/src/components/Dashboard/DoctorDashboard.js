// src/components/Dashboard/DoctorDashboard.js
import React, { useState, useEffect, useMemo } from 'react';
import { useParams } from 'react-router-dom';
import { getDoctorQueueStatus, updateCurrentNumber } from '../../api/clinicApi';
import { usePusher } from '../../context/PusherContext';
import CurrentQueue from './CurrentQueue';
import UpcomingPatients from './UpcomingPatients';
import QueueStats from './QueueStats';
import './DoctorDashboard.scss';

const DoctorDashboard = () => {
  const { doctorId } = useParams();
  const pusher = usePusher();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [lastUpdated, setLastUpdated] = useState(null);
  const [doctorData, setDoctorData] = useState(null);
  const [queueData, setQueueData] = useState({
    currentNumber: 0,
    upcoming: [],
    totalWaiting: 0,
    avgWaitTime: 15,
    canCallNext: true,
    completedToday: 0
  });
  const [upcomingPage, setUpcomingPage] = useState(1);
  const [itemsPerPage] = useState(8);

  const fetchDoctorQueueData = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);

    try {
      setLoading(true);
      const response = await getDoctorQueueStatus(doctorId);
      setDoctorData(response.data.doctor);
      setQueueData(prev => ({
        ...prev,
        currentNumber: response.data.currentNumber || 0,
        upcoming: response.data.upcoming || [],
        totalWaiting: response.data.totalWaiting || 0,
        canCallNext: (response.data.upcoming?.length || 0) > 0
      }));
      setLastUpdated(new Date());
      setUpcomingPage(1);
      setError('');
    } catch (err) {
      setError('Failed to load doctor queue data');
      console.error('Error fetching doctor queue:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    if (doctorId) {
      fetchDoctorQueueData();
    }
  }, [doctorId]);

  // Memoized paginated upcoming patients
  const paginatedUpcoming = useMemo(() => {
    const startIndex = (upcomingPage - 1) * itemsPerPage;
    return queueData.upcoming.slice(startIndex, startIndex + itemsPerPage);
  }, [queueData.upcoming, upcomingPage, itemsPerPage]);

  const handleRefresh = () => {
    fetchDoctorQueueData(true);
  };

  // Updated handleNextPatient function to match Dashboard.js
  const handleNextPatient = async () => {
    if (!queueData.canCallNext) return;

    try {
      const response = await updateCurrentNumber({
        doctorId: doctorId,
        action: 'next'
      });

      setQueueData(prev => ({
        ...prev,
        currentNumber: response.data.currentNumber,
        completedToday: prev.completedToday + response.data.served,
        canCallNext: response.data.hasNextPatient
      }));
      setLastUpdated(new Date());
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update queue');
      fetchDoctorQueueData();
    }
  };

  const handlePageChange = (newPage) => {
    setUpcomingPage(newPage);
  };

  useEffect(() => {
    if (!pusher || !doctorId) return;

    const channelName = `presence-doctor-${doctorId}`;
    console.log('Subscribing to doctor channel:', channelName);

    const channel = pusher.subscribe(channelName);

    channel.bind('pusher:subscription_succeeded', () => {
      console.log('✅ Subscribed to doctor channel:', channelName);
      fetchDoctorQueueData();
    });

    channel.bind('queue-update', (data) => {
      console.log('📢 Doctor queue update received:', data);
      setQueueData(prev => ({
        ...prev,
        currentNumber: data.currentNumber || prev.currentNumber,
        upcoming: data.upcoming || prev.upcoming,
        totalWaiting: data.totalWaiting || prev.totalWaiting,
        canCallNext: data.hasNextPatient !== undefined ? data.hasNextPatient : prev.canCallNext
      }));
      setLastUpdated(new Date());
    });

    return () => {
      channel.unbind_all();
      pusher.unsubscribe(channelName);
    };
  }, [pusher, doctorId]);

  if (loading) return (
    <div className="doctor-dashboard-container">
      <div className="dashboard-content">
        <div className="loading-state">
          <div className="spinner"></div>
          <p>Loading doctor queue data...</p>
        </div>
      </div>
    </div>
  );

  return (
    <div className="doctor-dashboard-container">
      <div className="dashboard-content">
        <div className="dashboard-header">
          <div className="header-left">
            <div>
              <h1>Doctor Dashboard</h1>
              <div className="doctor-info">
                <span className="doctor-name">{doctorData?.name || 'Loading...'}</span>
                <span className="separator">•</span>
                <span className="doctor-specialty">{doctorData?.specialty || 'Specialty'}</span>
                <span className="separator">•</span>
                <span className={`status ${doctorData?.isAvailable ? 'available' : 'unavailable'}`}>
                  {doctorData?.isAvailable ? 'Available' : 'Unavailable'}
                </span>
              </div>
            </div>
          </div>

          <div className="header-right">
            <div className="data-freshness">
              <span className="status-indicator live"></span>
              <span>Updated: {lastUpdated ? lastUpdated.toLocaleTimeString() : '--:--:--'}</span>
            </div>

            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="refresh-btn"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M4 4V9H4.58152M19.9381 11C19.446 7.05369 16.0796 4 12 4C8.64262 4 5.76829 6.06817 4.58152 9M4.58152 9H9M20 20V15H19.4185M19.4185 15C18.2317 17.9318 15.3574 20 12 20C7.92038 20 4.55399 16.9463 4.06189 13M19.4185 15H15" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              {refreshing ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
        </div>

        {error && (
          <div className="alert error">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M12 8V12M12 16H12.01M21 12C21 极 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C极 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <span>{error}</span>
          </div>
        )}

        <div className="dashboard-grid">
          <div className="top-row">
            <div className="current-queue-container">
              <CurrentQueue
                currentNumber={queueData.currentNumber}
                onNext={handleNextPatient}
                canCallNext={queueData.canCallNext}
                totalWaiting={queueData.totalWaiting}
              />
            </div>

            <div className="queue-stats-container">
              <QueueStats
                totalPatients={queueData.totalWaiting}
                avgWaitTime={queueData.avgWaitTime}
                upcomingCount={queueData.upcoming.length}
                currentNumber={queueData.currentNumber}
                completedToday={queueData.completedToday}
              />
            </div>
          </div>

          <div className="bottom-row">
            <UpcomingPatients
              patients={paginatedUpcoming}
              totalPatients={queueData.upcoming.length}
              currentPage={upcomingPage}
              itemsPerPage={itemsPerPage}
              onPageChange={handlePageChange}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export default DoctorDashboard;