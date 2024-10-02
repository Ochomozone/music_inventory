// routes/instruments.js

const express = require("express");
const router = express.Router();
const db = require('../db/instrumentDb');

router.get('/states', async (req, res) => {
    try {
        const states = await db.getInstrumentStates();
        res.json(states);
    } catch (error) {
        console.error('Error fetching states:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/location', async (req, res) => {
    try {
        const locations = await db.getLocations();
       
        res.json(locations);
    } catch (error) {
        console.error('Error :', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/', async (req, res) => {
    let { instrumentId, description, number, code, serialNo } = req.query;
    number = req.query.number ? parseInt(req.query.number, 10) : undefined;
    if (code && code.length > 0) {
        try {
            description = await db.getInstrumentDescriptionByOldCode(code);
        } catch (error) {
            console.error('Error fetching instrument description :', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    }

    try {
        let instruments;
        if (instrumentId) {
            instruments = await db.getInstrumentById(instrumentId);
        } else if (serialNo) {
            instruments = await db.getInstrumentBySerial(serialNo);
        } else if(description && number) {
            instruments = await db.getInstrumentByNumber(description, number);
        } else if (description) {
            instruments = await db.getInstrumentsByDescription(description);
        } else {
            instruments = await db.getInstruments();
        }
        res.json(instruments);
    } catch (error) {
        console.error('Error fetching instruments:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.post('/', async (req, res) => {
    const {description, make, model, serial, instrumentState, selectedNumber, profileId, username, location} = req.body;
    try {
        const equipment = await db.getEquipmentTypeDescription(description);
        code = equipment[0].code;
        await db.createInstrument(description, make, model, serial, instrumentState, selectedNumber, profileId, username, location);
        res.status(201).json({message: `${description} serial ${serial} entered as number ${selectedNumber} in the inventory \nPut label: ${code}-${selectedNumber} on the instrumentcase. `});
    } catch (error) {
        console.error('Error creating instrument:', error);
        res.status(500).json({error: 'Internal server error'});
    }

});
router.post('/swap', async (req, res) => {
    const {code, id_1, id_2, created_by} = req.body;
    try {
        await db.swapCases(code, id_1, id_2, created_by);
        res.status(201).json({message: `Instrument Cases swapped succesfully! `});
    } catch (error) {
        console.error('Error swapping instrument:', error);
        res.status(500).json({error: 'Internal server error'});
    }
});
router.post('/takeStock', async (req, res) => {
    const {location, item_id, description, number, status, created_by, notes} = req.body;
    try {
        await db.takeStock(location, item_id, description, number, status, created_by, notes);
        res.status(201).json({message: `${description} number ${number} confirmed in ${location}`});
    } catch (error) {
        console.error('An error occurred:', error);
        res.status(500).json({error: 'Internal server error'});
    }

});



module.exports = router;
