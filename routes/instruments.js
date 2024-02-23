// routes/instruments.js

const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

// Route to get instruments, with optional filtering by ID and description
router.get('/', async (req, res) => {
    // Extract query parameters
    const { instrumentId, description } = req.query;

    try {
        let instruments;
        // If both ID and description query parameters are provided, prioritize ID filtering
        if (instrumentId) {
            instruments = await db.getInstrumentById(instrumentId);
        } else if (description) {
            instruments = await db.getInstrumentsByDescription(description);
        } else {
            // If neither ID nor description is provided, fetch all instruments
            instruments = await db.getInstruments();
        }
        res.json(instruments);
    } catch (error) {
        console.error('Error fetching instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
