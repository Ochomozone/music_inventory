const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

// Route to get all available instruments, with optional filtering by description
router.get('/', async (req, res) => {
    // Extract query parameters
    const { description, number } = req.query;

    try {
        let availableInstruments;
        // If description query parameter is provided, filter available instruments by description
        if (description && number) {
                availableInstruments = await db.getAvailableInstrumentsByDescriptionNumber(description, number);
            } else if (description ) {
                availableInstruments = await db.getAvailableInstrumentsByDescription(description);
            } else {
                // Otherwise, fetch all available instruments
                availableInstruments = await db.getAllAvailableInstruments();
            }
        res.json(availableInstruments);
    } catch (error) {
        console.error('Error fetching  instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



module.exports = router;