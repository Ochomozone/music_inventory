const express = require("express");
const router = express.Router();
const db = require('../db/db.js');
const { parse } = require("dotenv");


router.post('/', async (req, res) => {
    try {
        let { instrumentId, userName, userId, formerUserId} = req.query;
        
            instrumentId = parseInt(instrumentId);
            userId  = parseInt(userId);
            formerUserId = parseInt(formerUserId);
       

        const returnedInstrument = await db.returnInstrument(instrumentId, userName, userId, formerUserId);

        res.status(201).json({ returnedInstrument });
    } catch (error) {
        console.error('Error returning instrument:', error);
        res.status(500).json({ error: 'Failed to return instrument' });
    }
});


module.exports = router;