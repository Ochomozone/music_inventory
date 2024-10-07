const express = require("express");
const router = express.Router();
const db = require('../db/studentsDb.js');

router.get('/', async (req, res) => {
    const { studentNumber, email } = req.query;
    try {
        let studentList;
        if (studentNumber) {
            studentList = await db.searchStudentByNumber(studentNumber);
       
        }else if (email ) {
            studentList = await db.searchStudentbyEmail(email);
         }else {
            studentList = await db.getAllStudents();
        }
        res.json(studentList);
    } catch (error) {
        console.error('Error fetching student list:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.post('/', async (req, res) => {
    const { student_number, first_name, last_name, email, parent1_email, parent2_email, grade_level } = req.body;
    const student = {
        student_number,
        first_name,
        last_name,
        email,
        parent1_email,
        parent2_email,
        grade_level
    };
    try {
        const newStudent = await db.addNewStudent(student);
        res.json(newStudent);
    } catch (error) {
        console.error('Error adding student:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);

router.patch('/', async (req, res) => {
    const { student_number, first_name, last_name, email, parent1_email, parent2_email, grade_level} = req.body;
    // Check if student number is provided
    if (!student_number) {
        return res.status(400).json({ error: 'Student number is required' });
    }
    //Create student object with all values from request body that are not null or empty
    const student = {
        ...(student_number ? { student_number } : {}),
        ...(first_name ? { first_name } : {}),
        ...(last_name ? { last_name } : {}),
        ...(email ? { email } : {}),
        ...(parent1_email ? { parent1_email } : {}),
        ...(parent2_email ? { parent2_email } : {}),
        ...(grade_level ? { grade_level } : {}),
        
    };
    try {
        const updatedStudent = await db.updateStudent(student);
        res.json(updatedStudent);
    } catch (error) {
        console.error('Error updating student:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



module.exports = router;