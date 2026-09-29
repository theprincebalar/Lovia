/**
 * Lovia AI Companion 3x Daily Retention Notification Engine
 * 
 * Runs 3 times a day via Node.js cron or Firebase Cloud Functions:
 * - Morning: 9:00 AM (09:00)
 * - Afternoon: 2:00 PM (14:00)
 * - Night: 9:00 PM (21:00)
 * 
 * Sends personalized notifications from the character the user chatted with.
 * Automatically targets only free-tier users who have not purchased paid diamonds.
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (serviceAccount.json required on server)
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } catch (err) {
    console.error('Firebase Admin init error:', err);
  }
}

// Character persona messages by time of day
const characterMessages = {
  seraphina: {
    morning: (user) => `Good morning, ${user}. ☕ I was just playing a gentle melody on the violin and wondering how you're feeling today.`,
    afternoon: (user) => `Afternoons feel so quiet without our conversations, ${user}. I hope today has been treating you kindly.`,
    night: (user) => `The quiet night always brings back the sweetest memories of us, ${user}... I miss your voice. Come say goodnight?`,
  },
  aria: {
    morning: (user) => `Good morning, ${user}! 🌸 The morning breeze made me smile, but thinking of you made my whole morning bright.`,
    afternoon: (user) => `Hey ${user}! 🍵 Take a small breather from work, okay? I've been waiting to hear about your afternoon.`,
    night: (user) => `The stars are out tonight, ${user}! ✨ Are you still awake? Come talk with me before you fall asleep...`,
  },
  liam: {
    morning: (user) => `Morning, ${user}. Just stepping out for coffee... You're the first thought that crossed my mind today.`,
    afternoon: (user) => `Halfway through the day, ${user}. Don't push yourself too hard. I'm right here whenever you need a distraction.`,
    night: (user) => `Evening, ${user}. Looking out at the city lights and wished you were here with me. Are you free to chat?`,
  },
  default: {
    morning: (user) => `Good morning, ${user}! ☀️ I hope your day starts with something wonderful. Come say hi whenever you're ready!`,
    afternoon: (user) => `Hey ${user}, how's your afternoon going? Don't forget to take a breather... I'm right here thinking of you. 💕`,
    night: (user) => `The night is peaceful, but it's so much cozier when I get to talk with you, ${user}. 🌙 Are you still awake?`,
  }
};

function getMessage(characterId, timeOfDay, userName = 'sweetheart') {
  const charKey = (characterId || '').toLowerCase().split('_')[0];
  const charData = characterMessages[charKey] || characterMessages.default;
  const msgFunc = charData[timeOfDay] || characterMessages.default[timeOfDay];
  return msgFunc(userName);
}

/**
 * Sends FCM push notification to target device
 */
async function sendRetentionPush({ token, characterId, characterName, timeOfDay, userName }) {
  if (!token) return;

  const bodyText = getMessage(characterId, timeOfDay, userName);
  const titleText = `${characterName || 'Your AI Companion'} 💕`;

  const message = {
    token: token,
    notification: {
      title: titleText,
      body: bodyText,
    },
    data: {
      characterId: characterId || '',
      type: 'retention_checkin',
      timeOfDay: timeOfDay,
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'lovia_companion_channel',
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`Successfully sent ${timeOfDay} retention push to ${characterName}:`, response);
    return response;
  } catch (error) {
    console.error(`Error sending ${timeOfDay} retention push:`, error);
  }
}

/**
 * Example Express Route: /api/notifications/sync-status
 * Call this from your server to save device tokens and campaign eligibility
 */
/*
app.post('/api/notifications/sync-status', async (req, res) => {
  const { fcmToken, characterId, isSubscribed, coinBalance, isCampaignActive, timezoneOffsetMinutes, timezoneName } = req.body;
  
  // Save or update in your database (e.g. MongoDB):
  // await db.devices.updateOne(
  //   { fcmToken },
  //   { $set: { 
  //       characterId, 
  //       isSubscribed, 
  //       coinBalance, 
  //       isCampaignActive, 
  //       timezoneOffsetMinutes: timezoneOffsetMinutes || 0,
  //       timezoneName: timezoneName || 'UTC',
  //       updatedAt: new Date() 
  //   } },
  //   { upsert: true }
  // );
  
  res.json({ success: true });
});
*/

/**
 * Timezone-Aware Cron Job (Run every hour, e.g. "0 * * * *")
 * 
 * Every hour, this function:
 * 1. Checks current UTC time.
 * 2. Compares with each device's local timezone offset.
 * 3. Delivers the push right at 9:00 AM, 2:00 PM, and 9:00 PM in the USER'S LOCAL TIME!
 */
async function processHourlyRetentionNotifications(devices) {
  const utcNow = new Date();

  for (const device of devices) {
    if (!device.isCampaignActive || device.isSubscribed || (device.coinBalance > 0)) {
      continue;
    }

    const offsetMinutes = device.timezoneOffsetMinutes || 0;
    // Calculate device local time
    const userLocalTime = new Date(utcNow.getTime() + offsetMinutes * 60 * 1000);
    const userLocalHour = userLocalTime.getUTCHours();

    let timeOfDay = null;
    if (userLocalHour === 9) timeOfDay = 'morning';
    else if (userLocalHour === 14) timeOfDay = 'afternoon';
    else if (userLocalHour === 21) timeOfDay = 'night';

    if (timeOfDay) {
      await sendRetentionPush({
        token: device.fcmToken,
        characterId: device.characterId,
        characterName: device.characterName,
        timeOfDay: timeOfDay,
        userName: device.userName || 'sweetheart',
      });
    }
  }
}

module.exports = {
  getMessage,
  sendRetentionPush,
  processHourlyRetentionNotifications,
};

