const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const PORT = process.env.PORT || 4001;

const instrumentsRouter = require('./routes/instruments');
const dispatchedRouter = require('./routes/dispatched');
const availableInstrumentsRouter = require('./routes/available');
const issueRouter = require('./routes/instrument_issue');

app.use(bodyParser.json());
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
);

app.get('/', (request, response) => {
  response.json({ info: 'Entry point for music inventory database' });
});


app.use('/instruments', instrumentsRouter);
app.use('/dispatches', dispatchedRouter);
app.use('/available', availableInstrumentsRouter);

app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
