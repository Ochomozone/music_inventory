const {query, pool} = require('./dbCore.js');
const getInstrumentHistory = async () => { 
    try {
        const queryText = `SELECT * FROM history_view
        ORDER BY transaction_timestamp DESC`;
        const instrumentHistory = await query(queryText);
        return instrumentHistory;
    } catch (error) {
        console.error('Error fetching history:', error);
        return{error};
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
        return{error};
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
        return{error};
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
        return{error};
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
        return{error};
    }
 };

 module.exports = {
    getInstrumentHistory,
    getInstrumentHistoryByDescriptionNumber,
    getInstrumentHistoryByDescription,
    getInstrumentHistoryByUser,
    getInstrumentHistoryByUserId
 };