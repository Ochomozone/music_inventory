const { query, pool } = require('./dbCore.js');
 const createRequest = async (userId, uniqueId, requestData) => {
    if (!userId || !Array.isArray(requestData) || requestData.length === 0) {
        throw new Error('Invalid parameters');
    } else {
        try {
            const values = requestData.map(({ description, quantity }) => `(${userId}, ${uniqueId}, '${description}', ${quantity})`).join(', ');
            const queryText = `
                INSERT INTO instrument_requests (user_id, unique_id, instrument, quantity)
                VALUES ${values}
                RETURNING *
            `;
            const rows = await query(queryText);
            return rows;
        } catch (error) {
            console.error('Error creating request:', error);
            throw error;
        }
    }
};

const getAllRequests = async () => {
    try {
        const queryText = `
            SELECT * FROM instrument_requests
            ORDER BY created_at DESC
        `;
        const rows = await query(queryText);
        return rows;
    } catch (error) {
        console.error('Error getting all requests:', error);
        throw error;
    }
};

const getUserRequests = async (userId) => {
    if (!userId) {
        throw new Error('Invalid parameters');
    } else {
        try {
            const queryText = `
                SELECT * FROM instrument_requests
                WHERE user_id = $1
                ORDER BY created_at DESC
            `;
            const rows = await query(queryText, [userId]);
            return rows;
        } catch (error) {
            console.error('Error getting user requests:', error);
            throw error;
        }
    }
};

const getRequestDetails = async (uniqueId) => {
    if (!uniqueId) {
        throw new Error('Invalid parameters');
    } else {
        try {
            const queryText = `
                SELECT * FROM instrument_requests
                WHERE unique_id = $1
                ORDER BY created_at DESC
            `;
            const rows = await query(queryText, [`${uniqueId}`]);
            return rows;
        } catch (error) {
            console.error('Error getting request details:', error);
            throw error;
        }
    }
};


module.exports = {
    createRequest,
    getAllRequests,
    getUserRequests,
    getRequestDetails

};


