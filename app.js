const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const cors = require('cors');
const app = express();


app.use(cors());

const PORT = process.env.PORT || 4001;

app.use(session({
  resave: false,
  saveUninitialized: true,
  secret: 'SECRET' 
}));


app.set('view engine', 'ejs');

const instrumentsRouter = require('./routes/instruments');
const checkoutsRouter = require('./routes/checkouts');
const availableInstrumentsRouter = require('./routes/available');
const returnInstrumentRouter = require('./routes/returns');
const usersRouter = require('./routes/users');
const equipmentRouter = require('./routes/equipment');
const historyRouter = require('./routes/history');

app.use(bodyParser.json());
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
);

app.get('/', function(req, res) {
  res.render('pages/auth');
});

app.use('/instruments', instrumentsRouter);
app.use('/checkouts', checkoutsRouter);
app.use('/available', availableInstrumentsRouter);
app.use('/returns', returnInstrumentRouter);
app.use('/users', usersRouter);
app.use('/equipment', equipmentRouter);
app.use('/history', historyRouter);


app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
