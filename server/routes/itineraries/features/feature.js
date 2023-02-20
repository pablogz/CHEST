const Mustache = require('mustache');
const fetch = require('node-fetch');

const { logHttp, options4Request, sparqlResponse2Json, mergeResults } = require('../../../util/auxiliar');
const { getTasksFeatureIt } = require('../../../util/queries');
const winston = require('../../../util/winston');


function getTasksPointItineraryServer(req, res) {
    const start = Date.now();
    try {
        const idIt = Mustache.render(
            'http://chest.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        const idFeature = Mustache.render(
            'http://chest.gsic.uva.es/data/{{{feature}}}',
            { feature: req.params.feature });
        const options = options4Request(getTasksFeatureIt(idIt, idFeature));
        fetch(
            Mustache.render(
                'http://{{{host}}}:{{{port}}}{{{path}}}',
                {
                    host: options.host,
                    port: options.port,
                    path: options.path
                }),
            { headers: options.headers })
            .then(r => { return r.json(); })
            .then(json => {
                const tasksFeature = mergeResults(sparqlResponse2Json(json), 'task');
                const out = JSON.stringify(tasksFeature);
                winston.info(Mustache.render(
                    'getTasksFeatureIt || {{{body}}} || {{{time}}}',
                    {
                        body: out,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 200, 'getTasksFeatureIt', start);
                res.send(out);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getTasksFeatureIt || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getTasksFeatureIt', start);
        res.sendStatus(500);
    }
}

module.exports = {
    getTasksPointItineraryServer,
}