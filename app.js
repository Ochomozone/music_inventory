const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const PORT = process.env.PORT || 4001;

const instrumentsRouter = require('./routes/instruments');
const dispatchesRouter = require('./routes/dispatches');
const availableInstrumentsRouter = require('./routes/available');
const returnInstrumentRouter = require('./routes/returns');

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
app.use('/dispatches', dispatchesRouter);
app.use('/available', availableInstrumentsRouter);
app.use('/returns', returnInstrumentRouter);


app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
