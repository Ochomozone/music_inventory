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
    const queryText = `SELECT id, description, code, number, make, model, serial, location, user_name  
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

const getInstrumentById = async (instrumentId) => {
    const queryText = `SELECT id, description, code, legacy_code, number, make, model, serial, location, user_name 
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
    const queryText = 'SELECT get_item_id_by_description($1, $2) AS id';
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
    const queryText = `SELECT id, description, code, legacy_code, number, make, model, serial, location, user_name 
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
    const queryText = `SELECT id, description, code, legacy_code, number, make, model, serial, location, user_name 
    FROM instruments 
    WHERE description ILIKE '%'||$1||'%'
    AND number = $2
    ORDER BY description, number`;
    try {
        const instrument = await query(queryText, [description, number]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getDispatchedInstruments = async () => {
    const queryText = `SELECT * FROM instruments 
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
    const queryText = `SELECT * FROM instruments 
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
    const queryText = `SELECT * FROM instruments 
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
        SELECT * 
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


const getUserIdByName = async (name) => {
    const users = await searchUserIdsByName(name);
    if (users.length == 1) {
        return users[0];
    } else if (users.length > 1) {
        throw new Error('Narrow your results');
    } else {
        throw new Error('User not found');
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


const getAllAvailableInstruments = async () => {
    const queryText = `
        SELECT  id, description, number, make, model, serial, state, location
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
    `SELECT  id, description, number, make, model, serial, state, location
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
    `SELECT  id, description, number, make, model, serial, state, location
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

const createDispatch = async (description, number, userId) => {
    if (!description || !number || !userId) {
        throw new Error('Missing required parameters');
    } else { try {
        // Retrieve the instrument ID based on its description and number
        const instrumentId = await getInstrumentIdByDescriptionNumber(description, number);
        // console.log(instrumentId)

        // Insert the dispatch into the database
        const queryText = `
            INSERT INTO dispatches (item_id, user_id)
            VALUES ($1, $2)
            RETURNING *
        `;
        const rows = await query(queryText, [instrumentId, userId]);
        return rows; 
    } catch (error) {
        console.error('Error creating dispatch:', error);
        throw error;
    }}
};


const returnInstrument = async (instrumentId) => {
    try {
        const current_user = process.env.DB_USER
        const userId = await getUserIdByRole(current_user);
        // Insert the return into the database
        const queryText = `
            INSERT INTO returns (item_id)
            VALUES ($1)
            RETURNING *
        `;
        const rows = await query(queryText, [instrumentId]);
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




module.exports = { getDispatchedInstrumentsByUserIds, 
                    getInstrumentsByDescription, 
                    getInstrumentByNumber,
                    getInstrumentIdByDescriptionNumber,
                    getDispatchedInstruments,
                    getDispatchedInstrumentsBYDescriptionNumber, 
                    getDispatchedInstrumentsBYDescription,
                    getInstruments, 
                    getInstrumentById,
                    getAllUsers,
                    searchUserIdsByName, 
                    searchUsersByName,
                    searchUsersByDivision,
                    searchUsersByClass,
                    searchUsersByNameAndDivision,
                    searchUsersByNameAndClass,
                    searchUsersByDivisionAndClass,
                    searchUserIdsByName,
                    getAllAvailableInstruments,
                    getAvailableInstrumentsByDescription,
                    getAvailableInstrumentsByDescriptionNumber ,
                    createDispatch,
                    returnInstrument,
                    getAllEquipmentType,
                    getEquipmentTypeDescription };
