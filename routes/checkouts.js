const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.get('/', async (req, res) => {
    const { userName, description, number } = req.query;
    try {
        let dispatchedInstruments;
        if (userName) {
            const userIds = await db.searchUserIdsByName(userName);
            if (userIds.length > 0) {
                dispatchedInstruments = await db.getDispatchedInstrumentsByUserIds(userIds);
            } else {
                dispatchedInstruments = [];
            }
        } else if (description && number) {
            dispatchedInstruments = await db.getDispatchedInstrumentsBYDescriptionNumber(description, number);
        } else if (description) {
            dispatchedInstruments = await db.getDispatchedInstrumentsBYDescription(description);
        } else {
            dispatchedInstruments = await db.getDispatchedInstruments();
        }

        res.json(dispatchedInstruments);
    } catch (error) {
        console.error('Error fetching dispatched instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
