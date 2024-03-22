const express = require("express");
const router = express.Router();
const db = require('../db/requestsdb.js');

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
router.get('/', async (req, res) => {
    const { userId, uniqueId } = req.query;
    try {
        if (uniqueId) {
            const rows = await db.getRequestDetails(uniqueId);
            const requestData = rows.map(
                ({ id, success,  instrument, quantity }) => ({
                    id, success, description: instrument, quantity }));
            res.status(200).json({ uniqueId,requestData });
        } else if (userId) {
            const rows = await db.getUserRequests(userId);
            const requestData = rows.reduce((acc, { unique_id, status, instrument, quantity, created_at }) => {
                if (acc[unique_id]) {
                    acc[unique_id].num_of_instruments += quantity;
                } else {
                    acc[unique_id] = {
                        num_of_instruments: quantity,
                        status: status,
                        created_at: created_at
                    };
                }
                return acc;
            }, {});
            const uniqueIdsWithDates = new Map();
            rows.forEach(({ unique_id, created_at }) => {
                if (!uniqueIdsWithDates.has(unique_id)) {
                    uniqueIdsWithDates.set(unique_id, created_at);
                }
            });
            const uniqueIdDates = Object.fromEntries(uniqueIdsWithDates);
        
            const formattedData = Object.keys(requestData).map(uniqueId => ({
                uniqueId,
                date: uniqueIdDates[uniqueId], 
                requestData: {
                    num_of_instruments: requestData[uniqueId].num_of_instruments,
                    status: requestData[uniqueId].status
                }
            }));
        
            res.status(200).json(formattedData);
        }
        
        
         else {
            const rows = await db.getAllRequests();
            res.status(200).json(rows);
        }
    } catch (error) {
        console.error('Error getting requests:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});




module.exports = router;
