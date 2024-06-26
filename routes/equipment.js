const express = require("express");
const router = express.Router();
const db = require('../db/equipmentDb');

router.get('/', async (req, res) => {
    const { description} = req.body;
    try {
        let equipment;
        if (description) {
            equipment = await db.getEquipmentTypeDescription(description);
        } else {
            equipment = await db.getAllEquipmentType();
        }
        res.json(equipment);
    } catch (error) {
        console.error('Error fetching equipment:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/existing', async (req, res) => {
    try {
        const equipment = await db.getExistingInstrumentDescriptions();
        res.json(equipment);
    } catch (error) {
        console.error('Error fetching equipment:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



module.exports = router;