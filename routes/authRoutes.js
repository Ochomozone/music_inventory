const express = require('express');
const passport = require('../utils/authentication/google-auth');
const authRouter = express.Router();

authRouter.get('/google', 
  passport.authenticate('google', { scope : ['profile', 'email'] }));

  authRouter.get('/google/callback', 
  passport.authenticate('google', { failureRedirect: '/auth/error' }),
  function(req, res) {
    const email = req.user.emails[0].value;
    const username = email.substring(0, email.indexOf('@'));

    req.user.username = username;

    res.json(req.user);
  });

//   authRouter.get('/success', (req, res) => res.render('pages/success', { user: req.user }));
// authRouter.get('/error', (req, res) => {
//     const errorMessage = req.query.message || "Error logging in";
//     res.redirect('/auth/google?message=' + encodeURIComponent(errorMessage));
//   });

module.exports = authRouter;
