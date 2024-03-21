import { query } from './index.js';
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


module.exports = {
    createRequest
};


