import nodemailer from 'nodemailer';
import admin from 'firebase-admin';
import { detectCarrier } from './carrier.js';
import Patient from '../models/Patient.js';
import firebaseCredentials from '../config/firebase-credentials.json' with { type: 'json' };

// Initialize Firebase
admin.initializeApp({
  credential: admin.credential.cert(firebaseCredentials)
});

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true, // true for 465, false for other ports
  auth: {
    user: "zaheerszhrs@gmail.com",
    pass: "dnqg-iqsq-emen-mkaa"
  }
});

const CARRIER_DOMAINS = {
  jazz: 'jazzsms.com',
  telenor: 'sms.telenor.com.pk',
  zong: 'zongsms.pk',
  ufone: 'ufsms.com'
};

export const sendSms = async (phone, message) => {
  try {
    const carrier = detectCarrier(phone);
    
    if (!CARRIER_DOMAINS[carrier]) {
      throw new Error(`Unsupported carrier for ${phone}`);
    }

    await transporter.sendMail({
      from: `"Clinic Queue" <${process.env.GMAIL_USER}>`,
      to: `${phone}@${CARRIER_DOMAINS[carrier]}`,
      subject: '',
      text: message.slice(0, 160)
    });
  } catch (err) {
    console.error(`Email-to-SMS failed for ${phone}:`, err);
    throw err;
  }
};

export const sendPushNotification = async ({ to, title, body }) => {
  try {
    await admin.messaging().send({
      token: to,
      notification: { title, body }
    });
  } catch (err) {
    console.error('FCM Error:', err);
    throw err;
  }
};

export const notifyPatient = async (patientId, message) => {
  const patient = await Patient.findById(patientId);
  
  if (patient?.phone) {
    await sendSms(patient.phone, message).catch(console.error);
  }

  if (patient?.fcmToken) {
    await sendPushNotification({
      to: patient.fcmToken,
      title: 'Queue Update',
      body: message.slice(0, 100)
    }).catch(console.error);
  }
};

export const sendOtp = async (phone) => {
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  await sendSms(phone, `Your OTP is ${otp}. Valid for 5 minutes.`);
  return otp;
};

export const validatePakNumber = (phone) => {
  return /^(\+92|92|0)?(3\d{2})(\d{7})$/.test(phone);
};