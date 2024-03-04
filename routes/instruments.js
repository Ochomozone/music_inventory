// routes/instruments.js

const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

// Route to get instruments, with optional filtering by ID and description
router.get('/', async (req, res) => {
    // Extract query parameters
    let { instrumentId, description, number } = req.query;

    // Convert number parameter to integer if provided
    number = req.query.number ? parseInt(req.query.number, 10) : undefined;

    try {
        let instruments;
        // If ID  parameter is provided, prioritize ID filtering
        if (instrumentId) {
            instruments = await db.getInstrumentById(instrumentId);
        } else if (description && number) {
            instruments = await db.getInstrumentByNumber(description, number);
        } else if (description) {
            instruments = await db.getInstrumentsByDescription(description);
        } else {
            // If no parameters provided, fetch all instruments
            instruments = await db.getInstruments();
        }
        res.json(instruments);
    } catch (error) {
        console.error('Error fetching instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


module.exports = router;
