const express = require('express');
const passport = require('../utils/authentication/google-auth');
const authRouter = express.Router();

authRouter.get('/google', 
  passport.authenticate('google', { scope : ['profile', 'email'] }));

authRouter.get('/google/callback', 
  passport.authenticate('google', { failureRedirect: '/error' }),
  function(req, res) {
    res.redirect('/auth/success');
  });

authRouter.get('/success', (req, res) => res.send(req.user));
authRouter.get('/error', (req, res) => res.send("error logging in"));

module.exports = authRouter;
