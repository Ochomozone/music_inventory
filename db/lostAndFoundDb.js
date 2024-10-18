const {query, pool} = require('./dbCore.js');

const allLostAndFound = async () => {
    try {
        const queryText = `SELECT * FROM lost_and_found `;
        const rows = await query(queryText);
        return rows;
    } catch (error) {
        console.error('Error fetching:', error);
        return{error};
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
        return{error};
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
        return{error};
    }
 };

 module.exports = {
    allLostAndFound,
    checkLostAndFound,
    newLostAndFound
 };