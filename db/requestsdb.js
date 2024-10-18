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
            return{error};
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
        return{error};
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
            return{error};
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
            return{error};
        }
    }
};

const deleteRequest = async (uniqueId) => {
    if (!uniqueId) {
        throw new Error('Invalid parameters');
    } else {
        try {
            const queryText = `
                DELETE FROM instrument_requests
                WHERE unique_id = $1
                RETURNING *
            `;
            const rows = await query(queryText, [`${uniqueId}`]);
            return rows;
        } catch (error) {
            console.error('Error deleting request:', error);
            return{error};
        }
    }
};

const logUpdateRequest = async (status, success, notes, uniqueId, attendedBy, attendedById) => {
    if (!attendedBy || !attendedById ) {
        throw new Error('Invalid parameters');
    }
    try {
        const queryText = `
            UPDATE instrument_requests 
            SET status = $1, success = $2, resolved_at = (CURRENT_DATE + LOCALTIME) , attended_by = $3, attended_by_id = $4, notes = $5
            WHERE unique_id = $6
            RETURNING *
        `;
        const values = [status, success, attendedBy, attendedById, notes, uniqueId];
        const rows = await query(queryText, values);
        return rows;
    } catch (error) {
        console.error('Error updating request:', error);
        return{error};
    }
}
const updateRequests = async (id, status, success, uniqueId, notes, attendedBy, attendedById, instrumentsGranted) => {
    if (!attendedBy || !attendedById ) {
        throw new Error('Invalid parameters');
    } else {
        try {
            const queryText = `
                UPDATE instrument_requests
                SET   instruments_granted = $1
                WHERE id = $2
                RETURNING *
            `;
            const values = [instrumentsGranted, id];
            const rows = await query(queryText, values);
            if (rows){
                const logUpdate = await logUpdateRequest(status, success, notes, uniqueId, attendedBy, attendedById);
            return logUpdate;}
        } catch (error) {
            console.error('Error updating request:', error);
            return{error};
        }
    }
}


module.exports = {
    createRequest,
    getAllRequests,
    getUserRequests,
    getRequestDetails,
    deleteRequest,
    updateRequests

};


