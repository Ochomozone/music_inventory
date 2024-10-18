const {query, pool} = require('./dbCore.js');
const getAllRoles = async () => {
    const queryText = `SELECT role_name FROM roles`;
    try {
        const { rows } = await pool.query(queryText);
        return rows.map(row => row.role_name.toUpperCase());
    } catch (error) {
        console.error('Error fetching roles:', error);
        return {error};
    }
};



const searchStaffByNumber = async (staffNumber) => {
    const queryText = `
    SELECT *
    FROM staff
    WHERE staff.staff_number = $1
    ORDER BY staff.first_name ,staff.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [staffNumber]);
        return rows;
    } catch (error) {
        console.error('Error searching staff by number:', error);
        return{error};
    }
};

const searchstaffByUserNumber = async (staffNumber) => {
    const queryText = `
    SELECT *
    FROM users
    WHERE users.number = $1
    ORDER BY users.first_name ,users.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [staffNumber]);
        return rows;
    } catch (error) {
        console.error('Error searching staff by number:', error);
        return{error};
    }
};
const searchstaffbyEmail = async (email) => {
    const queryText = `
    SELECT *
    FROM staff
    WHERE staff.email ILIKE $1
    ORDER BY staff.first_name ,staff.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${email}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching staff by email:', error);
        return{error};
    }
};

const getAllstaff = async () => {
    const queryText = `SELECT * FROM staff ORDER BY staff.first_name ,staff.last_name`;
    try {
        const users = await query(queryText);
        return users;
    } catch (error) {
        console.error('Error fetching staff:', error);
        return{error};
    }
};

const addNewstaff = async (staff) => {
    const allRoles = await getAllRoles();

    
    if (staff.role && !allRoles.includes(staff.role.toUpperCase())) {
        const roleQueryText = `INSERT INTO public.roles (role_name) VALUES ($1)`;
        try {
            await query(roleQueryText, [staff.role.toUpperCase()]);
        } catch (error) {
            console.error('Error adding new role:', error);
            return { error }; 
        }
    }
    const queryText = `
        INSERT INTO staff (staff_number, first_name, last_name, email, division, role, room)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
    `;
    
    try {
        const { rows } = await pool.query(queryText, [
            staff.staff_number,
            staff.first_name,
            staff.last_name,
            staff.email,
            staff.division,
            staff.role,
            staff.room
        ]);
        return rows[0]; 
    } catch (error) {
        console.error('Error adding new staff:', error);
        return { error }; 
    }
};

const updatestaff = async (staff) => {     
    // Check if staff exists with that staff number
    const staffCheck = await searchstaffByUserNumber(staff.staff_number);
    if (staffCheck.length === 0) {
        return { error: 'staff does not exist' };
    }
    const allRoles = await getAllRoles();

    
    if (staff.role && !allRoles.includes(staff.role.toUpperCase())) {
        const roleQueryText = `INSERT INTO public.locations (role) VALUES ($1)`;
        try {
            await query(roleQueryText, [staff.role.toUpperCase()]);
        } catch (error) {
            console.error('Error adding new role:', error);
            return { error }; 
        }
    }
    let staffQueryText = 'UPDATE staff SET ';
    const staffQueryValues = [];
    let queryIndex = 2; // Start from $2 because $1 is the staff_number for the WHERE clause

    if (staff.first_name) {
        staffQueryText += `first_name = $${queryIndex}, `;
        staffQueryValues.push(staff.first_name);
        queryIndex++;
    }
    if (staff.last_name) {
        staffQueryText += `last_name = $${queryIndex}, `;
        staffQueryValues.push(staff.last_name);
        queryIndex++;
    }
    if (staff.email) {
        staffQueryText += `email = $${queryIndex}, `;
        staffQueryValues.push(staff.email);
        queryIndex++;
    }
    if (staff.division != null) {  
        staffQueryText += `division = $${queryIndex}, `;
        staffQueryValues.push(staff.division);
        queryIndex++;
    }
    if (staff.role != null) {
        staffQueryText += `role = $${queryIndex}, `;
        staffQueryValues.push(staff.role);
        queryIndex++;
    }
    if (staff.room != null) {
        staffQueryText += `room = $${queryIndex}, `;
        staffQueryValues.push(staff.room);
        queryIndex++;
    }
    if (staffQueryValues.length > 0) {
        // Remove the last comma and space from the staff query text
        staffQueryText = staffQueryText.slice(0, -2);
        staffQueryText += ` WHERE staff_number = $1 RETURNING *`;
        staffQueryValues.unshift(staff.staff_number);  

        try {
            const staffResult = await pool.query(staffQueryText, staffQueryValues);
            return staffResult.rows[0];
        } catch (error) {
            return { error };
        }
    }
};




module.exports = {
    getAllstaff,
    searchstaffbyEmail,
    searchstaffByNumber: searchStaffByNumber,
    searchstaffByUserNumber,
    addNewstaff,
    updatestaff
};
    