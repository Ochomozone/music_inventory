const express = require("express");
const router = express.Router();
const db = require('../db/lostAndFoundDb');

router.get('/', async (req, res) => {
    const { itemId} = req.query;
    try {
        let lostInstruments = [];
        if (itemId) {
            lostInstruments = await db.checkLostAndFound(itemId);
        } else {
            lostInstruments = await db.allLostAndFound();
        }

        res.json(lostInstruments);
    } catch (error) {
        console.error('Error fetching dispatched instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/', async (req, res) => {
    const { itemId, finderName, location,  contact} = req.body;
    try {
        await db.newLostAndFound (itemId, finderName, location,  contact);
        res.status(201).json({message: `Thank you for reporting the found item. Plase Keep it in ${location} and someone contact you soon.`});
    } catch (error) {
        console.error('Error creating report:', error);
        res.status(500).json({message: 'Could not place the report. Try again'});
    }

});

module.exports = router;
