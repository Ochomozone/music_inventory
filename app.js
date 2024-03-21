const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const app = express();
const {
  OAuth2Client,
} = require('google-auth-library');
app.use(express.json());

const oAuth2Client = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  'postmessage',
);
const session = require('express-session');


app.use(cors(
  {origin: 'http://localhost:3000', credentials: true}
));

const PORT = process.env.PORT || 4001;


app.set('view engine', 'ejs');

app.use(session({
  resave: false,
  saveUninitialized: true,
  secret: 'SECRET' 
}));



const instrumentsRouter = require('./routes/instruments');
const checkoutsRouter = require('./routes/checkouts');
const availableInstrumentsRouter = require('./routes/available');
const returnInstrumentRouter = require('./routes/returns');
const usersRouter = require('./routes/users');
const equipmentRouter = require('./routes/equipment');
const historyRouter = require('./routes/history');
const userProfileRouter = require('./utils/authentication/userProfile');
const googleAuthRouter = require('./utils/authentication/GoogleAuth');
const lostAndFoundRouter = require('./routes/lostAndFound');
const requestsRouter = require('./routes/requests');

app.use(bodyParser.json());
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
);

app.use(googleAuthRouter); 
app.use(userProfileRouter);

app.use('/instruments', instrumentsRouter);
app.use('/checkouts', checkoutsRouter);
app.use('/available', availableInstrumentsRouter);
app.use('/returns', returnInstrumentRouter);
app.use('/users', usersRouter);
app.use('/equipment', equipmentRouter);
app.use('/history', historyRouter);
app.use('/lost', lostAndFoundRouter);
app.use('/requests', requestsRouter);


app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
