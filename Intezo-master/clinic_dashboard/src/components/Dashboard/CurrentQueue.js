// CurrentQueue.js - Bootstrap responsive version
import React from 'react';
import './CurrentQueue.scss';

const CurrentQueue = ({ currentNumber, onNext, canCallNext, totalWaiting }) => {
  return (
    <div className="current-queue">
      <div className="queue-header">
        <div className="queue-info d-flex justify-content-between align-items-center">
          <h2>Now Serving</h2>
          <span className="waiting-count">{totalWaiting} waiting</span>
        </div>
        <div className="queue-number">{currentNumber || '--'}</div>
      </div>
      <button
        onClick={onNext}
        disabled={!canCallNext}
        className={`next-patient-btn ${!canCallNext ? 'disabled' : ''}`}
      >
        {canCallNext ? (
          <>
            <span>Call Next Patient</span>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M5 12H19M19 12L12 5M19 12L12 19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </>
        ) : (
          'Queue Complete'
        )}
      </button>
    </div>
  );
};

export default CurrentQueue;