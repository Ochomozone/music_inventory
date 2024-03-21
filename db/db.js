const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_DATABASE,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

pool.on('error', (err) => {
    console.error('Unexpected error on idle client', err);
    process.exit(-1);
});

const query = async (text, params) => {
    try {
        const { rows } = await pool.query(text, params);
        return rows;
    } catch (error) {
        console.error('Error executing query:', error);
        throw error;
    }
};

const getInstruments = async () => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, number, state, INITCAP(make) AS make, model, serial, location, user_name  
                        FROM instruments 
                        ORDER BY description, number`;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};
const getExistingInstrumentDescriptions = async () => {
    const queryText = `SELECT DISTINCT description AS description
                        FROM instruments `;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};
const getLocations = async () => {
    const queryText = `SELECT * FROM locations ORDER BY room`;
    try {
        const locations = await query(queryText);
        return locations;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getInstrumentStates = async () => {
    const queryText = `SELECT * FROM instrument_conditions`;
    try {
        const conditions = await query(queryText);
        return conditions;
    } catch (error) {
        console.error('Error fetching instrument conditions:', error);
        throw error;
    }
};

const createInstrument = async (description, make, model, serial, instrumentState, selectedNumber, profileId, username, location) => {
    const queryText = `
    INSERT INTO new_instrument (description, make, model, serial, state, number, profile_id, username, location )
    VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9)`;
    try {
        const instruments = await query(queryText, [description, make, model, serial, instrumentState, selectedNumber, profileId, username, location]);
        return instruments;
    } catch (error) {
        console.error('Error storing instruments:', error);
        throw error;
    }
};

const getInstrumentById = async (instrumentId) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name 
                        FROM instruments 
                        WHERE id = $1`;
    try {
        const instrument = await query(queryText, [instrumentId]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
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



const getInstrumentsByDescription = async (description) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, state
    FROM instruments WHERE description ILIKE '%'||$1||'%'
    ORDER BY description, number`;
    try {
        const instrument = await query(queryText, [description]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getInstrumentByNumber = async (description, number) => {
    const queryText = `
        SELECT 
            i.id,
            INITCAP(i.description) AS description,
            i.code,
            i.legacy_code,
            i.number,
            INITCAP(i.make) AS make,
            i.model,
            i.serial,
            i.location,
            i.user_name,
            i.state
            u.grade_level,
            u.email
        FROM 
            instruments AS i
        LEFT JOIN 
            users AS u ON i.user_id = u.id
        WHERE 
            i.description ILIKE '%'||$1||'%'
            AND i.number = $2
        ORDER BY 
            i.description, i.number`;
    try {
        const instrument = await query(queryText, [description, number]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getInstrumentDescriptionByOldCode = async (code) => {
    const queryText = `SELECT description
    FROM equipment
    WHERE legacy_code =$1`;
    try {
        const rows = await query(queryText, [code]);
        return rows[0].description;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getDispatchedInstruments = async () => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        ORDER BY user_name, description, number`;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getDispatchedInstrumentsBYDescriptionNumber = async (description, number) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id 
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        AND description ILIKE '%'||$1||'%'
                        AND number = $2
                        ORDER BY user_name, description, number`;
    try {
        const instruments = await query(queryText, [description, number]);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getDispatchedInstrumentsBYDescription = async (description) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id 
                        FROM instruments 
                        WHERE user_id IS NOT NULL
                        AND description ILIKE '%'||$1||'%'
                        ORDER BY user_name, description, number`;
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
        SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id 
        FROM instruments
        WHERE user_id IN (${userIds.map((_, i) => `$${i + 1}`).join(',')})
        ORDER BY user_name, description, number
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
        SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name, user_id 
        FROM instruments
        WHERE user_id = $1
        ORDER BY user_name, description, number
    `;
    try {
        const { rows } = await pool.query(queryText, [userId]);
        return rows;
    } catch (error) {
        console.error('Error fetching dispatched instruments by user IDs:', error);
        throw error;
    }
};

const searchUsersByName = async (userName) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE $1
    ORDER BY all_users_view.full_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userName}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users by name:', error);
        throw error;
    }
};

const searchUsersByDivision = async (userDivision) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.division ILIKE $1
    ORDER BY all_users_view.full_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userDivision}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users by division:', error);
        throw error;
    }
};

const searchUsersByClass = async (classValue) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.class ILIKE $1
    ORDER BY all_users_view.class ,all_users_view.division, all_users_view.full_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${classValue}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users by division:', error);
        throw error;
    }
};

const searchUsersById = async (databaseId) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.id = $1
    ORDER BY all_users_view.class ,all_users_view.division, all_users_view.full_name
    `;
    try {
        const { rows } = await pool.query(queryText, [databaseId]);
        return rows;
    } catch (error) {
        console.error('Error searching users by division:', error);
        throw error;
    }
};

const searchUsersByNameAndDivision = async (userName, userDivision) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.division ILIKE $1
    AND all_users_view.full_name ILIKE $2
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userDivision}%`, `%${userName}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users by division:', error);
        throw error;
    }
};

