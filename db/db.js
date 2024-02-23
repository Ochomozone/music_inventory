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
    const queryText = 'SELECT description, code, number, make, model, serial, location FROM all_instruments_view';
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const getInstrumentById = async (instrumentId) => {
    const queryText = 'SELECT description, code, legacy_code, number, make, model, serial, location, user_name FROM instruments WHERE id = $1';
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
    const queryText = 'SELECT description, code, legacy_code, number, make, model, serial, location, user_name FROM instruments WHERE description = $1';
    try {
        const instrument = await query(queryText, [description]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};

const getDispatchedInstruments = async () => {
    const queryText = 'SELECT * FROM dispatched_instruments_view';
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

const searchUserByName = async (namePattern) => {
    const queryText = `
    SELECT all_users_view.id
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE '%' || $1|| '%'
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${namePattern}%`]);
        return rows.map(row => row.id);
    } catch (error) {
        console.error('Error searching users by name:', error);
        throw error;
    }
};

const getUserIdByName = async (name) => {
    const users = await searchUserByName(name);
    if (users.length == 1) {
        return users[0];
    } else if (users.length > 1) {
        throw new Error('Narrow your results');
    } else {
        throw new Error('User not found');
    }
};

// Function to fetch dispatched instruments filtered by user IDs
const getDispatchedInstrumentsByUserIds = async (userIds) => {
    const queryText = `
        SELECT  description, number, make, model, serial, state, user_name
        FROM instruments
        WHERE user_id IN (${userIds.map((_, i) => `$${i + 1}`).join(',')})
    `;
    try {
        const { rows } = await pool.query(queryText, userIds);
        return rows;
    } catch (error) {
        console.error('Error fetching dispatched instruments by user IDs:', error);
        throw error;
    }
};

// Function to fetch all available instruments
const getAllAvailableInstruments = async () => {
    const queryText = `
        SELECT  description, number, make, model, serial, state, location
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
    `SELECT  description, number, make, model, serial, state, location
        FROM instruments
        WHERE user_name IS NULL
        AND description ILIKE '%' || $1|| '%'
        AND state IN ('New', 'Good', 'Fair')
        `;
    try {
        const instrument = await query(queryText, [description]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        throw error;
    }
};


const createDispatch = async (description, number, userId) => {
    try {
        console.log(description, number, userId);
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
        console.log(rows);
        return rows; 
    } catch (error) {
        console.error('Error creating dispatch:', error);
        throw error;
    }
};




module.exports = { getDispatchedInstrumentsByUserIds, 
                    getInstrumentsByDescription, 
                    getDispatchedInstruments, 
                    getInstruments, 
                    getInstrumentById,
                    searchUserByName, 
                    getAllAvailableInstruments,
                    getAvailableInstrumentsByDescription,
                    createDispatch,
                    query };
