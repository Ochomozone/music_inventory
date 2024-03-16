// routes/instruments.js

const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.get('/', async (req, res) => {
    let { instrumentId, description, number, code } = req.query;
    number = req.query.number ? parseInt(req.query.number, 10) : undefined;
    if (code && code.length > 0) {
        try {
            description = await db.getInstrumentDescriptionByOldCode(code);
        } catch (error) {
            console.error('Error fetching instrument description :', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    try {
        let instruments;
        if (instrumentId) {
            instruments = await db.getInstrumentById(instrumentId);
        } else if (description && number) {
            instruments = await db.getInstrumentByNumber(description, number);
        } else if (description) {
            instruments = await db.getInstrumentsByDescription(description);
        } else {
            instruments = await db.getInstruments();
        }
        res.json(instruments);
    } catch (error) {
        console.error('Error fetching instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


module.exports = router;
