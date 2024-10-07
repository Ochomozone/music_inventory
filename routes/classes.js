const express = require("express");
const router = express.Router();
const db = require('../db/classesDb.js');

router.get('/', async (req, res) => {
    try {
        const classList = await db.getAllClasses();
        res.json(classList);
    } catch (error) {
        console.error('Error fetching class list:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/students', async (req, res) => {
    console.log('req.query:', req.query);
    const classId  = req.query.classId;
    const userId = req.query.userId ? req.query.userId : null;

    if (!classId && !userId) {
        return res.status(400).json({ error: 'classId is required and cannot be blank' });
    } else if (classId) {

    try {
        const students = await db.getStudentsInClass(classId);
        res.json(students);
    } catch (error) {
        console.error('Error fetching students in class:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
} else {
    try {
        const classes = await db.getClassesForStudent(userId);
        res.json(classes);
    } catch (error) {
        console.error('Error fetching classes for student:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
});


router.post('/', async (req, res) => {
    const { class_name, teacher_id } = req.body;
    if (!class_name) {
        return res.status(400).json({ error: 'class Name is required and cannot be blank' });
    }
    if (!teacher_id) {
        return res.status(400).json({ error: 'teacherId is required and cannot be blank' });
    }

    try {
        const newClass = await db.addNewClass(class_name, teacher_id);  
        res.json(newClass);
    } catch (error) {
        console.error('Error adding class:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.post('/students', async (req, res) => {
    const { userId, classId } = req.body;
    if (!userId ) {
        return res.status(400).json({ error: 'user is required and cannot be blank' });
    }
    if (!classId) {
        return res.status(400).json({ error: 'class is required and cannot be blank' });
    }

    try {
        const newStudent = await db.addNewStudent(userId, classId);
        res.json(newStudent);
    } catch (error) {
        console.error('Error adding student to class:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.delete('/students', async (req, res) => {
    const { userId, classId } = req.body;
    try {
        const removedStudent = await db.removeStudentFromClass(userId, classId);
        res.json(removedStudent);
    } catch (error) {
        console.error('Error removing student from class:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);

router.patch('/instruments', async (req, res) => {
    const { classId, userId, instrument } = req.body;
    //cast instrument to all caps
    const instrumentCaps = instrument.toUpperCase();
    if (!classId || !userId) {
        return res.status(400).json({ error: 'classId and userId is required and cannot be blank' });
    }
    try {
        const newInstrument = await db.setPrimaryInstrument(userId, classId, instrumentCaps);
        res.json(newInstrument);
    } catch (error) {
        console.error('Error updating instrument:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);

module.exports = router;