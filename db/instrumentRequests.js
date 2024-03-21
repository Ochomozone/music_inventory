const createRequest = async (userId, description, quantity) => {
    if (!description || !userId || !quantity) {
        throw new Error('Missing required parameters');
    } else { try {
        const queryText = `
            INSERT INTO instrument_requests (user_id, instrument, quantity)
            VALUES ($1, $2, $3)
            RETURNING *
        `;
        const rows = await query(queryText, [userId, description, quantity]);
        return rows; 
    } catch (error) {
        console.error('Error creating request:', error);
        throw error;
    }}
};