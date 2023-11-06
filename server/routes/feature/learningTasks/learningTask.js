const fetch = require('node-fetch');

const winston = require('../../../util/winston.js');
const { serverPort, } = require('../../../util/config.js');


async function removeLearningTask(req, res) {
    const start = Date.now();
    try {
        const { feature, learningTask } = req.params;
        fetch(`http://127.0.0.1:${serverPort}/tasks/${learningTask}?feature=${feature}`, {
            method: 'DELETE',
            headers: {
                'Authorization': req.headers.authorization,
            },
        }).then((response) => {
            res.sendStatus(response.status)
        });
    } catch (error) {
        winston.info(Mustache.render(
            'removeLearningTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        res.status(500).send(error);
    }
}

module.exports = {
    removeLearningTask,
}