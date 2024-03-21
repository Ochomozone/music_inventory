const express = require("express");
const router = express.Router();
const db = require('../db/usersDb.js');

router.get('/', async (req, res) => {
    // Extract query parameters
    const { userName, userDivision, classValue, databaseId } = req.query;
    try {
        let userList;
        // If userName query parameter is provided, filterusers by user name
        if (databaseId) {
            userList = await db.searchUsersById(databaseId);
        } 
        else if (userName && classValue) {
            userList = await db.searchUsersByNameAndClass(userName, classValue);
        } else if (userDivision && userName) {
            userList = await db.searchUsersByNameAndDivision(userName, userDivision);
        } else if (userDivision && classValue) {
            userList = await db.searchUsersByDivisionAndClass (userDivision, classValue);
        }else if (userName ) {
        userList = await db.searchUsersByName(userName);
       
        }else if (userDivision ) {
            userList = await db.searchUsersByDivision(userDivision);
           
        }else if (classValue ) {
            userList = await db.searchUsersByClass(classValue);
           
        }else {
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