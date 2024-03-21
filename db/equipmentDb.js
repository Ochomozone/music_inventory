const {query, pool} = require('./dbCore.js');
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


module.exports = {
    getAllEquipmentType,
    getEquipmentTypeDescription,
    getExistingInstrumentDescriptions
};