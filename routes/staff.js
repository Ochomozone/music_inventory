const express = require("express");
const router = express.Router();
const db = require('../db/staffDb.js');

router.get('/', async (req, res) => {
    const { staffNumber, email } = req.query;
    try {
        let staffList;
        if (staffNumber) {
            staffList = await db.searchstaffByNumber(staffNumber);
       
        }else if (email ) {
            staffList = await db.searchstaffbyEmail(email);
         }else {
            staffList = await db.getAllstaff();
        }
        res.json(staffList);
    } catch (error) {
        console.error('Error fetching staff list:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.post('/', async (req, res) => {
    const { staff_number, first_name, last_name, email, division, role, room } = req.body;
    const staff = {
        staff_number,
        first_name,
        last_name,
        email,
        division,
        role,
        room
    };
    try {
        const newstaff = await db.addNewstaff(staff);
        res.json(newstaff);
    } catch (error) {
        console.error('Error adding staff:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);

router.patch('/', async (req, res) => {
    const { staff_number, first_name, last_name, email, room, role, division} = req.body;
    if (!staff_number) {
        return res.status(400).json({ error: 'staff number is required' });
    }
    const staff = {
        ...(staff_number ? { staff_number } : {}),
        ...(first_name ? { first_name } : {}),
        ...(last_name ? { last_name } : {}),
        ...(email ? { email } : {}),
        ...(division ? { division } : {}),
        ...(room ? { room } : {}),
        ...(role ? { role } : {}),
        
    };
    try {
        const updatedstaff = await db.updatestaff(staff);
        res.json(updatedstaff);
    } catch (error) {
        console.error('Error updating staff:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/rooms', async (req, res) => {
    try {
        const rooms = await db.getAllRooms();
        res.json(rooms);
    } catch (error) {
        console.error('Error fetching rooms:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.post('/rooms', async (req, res) => {
    const { department, room } = req.body;
    if (!room || !department) {
        return res.status(400).json({ error: 'Room and department is required' });
    }
    try {
        const newRoom = await db.addNewRoom(department, room);
        res.json(newRoom);
    } catch (error) {
        console.error('Error adding room:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
}
);



module.exports = router;