// const { Pool, Client } = require('pg');
// require('dotenv').config();
// const pool = new Pool({
//     user: process.env.DB_USER,
//     host: process.env.DB_HOST,
//     database: process.env.DB_DATABASE,
//     password: process.env.DB_PASSWORD,
//     port: process.env.DB_PORT,
// });

// const client = new Client({
//     user: process.env.DB_USER,
//     host: process.env.DB_HOST,
//     database: process.env.DB_DATABASE,
//     password: process.env.DB_PASSWORD,
//     port: process.env.DB_PORT,
//   })

// const getClient = () => {
//     return pool.connect()
// }

// const query = (text, params, callback) => {
//     pool.query(text, params, callback)
// }

// const getInstruments = async () => {
//     await client.connect();
 
//     console.log('connected')
//     const { rows } = await pool.query('SELECT * FROM all_instruments_view');
//     await client.end();
//     return rows;
 
    
    
// };
// module.exports = { getInstruments, getClient, query };

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
    const queryText = 'SELECT * FROM all_instruments_view';
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        throw error;
    }
};

module.exports = { getInstruments, query };
