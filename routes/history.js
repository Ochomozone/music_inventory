const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.get('/', async (req, res) => {
    const { userName, description, number } = req.query;
    try {
        let history;
        if (userName) {
            history = await db.getInstrumentHistoryByUser(userName);
        }else if (description && number) {
            history = await db.getInstrumentHistoryByDescriptionNumber(description, number);
        } 
         else if (description) {
            history = await db.getInstrumentHistoryByDescription(description);
        } else {
            history = await db.getInstrumentHistory();
        }

        res.json(history);
    } catch (error) {
        console.error('Error fetching dispatched instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/', async (req, res) => {
    const {description, number, userId} = req.body;
    try {
        await db.createDispatch(description, number, userId);
        res.status(201).json({message: `${description} number ${number} dispatched to user ${userId}`});
    } catch (error) {
        console.error('Error dispatching instrument:', error);
        res.status(500).json({error: 'Internal server error'});
    }

});

module.exports = router;
