// passport.js
const passport = require('passport');
const { Strategy: GoogleStrategy } = require('passport-google-oauth20');
const db = require('../db/db.js'); 

passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: '/auth/google/callback'
  },
  async (accessToken, refreshToken, profile, done) => {
    // You can save user information to your database here if needed
    return done(null, profile);
  }
));

passport.serializeUser((user, done) => {
  done(null, user);
});

passport.deserializeUser(async (user, done) => {
  // If you have user sessions stored in the database, retrieve the user from the database based on user.id or user.email
  // Example: const user = await db.getUserById(user.id);
  done(null, user);
});

module.exports = passport;
