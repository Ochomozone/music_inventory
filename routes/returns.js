const express = require("express");
const router = express.Router();
const db = require('../db/db.js');


router.post('/', async (req, res) => {
    try {
        let { instrumentId, description, number } = req.query;

        if (!instrumentId && description && number) {
            const assignedInstrumentId = await db.getInstrumentIdByDescriptionNumber(description, number);
            if (!assignedInstrumentId) {
                throw new Error('Instrument ID not found for the provided description and number');
            }
            instrumentId = assignedInstrumentId;
        }

        const returnedInstrument = await db.returnInstrument(instrumentId);

        res.status(201).json({ returnedInstrument });
    } catch (error) {
        console.error('Error returning instrument:', error);
        res.status(500).json({ error: 'Failed to return instrument' });
    }
});


module.exports = router;