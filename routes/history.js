const express = require("express");
const router = express.Router();
const db = require('../db/historyDb');

router.get('/', async (req, res) => {
    const { userName, description, number, databaseId } = req.query;
    try {
        let history;
        if (databaseId) {
            history = await db.getInstrumentHistoryByUserId(parseInt(databaseId));
        }
        else if (userName) {
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

module.exports = router;
