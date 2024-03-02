
// routes/dispatches.js

const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

// Route to get all dispatched instruments, with optional filtering by user name
router.get('/', async (req, res) => {
    // Extract query parameters
    const { userName } = req.query;
    console.log('Query userName:', userName);

    try {
        let dispatchedInstruments;
        // If userName query parameter is provided, filter dispatched instruments by user name
        if (userName) {
            console.log('Received userName:', userName);
            // Call search_user_by_name function to get user IDs based on name pattern
            const userIds = await db.searchUserIdsByName(userName);
            // If user IDs are found, filter dispatched instruments by those user IDs
            if (userIds.length > 0) {
                console.log('userIds:', userIds);
                dispatchedInstruments = await db.getDispatchedInstrumentsByUserIds(userIds);
            } else {
                dispatchedInstruments = [];
            }
        } else {
            // Otherwise, fetch all dispatched instruments
            console.log('No parameters received')
            dispatchedInstruments = await db.getDispatchedInstruments();
        }
        res.json(dispatchedInstruments);
    } catch (error) {
        console.error('Error fetching dispatched instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


// POST route to create a new dispatch
router.post('/', async (req, res) => {
    try {
        // Extract data from the request body
        const { description, number, userId } = req.query;

        // Call createDispatch function to add a new dispatch
        const dispatch = await db.createDispatch(description, number, userId);

        // Send a success response with the created dispatch
        res.status(201).json({ dispatch });
    } catch (error) {
        // Handle any errors and send an error response
        console.error('Error creating dispatch:', error);
        res.status(500).json({ error: 'Failed to create dispatch' });
    }
});


module.exports = router;

