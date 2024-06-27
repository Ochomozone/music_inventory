const express = require("express");
const router = express.Router();
const db = require('../db/requestsdb.js');
const {searchUsersById} = require('../db/usersDb.js');
const {getInstrumentById} = require('../db/instrumentDb.js');
const {createDispatch} = require('../db/dispatchesDb.js');

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
            try {
                const rows = await db.getRequestDetails(uniqueId);
                const date = rows.length > 0 ? rows[0].created_at : null;
                const notes = rows.length > 0 ? rows[0].notes : null;
                const creatorId = rows.length > 0 ? rows[0].user_id : null;
                const users = await searchUsersById(creatorId);
                const userName = users.length > 0 ? users[0].full_name : null;
                const requestData = await Promise.all(rows.map(async ({ id, success, instrument, quantity, instruments_granted }) => {
                    let instrumentDetails = [];
                    if (instruments_granted) {
                        instrumentDetails = await Promise.all(instruments_granted.map(async (instrumentId) => {
                            const returnedInstrument = await getInstrumentById(parseInt(instrumentId));
                            const { id, description, number, serial } = returnedInstrument[0];
                            return { id, description, number, serial };
                        }));
                    }
                    return {
                        id,
                        success,
                        creatorId,
                        creatorName: userName,
                        description: instrument,
                        quantity,
                        instruments_granted: instrumentDetails.length > 0 ? instrumentDetails : undefined
                    };
                }));
        
                // Send response
                res.status(200).json({ uniqueId, date, notes, requestData });
            } catch (error) {
                console.error('Error fetching request details:', error);
                res.status(500).json({ error: 'Failed to fetch request details' });
            }
        }
        
         else if (userId) {
            const rows = await db.getUserRequests(userId);
            const users = await searchUsersById(userId);
            const userName = users.length > 0 ? users[0].full_name : null;
            const requestData = rows.reduce((acc, { unique_id, status, quantity, created_at, resolved_at }) => {
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

            const uniqueAttendedBys = new Map();
            rows.forEach(({ unique_id, attended_by }) => {
                if (!uniqueAttendedBys.has(unique_id)) {
                    uniqueAttendedBys.set(unique_id, attended_by);
                }
            });
            const uniqueAttendedBy = Object.fromEntries(uniqueAttendedBys);

            const uniqueIdsWithResolveDates = new Map();
            rows.forEach(({ unique_id, resolved_at }) => {
                if (!uniqueIdsWithResolveDates.has(unique_id)) {
                    uniqueIdsWithResolveDates.set(unique_id, resolved_at);
                }
            });
            const uniqueIdResolveDates = Object.fromEntries(uniqueIdsWithResolveDates);
        
            const formattedData = Object.keys(requestData).map(uniqueId => ({
                uniqueId,
                userName,
                createDate: uniqueIdDates[uniqueId], 
                resolveDate: uniqueIdResolveDates[uniqueId],
                attendedBy: uniqueAttendedBy[uniqueId],
                requestData: {
                    quantityRequested: requestData[uniqueId].num_of_instruments,
                    status: requestData[uniqueId].status
                }
            }));
        
            res.status(200).json(formattedData);
        }
        
        
        else {
            try {
                const rows = await db.getAllRequests();
                const result = {};
        
                await Promise.all(rows.map(async row => {
                    const { id, created_at, user_id, instrument, quantity, status, success, unique_id, resolved_at, notes, attended_by, attended_by_id,  instruments_granted } = row;
                    let instrumentDetails = [];
        
                    if (instruments_granted) {
                        instrumentDetails = await Promise.all(instruments_granted.map(async (instrumentId) => {
                            const returnedInstrument = await getInstrumentById(parseInt(instrumentId));
                            const { id, description, number, serial } = returnedInstrument[0];
                            return { instrumentId: id, number, description, serial };
                        }));
                    }
        
                    // Fetch creatorName
                    const users = await searchUsersById(user_id);
                    const creatorName = users.length > 0 ? users[0].full_name : null;
                   
        
                    if (!result[unique_id]) {
                        result[unique_id] = {
                            user_id,
                            created_at,
                            status,
                            success,
                            resolved_at,
                            attended_by,
                            attended_by_id,
                            creatorId:user_id,
                            notes,
                            creatorName,
                            instrumentData: []
                        };
                    }
        
                    result[unique_id].instrumentData.push({
                        instrument,
                        requestId: id,
                        quantity,
                        instruments_granted: instrumentDetails.length > 0 ? instrumentDetails : undefined
                    });
                }));
        
                res.status(200).json(result);
            } catch (error) {
                console.error('Error fetching requests:', error);
                res.status(500).json({ error: 'Failed to fetch requests' });
            }
        }
        
        
    } catch (error) {
        console.error('Error getting requests:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



router.delete('/', async (req, res) => {
    const { uniqueId } = req.query;
    if (!uniqueId) {
        return res.status(400).json({ error: 'Invalid request body' });
    }
    try {
        await db.deleteRequest(uniqueId);
        res.status(200).json({ message: 'Request deleted successfully' });
    } catch (error) {
        console.error('Error deleting request:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);
router.patch('/', async (req, res) => {
    const { id, status, success, uniqueId, notes, attendedBy, attendedById, creatorName, creatorId, instrumentsGranted } = req.body;
    if (!attendedBy || !attendedById || id === '0') {
        return res.status(400).json({ error: 'Invalid request body' });
    }
    try {
        let instrumentsGrantedList = null;
        if (instrumentsGranted) {
            instrumentsGrantedList = instrumentsGranted.map(item => parseInt(item, 10));
            for (const instrument of instrumentsGrantedList) {
                const returnedInstrument = await getInstrumentById(instrument);
                const {description, number} = returnedInstrument[0];
                await createDispatch(description, attendedById, creatorName, number, creatorId); 
            }
        }
        await db.updateRequests(id, status, success, uniqueId, notes, attendedBy, attendedById, instrumentsGrantedList);
        res.status(200).json({ message: 'Request updated successfully' });
    } catch (error) {
        console.error('Error updating request:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});




module.exports = router;
