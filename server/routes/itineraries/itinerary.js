const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, sparqlResponse2Json, getTokenAuth } = require('../../util/auxiliar');
const { getPOIsItinerary, isAuthor, deleteItinerarySparql } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');

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
                const itineraryJson = sparqlResponse2Json(json);
                if (!itineraryJson.length) {
                    res.sendStatus(404);
                } else {
                    const points = [];
                    let first = null;
                    itineraryJson.forEach((point) => {
                        const findIndex = points.findIndex(p => {
                            return p.poi === point.poi;
                        });
                        if (findIndex > -1) {
                            const prev = points.splice(findIndex, 1).pop();
                            // Agrego la información que no esté repetida
                            const keys = Object.keys(point);
                            for (let i = 0, tama = keys.length; i < tama; i++) {
                                const prop = keys[i];
                                if (prev[prop] === undefined) {
                                    prev[prop] = point[prop];
                                } else {
                                    if (typeof prev[prop] === 'object') {
                                        if (Array.isArray(prev[prop])) {
                                            let encontrado = false;
                                            if (prop === 'label' || prop === 'comment' || prop === 'altComment') {
                                                //busco si está guardado el mismo idioma
                                                prev[prop].forEach(ele => {
                                                    if (ele.lang === point[prop].lang) {
                                                        encontrado = true;
                                                    }
                                                });

                                            } else {
                                                prev[prop].forEach(ele => {
                                                    if (ele === point[prop]) {
                                                        encontrado = true;
                                                    }
                                                });
                                            }
                                            if (!encontrado) {
                                                prev[prop].push(point[prop]);
                                            }
                                        } else {
                                            let save = false;
                                            for (let ele in prev[prop]) {
                                                if (prev[prop][ele] !== point[prop][ele]) {
                                                    save = true;
                                                    break;
                                                }
                                            }
                                            if (save) {
                                                prev[prop] = [prev[prop], point[prop]];
                                            }
                                        }
                                    } else {
                                        if (prev[prop] !== point[prop]) {
                                            prev[prop] = [prev[prop], point[prop]];
                                        }
                                    }
                                }
                            }
                            points.push(prev);
                        } else {
                            if (first === null && point.first !== undefined) {
                                first = point.first;
                            }
                            points.push(point);
                        }
                    }
                    );
                    const out = {};
                    if (first !== null) {
                        out.first = first;
                    }
                    out.points = points;
                    res.send(JSON.stringify(out))
                }
            });
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }
}

function updateItineraryServer(req, res) {
    res.sendStatus(418);
}

// curl -X DELETE -H "Authorization: Bearer fdas" "localhost:11110/itineraries/rkoxEMyKgT4BaB3xUofRPp" -v
function deleteItineraryServer(req, res) {
    try {
        const idIt = Mustache.render(
            'http://chest.gsic.uva.es/data/{{{it}}}',
            { it: req.params.itinerary });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            let options = options4Request(isAuthor(idIt, infoUser.id));
                            fetch(
                                Mustache.render(
                                    'http://{{{host}}}:{{{port}}}{{{path}}}',
                                    {
                                        host: options.host,
                                        port: options.port,
                                        path: options.path
                                    }),
                                { headers: options.headers })
                                .then((r) => r.json())
                                .then((json) => {
                                    if (json.boolean === true || infoUser.rol === 0) {
                                        options = options4Request(deleteItinerarySparql(idIt), true);
                                        fetch(
                                            Mustache.render(
                                                'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                {
                                                    host: options.host,
                                                    port: options.port,
                                                    path: options.path
                                                }),
                                            { headers: options.headers })
                                            .then(r => res.sendStatus(r.status))
                                            .catch(error => {
                                                console.log(error);
                                                res.sendStatus(500);
                                            });
                                    } else {
                                        res.sendStatus(401);
                                    }
                                })
                                .catch((error) => {
                                    console.log(error);
                                    res.sendStatus(500);
                                });
                        } else {
                            res.sendStatus(401);
                        }
                    });
                } else {
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                console.error(error);
                res.sendStatus(401);
            });
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }
}

module.exports = {
    getItineraryServer,
    updateItineraryServer,
    deleteItineraryServer,
}