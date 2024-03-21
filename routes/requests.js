const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.post('/', async (req, res) => {
    const { userId, uniqueId,requestData } = req.body;
    if (!userId || !uniqueId || !Array.isArray(requestData) || requestData.length === 0) {
        return res.status(400).json({ error: 'Invalid request body' });
    }

    try {
        
            await db.createRequest(userId, uniqueId, requestData);
        
        res.status(201).json({ message: 'Requests created successfully' });
    } catch (error) {
        console.error('Error creating request:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
