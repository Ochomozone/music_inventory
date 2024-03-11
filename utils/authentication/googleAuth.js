// routes/authGoogle.js
const express = require('express');
const fetch = require('node-fetch');
const router = express.Router();

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
      const userInfo = await responseUserInfo.json();

      if (responseUserInfo.ok) {

        res.json(userInfo);
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
