const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json } = require('../../util/auxiliar');
const { getPOIsItinerary } = require('../../util/queries');

// curl "localhost:11110/itineraries/rkoxEMyKgT4BaB3xUofRPp" -v
function getItineraryServer(req, res) {
    try {
        const idIt = Mustache.render(
            'http://chest.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        const options = options4Request(getPOIsItinerary(idIt));
        fetch(
            Mustache.render(
                'http://{{{host}}}:{{{port}}}{{{path}}}',
                {
                    host: options.host,
                    port: options.port,
                    path: options.path
                }),
            { headers: options.headers })
            .then(r => {
                return r.json();
            }).then(json => {
                const itinerary = mergeResults(sparqlResponse2Json(json), 'poi');
                if (!itinerary.length) {
                    res.sendStatus(404);
                } else {
                    res.send(JSON.stringify(itinerary.pop()))
                }
            });
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }
}

function updateItineraryServer(req, res) {
    res.sendStatus(202);
}
function deleteItineraryServer(req, res) {
    res.sendStatus(202);
}

module.exports = {
    getItineraryServer,
    updateItineraryServer,
    deleteItineraryServer,
}