const fetch = require('node-fetch');
const Mustache = require('mustache');

const winston = require('../../../util/winston.js');
const { logHttp, } = require('../../../util/auxiliar.js');
const { serverPort, } = require('../../../util/config.js');

async function getTasksFeature(req, res) {
    // /features/:featureShortId/learningTasks
    const start = Date.now();
    try {
        fetch(Mustache.render('{{{urlServer}}}/tasks?feature={{{feature}}}', {
            urlServer: `http://127.0.0.1:${serverPort}`,
            feature: req.params.feature,
        })).then((response) => { return response.status == 200 ? response.json() : response.status == 204 ? undefined : null }).then((data) => {
            if (data !== null) {
                if (data !== undefined) {
                    res.send(data);
                } else {
                    res.sendStatus(204);
                }
            } else {
                res.sendStatus(404);
            }
        });
    } catch (error) {
        winston.info(Mustache.render(
            'getTasksFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getTasksFeature', start);
        res.status(500).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/features/chd:exFeature/learningTasks',
            { error: error, urlServer: urlServer }));
    }
}

module.exports = { getTasksFeature, };
