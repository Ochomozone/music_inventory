const { query, pool } = require('./dbCore.js');
const getInstruments = async () => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, number, state, INITCAP(make) AS make, model, serial, location, user_name  
                        FROM instruments 
                        ORDER BY description, number`;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        return { error};
        // return{error};
    }
};
const getExistingInstrumentDescriptions = async () => {
    const queryText = `SELECT DISTINCT description AS
                        FROM instruments `;
    try {
        const instruments = await query(queryText);
        return instruments;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        return{error};
    }
};
const getLocations = async () => {
    const queryText = `SELECT * FROM locations ORDER BY room`;
    try {
        const locations = await query(queryText);
        return locations;
    } catch (error) {
        console.error('Error fetching instruments:', error);
        return{error};
    }
};

const getInstrumentStates = async () => {
    const queryText = `SELECT * FROM instrument_conditions`;
    try {
        const conditions = await query(queryText);
        return conditions;
    } catch (error) {
        console.error('Error fetching instrument conditions:', error);
        return{error};
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
        return{error};
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
        return{error};
    }
};

const getInstrumentBySerial = async (serialNo) => {
    const queryText = `SELECT id, INITCAP(description) AS description, code, legacy_code, number, INITCAP(make) AS make, model, serial, location, user_name 
                        FROM instruments 
                        WHERE serial = $1`;
    try {
        const instrument = await query(queryText, [serialNo]);
        return instrument;
    } catch (error) {
        console.error('Error fetching instrument by ID:', error);
        return{error};
    }
};

const getInstrumentIdByDescriptionNumber = async (description, number) => {
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
        return{error};
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
        return{error};
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
            i.state,
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
        return{error};
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
        return{error};
    }
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
            return{error};
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
            return{error};
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
            return{error};
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
            return{error};
        }
    };

    const swapCases = (code, id_1, id_2, created_by) => {
        const queryText = `INSERT INTO swap_cases(instr_code, item_id_1, item_id_2, created_by)
                    VALUES ($1, $2, $3, $4);`;
        try {
            const result = query(queryText, [code, id_1, id_2, created_by]);
            return result;
        } catch (error) {
            console.error('Error swapping cases:', error);
            return{error};
        }
    }
    const takeStock = async (location, item_id, description, number, status, created_by, notes) => {
        const queryText = `INSERT INTO take_stock(location, item_id, description, number, status, created_by, notes)
                    VALUES ($1, $2, $3, $4, $5, $6, $7);`;
        try {
            const result = query(queryText, [location, item_id, description, number, status, created_by, notes]);
            return result;
        } catch (error) {
            console.error('An Error Occurred:', error);
            return{error};
        }
    }

    


    module.exports = {
        getAllAvailableInstruments,
        getAvailableInstrumentsByDescription,
        getAvailableInstrumentsByDescriptionNumber,
        getExistingInstrumentDescriptions,
        getInstrumentById,
        getInstrumentByNumber,
        getInstrumentDescriptionByOldCode,
        getInstrumentIdByDescriptionNumber,
        getInstruments,
        getInstrumentsByDescription,
        getInstrumentBySerial,
        getInstrumentStates,
        getLocations,
        createInstrument,
        getEquipmentTypeDescription,
        swapCases,
        takeStock
    };