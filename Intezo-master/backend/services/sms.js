import axios from 'axios';

/**
 * Alternative SMS provider for Pakistan (if Twilio fails)
 */
export const sendViaPakSmsGateway = async (phone, message) => {
  const payload = {
    api_key: process.env.PAK_SMS_API_KEY,
    sender: 'QUEUEAPP',
    mobile: phone.replace('+', ''),
    message: message.slice(0, 160)  // Pakistani SMS length limit
  };

  return axios.post('https://pak-sms-gateway.com/api/send', payload);
};

/**
 * Send appointment confirmation (Urdu/English)
 */
export const sendBookingConfirmation = async (phone, queueDetails) => {
  const message = `
    Queue Booked!
    Number: ${queueDetails.number}
    Clinic: ${queueDetails.clinicName}
    Estimated wait: ${queueDetails.waitTime} mins
    Thank you!
  `;

  try {
    await sendSms({ to: phone, body: message });
  } catch (err) {
    // Fallback to Pakistani SMS gateway
    await sendViaPakSmsGateway(phone, message);
  }
};