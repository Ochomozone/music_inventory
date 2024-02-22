const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const PORT = process.env.PORT || 4001;

const instrumentsRouter = require('./routes/instruments');

app.use(bodyParser.json());
app.use(
  bodyParser.urlencoded({
    extended: true,
  })
);

app.get('/', (request, response) => {
  response.json({ info: 'Entry point for music inventory database' });
});

// Use the instruments router for '/instruments' endpoint
app.use('/instruments', instrumentsRouter);

app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
