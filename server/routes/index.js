/**
 *
 * @param {*} req
 * @param {*} res
 */
function getIndex(req, res) {
    res.send('Welcome to CHEST');
}

module.exports = { getIndex };