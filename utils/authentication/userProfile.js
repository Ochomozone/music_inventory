// routes/userProfile.js
const express = require('express');
const fetch = require('node-fetch');
const router = express.Router();
const db = require('../../db/usersDb.js');

router.get('/user/profile', async (req, res) => {
  const authorizationHeader = req.headers['authorization'];
  if (!authorizationHeader || !authorizationHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Access token missing' });
  }

  const accessToken = authorizationHeader.substring('Bearer '.length);

  try {
    const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!response.ok) {
      return res.status(500).json({ error: 'Failed to fetch user profile from Google' });
    }

    const userProfile = await response.json();
    const { id, division, role, room}  = await db.getUserByEmail(userProfile.email);
    const username = userProfile.email.split('@')[0];
    userProfile.username = username;
    userProfile.databaseId = id;
    userProfile.role = role;
    userProfile.division = division;
    userProfile.room = room;
    res.json(userProfile);
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
