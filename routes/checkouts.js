const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

// Route to get all dispatched instruments, with optional filtering by user name
router.get('/', async (req, res) => {
    // Extract query parameters
    const { userName, description, number } = req.query;

    try {
        let dispatchedInstruments;

        // If userName query parameter is provided, filter dispatched instruments by user name
        if (userName) {
            // Call search_user_by_name function to get user IDs based on name pattern
            const userIds = await db.searchUserIdsByName(userName);
            // If user IDs are found, filter dispatched instruments by those user IDs
            if (userIds.length > 0) {
                dispatchedInstruments = await db.getDispatchedInstrumentsByUserIds(userIds);
            } else {
                dispatchedInstruments = [];
            }
        } else if (description && number) {
            // If both description and number are provided, filter dispatched instruments by both
            dispatchedInstruments = await db.getDispatchedInstrumentsBYDescriptionNumber(description, number);
        } else if (description) {
            // If only description is provided, filter dispatched instruments by description
            dispatchedInstruments = await db.getDispatchedInstrumentsBYDescription(description);
        } else {
            // If no filtering parameters provided, get all dispatched instruments
            dispatchedInstruments = await db.getDispatchedInstruments();
        }

        res.json(dispatchedInstruments);
    } catch (error) {
        console.error('Error fetching dispatched instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
