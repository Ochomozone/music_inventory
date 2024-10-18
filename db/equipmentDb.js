const {query, pool} = require('./dbCore.js');
const getAllEquipmentType = async () => {
    try {
        const queryText = `SELECT * FROM equipment
                            ORDER BY description`;
        const equipmentTypes = await query(queryText);
        return equipmentTypes;
    } catch (error) {
        return { error};
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
        return { error};
    }
};

const getExistingInstrumentDescriptions = async () => {
    const queryText = `SELECT DISTINCT description AS description
                        FROM instruments `;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        return { error};
    }
};


module.exports = {
    getAllEquipmentType,
    getEquipmentTypeDescription,
    getExistingInstrumentDescriptions
};