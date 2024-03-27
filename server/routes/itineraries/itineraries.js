const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');
const fetch = require('node-fetch');

const { Itinerary, PointItinerary } = require("../../util/pojos/itinerary");
const { getTokenAuth, generateUid, options4Request, sparqlResponse2Json, mergeResults, logHttp } = require('../../util/auxiliar');
const { getInfoUser } = require('../../util/bd');
const { checkDataSparql, insertItinerary, getAllItineraries } = require('../../util/queries');

const winston = require('../../util/winston');

// curl "localhost:11110/itineraries" -v
function getItineariesServer(req, res) {
    const start = Date.now();
    try {
        const options = options4Request(getAllItineraries());
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
                const itineraries = mergeResults(sparqlResponse2Json(json), 'it');
                if (itineraries.length > 0) {
                    itineraries.sort((a, b) => a.update - b.update);
                    const itsResponse = [];
                    itineraries.forEach(element => {
                        const v = {};
                        for (let ele in element) {
                            if (ele !== 'type') {
                                v[ele] = element[ele];
                            } else {
                                for (let t of element[ele]) {
                                    if (t !== 'http://moult.gsic.uva.es/ontology/Itinerary') {
                                        switch (t) {
                                            case 'http://moult.gsic.uva.es/ontology/ListItinerary':
                                            case 'http://moult.gsic.uva.es/ontology/BagSTsListTasksItinerary':
                                            case 'http://moult.gsic.uva.es/ontology/ListSTsBagTasks':
                                            case 'http://moult.gsic.uva.es/ontology/BagItinerary':
                                                v[ele] = t;
                                                break;
                                            default:
                                                break;
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                        itsResponse.push(v);
                    });
                    winston.info(Mustache.render(
                        'getItineraries || {{{body}}} || {{{time}}}',
                        {
                            body: JSON.stringify(itsResponse),
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 200, 'getItineraries', start);
                    res.send(JSON.stringify(itsResponse));
                } else {
                    winston.info(Mustache.render(
                        'getItineraries || empty || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 204, 'getItineraries', start);
                    res.sendStatus(204);
                }
            })
    } catch (error) {
        winston.error(Mustache.render(
            'getItineraries || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

// curl -H "Content-Type: Application/json" -d "{\"type\": \"order\", \"label\": {\"value\": \"Itinerary's label\", \"lang\": \"en\"}, \"comment\": {\"value\": \"Itinerary's description\", \"lang\": \"en\"}, \"points\": [{\"poi\": \"http://chest.gsic.uva.es/data/Casa_Consistorial_de_Valladolid_4728611111_41652222222\", \"tasks\": [\"http://chest.gsic.uva.es/data/Awi92rS3ZUxwqhfGTACCse\",\"http://chest.gsic.uva.es/data/mVX3P6TRhKAZdjhwY8vAKH\"]},{\"poi\": \"http://chest.gsic.uva.es/data/Palacio_de_la_Magdalena\", \"tasks\":[]}]}" "localhost:11110/itineraries" -v
async function newItineary(req, res) {
    /*
    0) Comprobar que el cuerpo de la petición tiene el formato adecuado
    {
        "type": "[order/orderPoi/noOrder/]",
        "points": [
            ...,
            {
                "poi": "chestd:patata"
                "tasks": ["chestd:132123fdas", "chestd:12312321kjdafsneqrwjfdsa", ...]
            },
            ...
        ]
    } 
    1) Recuperar el usuario mediante el token de autenticación
    2) Comprobar que el usuario puede crear el itinerario
    // 3) Comprobar que los POI y tasks del itinerario existan
    4) Agregar el itineario y devolverle al cliente el identificador
     */
    const start = Date.now();
    try {
        // 0
        if (req.body) {
            const { type, points } = req.body;
            let { label, comment } = req.body;
            if (type !== undefined &&
                typeof type === 'string' &&
                points !== undefined &&
                Array.isArray(points) &&
                label !== undefined &&
                comment !== undefined) {
                let sigue = true;
                const itinerary = Itinerary.ItineraryEmpty();
                itinerary.setType(type);
                if (itinerary.type == null) {
                    sigue = false;
                }
                if (sigue) {
                    if (!Array.isArray(label)) {
                        label = [label];
                    }
                    for (let l of label) {
                        if (l.value === undefined || l.lang === undefined) {
                            sigue = false;
                            break;
                        }
                    }
                    if (sigue) {
                        itinerary.setLabels(label);
                        if (!Array.isArray(comment)) {
                            comment = [comment];
                        }
                        for (let l of comment) {
                            if (l.value === undefined || l.lang === undefined) {
                                sigue = false;
                                break;
                            }
                        }
                        if (sigue) {
                            itinerary.setComments(comment);
                            for (let point of points) {
                                try {
                                    if (point.poi !== undefined &&
                                        point.tasks !== undefined &&
                                        typeof point.poi === 'string' &&
                                        Array.isArray(point.tasks)) {
                                        if (point.altComment !== 'undefined') {
                                            itinerary.addPoint(new PointItinerary(point.poi, point.altComment, point.tasks))
                                        } else {
                                            itinerary.addPoint(PointItinerary.WitoutComment(point.poi, point.tasks));
                                        }
                                    } else {
                                        sigue = false;
                                        break;
                                    }
                                } catch (error) {
                                    // console.log(error);
                                    sigue = false;
                                    break;
                                }
                            }
                        }
                    }
                }
                if (sigue) {
                    // 1
                    FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                        .then(async dToken => {
                            const { uid } = dToken;
                            if (uid !== '') {
                                // 2
                                getInfoUser(uid).then(async infoUser => {
                                    if (infoUser !== null && infoUser.rol < 2) {
                                        // 3
                                        itinerary.setAuthor(infoUser.id);
                                        // const options = options4Request(checkDataSparql(itinerary.points));
                                        // fetch(
                                        //     Mustache.render(
                                        //         'http://{{{host}}}:{{{port}}}{{{path}}}',
                                        //         {
                                        //             host: options.host,
                                        //             port: options.port,
                                        //             path: options.path
                                        //         }),
                                        //     { headers: options.headers })
                                        //     .then(async (resp) => {
                                        //         switch (resp.status) {
                                        //             case 200:
                                        //                 return resp.json();
                                        //             default:
                                        //                 return null;
                                        //         }
                                        //     }).then(async (data) => {
                                        //         //TODO
                                        //         //if (data !== null && data.boolean === true) {
                                        // if (true) {
                                        itinerary.setId(await generateUid());
                                        const queries = insertItinerary(itinerary);
                                        const promises = [];
                                        queries.forEach(query => {
                                            const options2 = options4Request(query, true);
                                            promises.push(
                                                fetch(Mustache.render(
                                                    'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                    {
                                                        host: options2.host,
                                                        port: options2.port,
                                                        path: options2.path
                                                    }),
                                                    { headers: options2.headers })
                                            );
                                        });
                                        Promise.all(promises).then((values) => {
                                            let sendOK = true;
                                            values.forEach(v => {
                                                if (v.status !== 200) {
                                                    sendOK = false;
                                                }
                                            });
                                            if (sendOK) {
                                                winston.info(Mustache.render(
                                                    'newItinerary || {{{uid}}} || {{{time}}}',
                                                    {
                                                        uid: itinerary.id,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 201, 'newItinerary', start);
                                                res.location(itinerary.id).sendStatus(201);
                                            } else {
                                                res.sendStatus(500);
                                            }
                                        });
                                        // } else {
                                        //     res.sendStatus(400);
                                        // }
                                        // }).catch((error) => {
                                        //     winston.error(Mustache.render(
                                        //         'newItinerary || {{{error}}} || {{{time}}}',
                                        //         {
                                        //             error: error,
                                        //             time: Date.now() - start
                                        //         }
                                        //     ));
                                        //     logHttp(req, 500, 'newItinerary', start);
                                        //     res.sendStatus(500);
                                        // });

                                    } else {
                                        winston.info(Mustache.render(
                                            'newItinerary || Unprivileged user || {{{time}}}',
                                            {
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 401, 'newItinerary', start);
                                        res.sendStatus(401);
                                    }
                                });
                            } else {
                                winston.info(Mustache.render(
                                    'newItinerary || 403 - Verify email || {{{time}}}',
                                    {
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 403, 'newItinerary', start);
                                res.status(403).send('You have to verify your email!');
                            }
                        }).catch(error => {
                            winston.error(Mustache.render(
                                'newItinerary || {{{error}}} || {{{time}}}',
                                {
                                    error: error,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 500, 'newItinerary', start);
                            res.sendStatus(500);
                        });

                } else {
                    winston.info(Mustache.render(
                        'newItinerary || 400 - Missing or incorrect fields || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 400, 'newItinerary', start);
                    res.sendStatus(400);
                }
            } else {
                winston.info(Mustache.render(
                    'newItinerary || 400 - Missing or incorrect fields || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newItinerary', start);
                res.sendStatus(400);
            }
        } else {
            winston.info(Mustache.render(
                'newItinerary || 400 - Missing body || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newItinerary', start);
            res.sendStatus(400);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'newItinerary || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'newItinerary', start);
        res.sendStatus(500);
    }

}

module.exports = {
    getItineariesServer,
    newItineary
}