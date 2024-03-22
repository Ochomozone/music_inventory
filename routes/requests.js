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
            const requestData = rows.reduce((acc, { uniqueId: unique_id, status, instrument, quantity, created_at }) => {
                if (acc[unique_id]) {
                    acc[unique_id].num_of_instruments += quantity;
                } else {
                    acc[unique_id] = {
                        date: created_at,
                        requestData: {
                            quantityRequested: quantity,
                            status: status
                        }
                    };
                }
                return acc;
            }, {});
            const formattedData = Object.keys(requestData).map(unique_id => ({
                unique_id,
                date: requestData[uniqueId].date,
                requestData: {
                    quantityRequested: requestData[uniqueId].requestData.quantityRequested,
                    status: requestData[uniqueId].requestData.status
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
