const express = require("express");
const router = express.Router();
const db = require('../db/index.js');

router.get('/', async (req, res) => {
    try {
        const instruments = await db.getInstruments();
        res.json(instruments);
    } catch (error) {
        console.error('Error fetching instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;




