const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.get('/', async (req, res) => {
    const { description, number } = req.query;

    try {
        let availableInstruments;
        if (description && number) {
                availableInstruments = await db.getAvailableInstrumentsByDescriptionNumber(description, number);
            } else if (description ) {
                availableInstruments = await db.getAvailableInstrumentsByDescription(description);
                
            } else { availableInstruments = await db.getAllAvailableInstruments(); }
        res.json(availableInstruments);
    } catch (error) {
        console.error('Error fetching  instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



module.exports = router;