const express = require("express");
const router = express.Router();
const db = require('../db/db.js');

router.get('/', async (req, res) => {
    // Extract query parameters
    const { userName } = req.query;

    try {
        let userList;
        // If userName query parameter is provided, filterusers by user name
        if (userName) {
             userList = await db.searchUsersByName(userName);
            
        } else {
            // Otherwise, fetch all users
            userList = await db.getAllUsers();
        }
        res.json(userList);
    } catch (error) {
        console.error('Error fetching users:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;