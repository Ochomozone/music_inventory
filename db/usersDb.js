const {query, pool} = require('./dbCore.js');

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


module.exports = {
    getAllUsers,
    searchUsersByName,
    searchUsersByDivision,
    searchUsersByClass,
    searchUsersById,
    searchUsersByNameAndDivision,
    searchUsersByNameAndClass,
    searchUsersByDivisionAndClass,
    getUserByEmail
};
    