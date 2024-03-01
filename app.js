const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const passport = require('./utils/authentication/google-auth');
const cors = require('cors');
const app = express();


app.use(cors());

const PORT = process.env.PORT || 4001;

app.use(session({
  resave: false,
  saveUninitialized: true,
  secret: 'SECRET' 
}));

app.use(passport.initialize());
app.use(passport.session());

app.set('view engine', 'ejs');

const authRouter = require('./routes/authRoutes');
const instrumentsRouter = require('./routes/instruments');
const dispatchesRouter = require('./routes/dispatches');
const availableInstrumentsRouter = require('./routes/available');
const returnInstrumentRouter = require('./routes/returns');
const useersRouter = require('./routes/users');

app.use(bodyParser.json());
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
);

app.get('/', function(req, res) {
  res.render('pages/auth');
});

app.use('/auth', authRouter); 
app.use('/instruments', instrumentsRouter);
app.use('/dispatches', dispatchesRouter);
app.use('/available', availableInstrumentsRouter);
app.use('/returns', returnInstrumentRouter);
app.use('/users', useersRouter);


app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
