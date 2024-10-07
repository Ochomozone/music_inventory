const {query, pool} = require('./dbCore.js');

const searchStudentByNumber = async (studentNumber) => {
    const queryText = `
    SELECT *
    FROM students
    WHERE students.student_number = $1
    ORDER BY students.first_name ,students.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [studentNumber]);
        return rows;
    } catch (error) {
        console.error('Error searching student by number:', error);
        throw error;
    }
};

const searchStudentByUserNumber = async (studentNumber) => {
    const queryText = `
    SELECT *
    FROM users
    WHERE users.number = $1
    ORDER BY users.first_name ,users.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [studentNumber]);
        return rows;
    } catch (error) {
        console.error('Error searching student by number:', error);
        throw error;
    }
};
const searchStudentbyEmail = async (email) => {
    const queryText = `
    SELECT *
    FROM students
    WHERE students.email ILIKE $1
    ORDER BY students.first_name ,students.last_name
    `;
    try {
        const { rows } = await pool.query(queryText, [`%${email}%`]);
        return rows;
    } catch (error) {
        console.error('Error searching students by email:', error);
        throw error;
    }
};

const getAllStudents = async () => {
    const queryText = `SELECT * FROM students ORDER BY students.first_name ,students.last_name`;
    try {
        const users = await query(queryText);
        return users;
    } catch (error) {
        console.error('Error fetching students:', error);
        throw error;
    }
};

const addNewStudent = async (student) => {
    const queryText = `
    INSERT INTO students (student_number, first_name, last_name, email, parent1_email, parent2_email, grade_level)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *
    `;
    try {
        const { rows } = await pool.query(queryText, [
            student.student_number,
            student.first_name,
            student.last_name,
            student.email,
            student.parent1_email,
            student.parent2_email,
            student.grade_level
        ]);
        return rows[0];
    } catch (error) {
        console.error('Error adding new student:', error);
        throw error;
    }
};

const updateStudent = async (student) => {     
    // Check if student exists with that student number
    const studentCheck = await searchStudentByUserNumber(student.student_number);
    if (studentCheck.length === 0) {
        return { error: 'Student does not exist' };
    }

    let queryText = 'UPDATE students SET ';
    const queryValues = [];
    let queryIndex = 2; // Start from $2 because $1 is the student_number for the WHERE clause

    
    if (student.first_name) {
        queryText += `first_name = $${queryIndex}, `;
        queryValues.push(student.first_name);
        queryIndex++;
    }
    if (student.last_name) {
        queryText += `last_name = $${queryIndex}, `;
        queryValues.push(student.last_name);
        queryIndex++;
    }
    if (student.email) {
        queryText += `email = $${queryIndex}, `;
        queryValues.push(student.email);
        queryIndex++;
    }
    if (student.parent1_email) {
        queryText += `parent1_email = $${queryIndex}, `;
        queryValues.push(student.parent1_email);
        queryIndex++;
    }
    if (student.parent2_email) {
        queryText += `parent2_email = $${queryIndex}, `;
        queryValues.push(student.parent2_email);
        queryIndex++;
    }
    if (student.grade_level != null) {  
        queryText += `grade_level = $${queryIndex}, `;
        queryValues.push(student.grade_level);
        queryIndex++;
    }

    // Remove the last comma and space from the query text
    queryText = queryText.slice(0, -2);

    // Add the WHERE clause
    queryText += ` WHERE student_number = $1 RETURNING *`;
    queryValues.unshift(student.student_number);  // Add student_number at the start of the values array
    try {
        const { rows } = await pool.query(queryText, queryValues);
        return rows[0];
    } catch (error) {
        console.error('Error updating student:', error);
        throw error;
    }
};


module.exports = {
    getAllStudents,
    searchStudentbyEmail,
    searchStudentByNumber,
    searchStudentByUserNumber,
    addNewStudent,
    updateStudent
};
    