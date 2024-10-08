// routes/authGoogle.js

const express = require('express');
const fetch = require('node-fetch');
const router = express.Router();
const db = require('../../db/usersDb.js');

router.post('/auth/google', async (req, res) => {
  const authorizationHeader = req.headers['authorization'];
  
  if (authorizationHeader && authorizationHeader.startsWith('Bearer ')) {
    const accessToken = authorizationHeader.substring('Bearer '.length);
    
    const responseTokenInfo = await fetch(`https://oauth2.googleapis.com/tokeninfo?access_token=${accessToken}`);
    const { error: tokenError, ...tokenData } = await responseTokenInfo.json();

    // Check if the token is valid
    if (responseTokenInfo.ok && !tokenError) {
      // Token is valid, now fetch user info
      const responseUserInfo = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });
      const userProfile = await responseUserInfo.json();
      const { id, division, role, room}  = await db.getUserByEmail(userProfile.email);
        const username = userProfile.email.split('@')[0];
        userProfile.username = username;
        userProfile.databaseId = id;
        userProfile.role = role;
        userProfile.division = division;
        userProfile.room = room;

      if (responseUserInfo.ok && userProfile.databaseId) {

        res.json(userProfile);
      } else {
        res.status(500).send('Failed to fetch user info from Google');
      }
    } else {
      res.status(401).send('Unauthorized: Invalid access token');
    }
  } else {
    res.status(400).send('Access token not provided');
  }
});

module.exports = router;
