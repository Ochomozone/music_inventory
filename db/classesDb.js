const {query, pool} = require('./dbCore.js');
const getAllClasses = async () => {
    const queryText = `SELECT * FROM class ORDER BY class_name`;
    try {
        const classes = await query(queryText);
        return classes;
    } catch (error) {
        console.error('Error fetching classes:', error);
        return {error: 'Error fetching classes:'};
    }
};

const addNewClass = async (class_name, teacher_id) => {
    const queryText = ` 
    INSERT INTO class(class_name, teacher_id)
    VALUES ($1, $2)
    RETURNING *
    `;
    try {
        const { rows } = await pool.query(queryText, [class_name, teacher_id]);
        return rows[0];
    } catch (error) {
        console.error('Error adding new class:', error);
        return {error: 'Error adding new class:'};
    }
};
const getStudentsInClass = async (classId) => {
    const queryText = `
    SELECT * FROM class_students_view
    WHERE class_id = $1
    ORDER BY first_name
    `;
    try {
        const students = await query(queryText, [classId]);
        return students;
    } catch (error) {
        console.error('Error fetching students in class:', error);
        return {error: 'Error fetching students in class:'}
    }
};

const getClassesForStudent = async (userId) => {
    const queryText = `
    SELECT * FROM class_students_view
    WHERE user_id = $1
    ORDER BY class_name
    `;
    try {
        const classes = await query(queryText, [userId]);
        return classes;
    } catch (error) {
        console.error('Error fetching classes for student:', error);
        return {error: 'Error fetching classes for student:'}
    }
};
const addNewStudent = async (studentId, classId) => {
    const queryText = `
    INSERT INTO class_students(user_id, class_id)
    VALUES ($1, $2)
    RETURNING *
    `;
    try {
        const { rows } = await pool.query(queryText, [studentId, classId]);
        return rows[0];
    } catch (error) {
        console.error('Error adding new student to class:', error);
        return {error: 'Error adding new student to class:'}
    }
};
const removeStudentFromClass = async (userId, classId) => {
    const queryText = `
    DELETE FROM class_students
    WHERE user_id = $1 AND class_id = $2
    RETURNING *
    `;
    try {
        const { rows } = await pool.query(queryText, [userId, classId]);
        return rows[0];
    } catch (error) {
        console.error('Error removing student from class:', error);
        return {error:'Error removing student from class:' }
    }
};
const setPrimaryInstrument = async (userId, classId, instrument) => {
    const queryText = `
    UPDATE class_students
    SET primary_instrument = $3
    WHERE user_id = $1 AND class_id = $2
    RETURNING *
    `;
    try {
        const { rows } = await pool.query(queryText, [userId, classId, instrument]);
        return rows[0];
    } catch (error) {
        console.error('Error setting primary instrument:', error);
        return {error:'Error setting primary instrument:' }
    }
};

module.exports = {
    getAllClasses,
    getStudentsInClass,
    addNewClass,
    addNewStudent,
    removeStudentFromClass,
    setPrimaryInstrument,
    getClassesForStudent
};