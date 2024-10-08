const {query, pool} = require('./dbCore.js');
const getDispatchedInstruments = async () => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id, issued_on
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        ORDER BY issued_on, user_name, description, number`;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        return {error}
    }
};

const getDispatchedInstrumentsBYDescriptionNumber = async (description, number) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id, issued_on
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        AND description ILIKE '%'||$1||'%'
                        AND number = $2
                        ORDER BY issued_on,user_name, description, number`;
    try {
        const instruments = await query(queryText, [description, number]);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getDispatchedInstrumentsBYDescription = async (description) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id, issued_on 
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        AND description ILIKE '%'||$1||'%'
                        ORDER BY issued_on, user_name, description, number`;
    try {
        const instruments = await query(queryText, [description]);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getDispatchedInstrumentsByUserIds = async (userIds) => {
    const queryText = `
        SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id, issued_on 
        FROM instruments
        WHERE user_id IN (${userIds.map((_, i) => `$${i + 1}`).join(',')})
        ORDER BY issued_on, user_name, description, number
    `;
    try {
        const { rows } = await pool.query(queryText, userIds);
        return rows;
    } catch (error) {
        console.error('Error fetching dispatched instruments by user IDs:', error);
        throw error;
    }
};

const getDispatchedInstrumentsByUserId = async (userId) => {
    const queryText = `
        SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id, issued_on 
        FROM instruments
        WHERE user_id = $1
        ORDER BY user_name, description, number, issued_on desc
    `;
    try {
        const { rows } = await pool.query(queryText, [userId]);
        return rows;
    } catch (error) {
        console.error('Error fetching dispatched instruments by user IDs:', error);
        throw error;
    }
};
const getInstrumentIdByDescriptionNumber = async (description, number) => {
    // const queryText = 'SELECT get_item_id_by_description($1, $2) AS id';
    const queryText = `SELECT id FROM instruments WHERE description ILIKE '%'||$1||'%' AND number = $2`
    try {
        const result = await query(queryText, [description, number]);
        if (result && result.length > 0) {
            return result[0].id;
        } else {
            throw new Error('Instrument not found');
        }
    } catch (error) {
        console.error('Error fetching instrument ID by description and number:', error);
        throw error;
    }
};
const searchUserIdsByName = async (userName) => {
    const queryText = `
    SELECT all_users_view.id
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE '%' || $1|| '%'
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userName}%`]);
        return rows.map(row => row.id);
    } catch (error) {
        console.error('Error searching users by name:', error);
        throw error;
    }
};
const createDispatch = async (description,profileId,  username, number, userId) => {
    if (!description || !number || !userId) {
        throw new Error('Missing required parameters');
    } else { try {
        const instrumentId = await getInstrumentIdByDescriptionNumber(description, number);
        const queryText = `
            INSERT INTO dispatches (item_id, profile_id, created_by, user_id)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `;
        const rows = await query(queryText, [instrumentId, profileId, username, userId]);
        return rows; 
    } catch (error) {
        console.error('Error creating dispatch:', error);
        throw error;
    }}
};


const returnInstrument = async (instrumentId, userName,  userId, formerUserId) => {
    try {
        
        // Insert the return into the database
        const queryText = `
            INSERT INTO returns (item_id, created_by, user_id, former_user_id)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `;
        const rows = await query(queryText, [instrumentId, userName, userId, formerUserId]);
        return rows; 
    } catch (error) {
        console.error('Error creating dispatch:', error);
        throw error;
    }
};

module.exports = {
    createDispatch,
    returnInstrument,
    getDispatchedInstruments,
    getDispatchedInstrumentsBYDescriptionNumber,
    getDispatchedInstrumentsBYDescription,
    getDispatchedInstrumentsByUserIds,
    getDispatchedInstrumentsByUserId,
    getInstrumentIdByDescriptionNumber,
    searchUserIdsByName 
};