const searchUsersByNameAndClass = async (userName, classValue) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE $1
    AND all_users_view.class ILIKE $2
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userName}%`, `%${classValue}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users:', error);
        throw error;
    }
};

const searchUsersByDivisionAndClass = async (userDivision, classValue) => {
    const queryText = `
    SELECT *
    FROM all_users_view
    WHERE all_users_view.division ILIKE $1
    AND all_users_view.class ILIKE $2
    ORDER BY all_users_view.class ,all_users_view.division, all_users_view.full_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${userDivision}%`, `%${classValue}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching users:', error);
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

const getUserByEmail = async (email) => {
    queryText = `SELECT * FROM all_users_view WHERE email = $1`;
    try {
        const { rows } = await pool.query(queryText, [email]);
        if (rows.length === 1) {
            const id = rows[0].id;
            const division = rows[0].division;
            const role = rows[0].role;
            const room = rows[0].room;
            return { id, division, role, room };
        } else {
            throw new Error('User not found');
        }
    } catch (error) {
        console.error('Error retrieving user ID:', error);
        throw error;
    }
};


const getUserIdByRole = async (role) => {
    try {
        const queryText = 'SELECT get_user_id_by_role($1) AS user_id';
        const { rows } = await pool.query(queryText, [role]);
        if (rows.length === 1 && rows[0].user_id !== null) {
            return rows[0].user_id;
        } else {
            throw new Error('User not found');
        }
    } catch (error) {
        console.error('Error retrieving user ID:', error);
        throw error;
    }
};

const getAllUsers = async () => {
    const queryText = `SELECT * FROM all_users_view ORDER BY full_name`;
    try {
        const users = await query(queryText);
        return users;
    } catch (error) {
        console.error('Error fetching users:', error);
        throw error;
    }
};

const getUserRole = async (userId) => {
    let role = 'COMMUNITY';
    const queryText = `SELECT role FROM all_users_view 
                        WHERE id = $1`;
    try {
        const result = await query(queryText, [userId]);
        role = result[0].role;
        
    } catch (error) {
        console.error('Error fetching users:', error);
        throw error;
    }
    return role;
};


const getAllAvailableInstruments = async () => {
    const queryText = `
        SELECT  id, INITCAP(description) AS description, number, INITCAP(make) AS make, model, serial, state, location
        FROM instruments
        WHERE user_name IS NULL
        AND state IN ('New', 'Good', 'Fair')
    `;
    try {
        const { rows } = await pool.query(queryText);
        return rows;
    } catch (error) {
        console.error('Error fetching dispatched instruments by user IDs:', error);
        throw error;
    }
};

const getAvailableInstrumentsByDescription = async (description) => {
    const queryText = 
    `SELECT  id, INITCAP(description) AS description, number, INITCAP(make) as make, model, serial, state, location
        FROM instruments
        WHERE user_id IS NULL
        AND description ILIKE '%' || $1|| '%'
        AND state IN ('New', 'Good', 'Fair')
        ORDER BY description, number
        `;
    try {
        const instrument = await query(queryText, [description]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getAvailableInstrumentsByDescriptionNumber = async (description, number) => {
    const queryText = 
    `SELECT  id, INITCAP(description) AS description, number, INITCAP(make) AS make, model, serial, state, location
        FROM instruments
        WHERE user_id IS NULL
        AND description ILIKE '%' || $1|| '%'
        AND number = $2
        AND state IN ('New', 'Good', 'Fair')
        ORDER BY description, number
        `;
    try {
        const instrument = await query(queryText, [description, number]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
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

const getAllEquipmentType = async () => {
    try {
        const queryText = `SELECT * FROM equipment
                            ORDER BY description`;
        const equipmentTypes = await query(queryText);
        return equipmentTypes;
    } catch (error) {
        console.error('Error fetching equipment types:', error);
        throw error;
    }
};

const getEquipmentTypeDescription = async (description) => {
    try {
        const queryText = `SELECT * FROM equipment
                            WHERE description ILIKE $1
                            ORDER BY description`;
        const equipmentTypes = await query(queryText, [`%${description}%`]);
        return equipmentTypes;
    } catch (error) {
        console.error('Error fetching equipment types:', error);
        throw error;
    }
};

const getInstrumentHistory = async () => { 
    try {
        const queryText = `SELECT * FROM history_view
        ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        throw error;
    }
 };
 const getInstrumentHistoryByDescriptionNumber = async (description, number) => { 
    try {
        const queryText = `SELECT * FROM history_view
                            WHERE description ILIKE '%' || $1 || '%' 
                            AND number = $2
                            ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText, [description, number]);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        throw error;
    }
 };

 const getInstrumentHistoryByDescription = async (description) => { 
    try {
        const queryText = `SELECT * FROM history_view
                            WHERE description ILIKE '%' || $1 || '%' 
                            ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText, [description]);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        throw error;
    }
 };

 const getInstrumentHistoryByUser = async (userName) => { 
    try {
        const queryText = `SELECT * FROM history_view
                            WHERE full_name ILIKE '%' || $1 || '%' 
                            ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText, [userName]);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        throw error;
    }
 };

 const getInstrumentHistoryByUserId = async (databaseId) => { 
    try {
        const queryText = `SELECT * FROM history_view
                            WHERE user_id = $1 OR returned_by_id = $1
                            ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText, [databaseId]);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        throw error;
    }
 };
 const allLostAndFound = async () => {
    try {
        const queryText = `SELECT * FROM lost_and_found `;
        const rows = await query(queryText);
        return rows;
    } catch (error) {
        console.error('Error fetching:', error);
        throw error;
    }
 };
 const checkLostAndFound = async (itemId) => {
    try {
        const queryText = `SELECT * FROM lost_and_found
        WHERE id = (
            SELECT MAX(id) FROM lost_and_found
            WHERE item_id = $1
        )
        `;
        const rows = await query(queryText, [itemId]);
        return rows;
    } catch (error) {
        console.error('Error fetching:', error);
        throw error;
    }
 };

 const newLostAndFound = async (itemId, finderName, location, contact) => {
    try {
        const queryText = `INSERT INTO lost_and_found (item_id, finder_name, location, contact)
                            VALUES ($1, $2, $3, $4)
                            RETURNING *`;
        const rows = await query(queryText, [itemId, finderName, location, contact]);
        return rows;
    } catch (error) {
        console.error('Error creating lost and found:', error);
        throw error;
    }
 };

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



module.exports = { getDispatchedInstrumentsByUserIds, 
                    getInstrumentsByDescription, 
                    getInstrumentByNumber,
                    getInstrumentIdByDescriptionNumber,
                    createInstrument,
                    getDispatchedInstruments,
                    getDispatchedInstrumentsBYDescriptionNumber, 
                    getDispatchedInstrumentsBYDescription,
                    getDispatchedInstrumentsByUserId,
                    getInstruments, 
                    getInstrumentById,
                    getInstrumentDescriptionByOldCode,
                    getAllUsers,
                    searchUsersById,
                    searchUserIdsByName, 
                    searchUsersByName,
                    searchUsersByDivision,
                    searchUsersByClass,
                    searchUsersByNameAndDivision,
                    searchUsersByNameAndClass,
                    getUserByEmail,
                    searchUsersByDivisionAndClass,
                    getInstrumentStates,
                    searchUserIdsByName,
                    getUserRole,
                    getAllAvailableInstruments,
                    getAvailableInstrumentsByDescription,
                    getAvailableInstrumentsByDescriptionNumber ,
                    createDispatch,
                    returnInstrument,
                    getAllEquipmentType,
                    getEquipmentTypeDescription,
                    getInstrumentHistory,
                    getInstrumentHistoryByDescriptionNumber,
                    getInstrumentHistoryByDescription,
                    getInstrumentHistoryByUser,
                    getInstrumentHistoryByUserId,
                    newLostAndFound,
                    checkLostAndFound,
                    getLocations,
                    allLostAndFound,
                    getExistingInstrumentDescriptions,
                    createRequest};
