const FirebaseAdmin = require('firebase-admin');
const Mustache = require('mustache');
const fetch = require('node-fetch');

const { Itinerary, PointItinerary } = require("../../util/pojos/itinerary");
const { getTokenAuth, generateUid, options4Request, sparqlResponse2Json, mergeResults } = require('../../util/auxiliar');
const { getInfoUser } = require('../../util/bd');
const { checkDataSparql, insertItinerary, getAllItineraries } = require('../../util/queries');

// curl "localhost:11110/itineraries" -v
function getItineariesServer(req, res) {
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
                    const itsResponse = [];
                    itineraries.forEach(element => {
                        const v = {};
                        for (let ele in element) {
                            if (ele !== 'type') {
                                v[ele] = element[ele];
                            } else {
                                for (let t of element[ele]) {
                                    if (t !== 'http://chest.gsic.uva.es/ontology/Itinerary') {
                                        switch (t) {
                                            case 'http://chest.gsic.uva.es/ontology/ItineraryOrder':
                                                v[ele] = 'order';
                                                break;
                                            case 'http://chest.gsic.uva.es/ontology/ItineraryOrderPoi':
                                                v[ele] = 'orderPoi';
                                                break;
                                            case 'http://chest.gsic.uva.es/ontology/ItineraryNoOrder':
                                                v[ele] = 'noOrder';
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
                    res.send(JSON.stringify(itsResponse));
                } else {
                    res.sendStatus(204);
                }
            })
    } catch (error) {
        console.log(error);
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
    3) Comprobar que los POI y tasks del itinerario existan
    4) Agregar el itineario y devolverle al cliente el identificador
     */
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
                                console.log(error);
                                sigue = false;
                                break;
                            }
                        }
                    }
                }
                if (sigue) {
                    // 1
                    FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                        .then(async dToken => {
                            const { uid, email_verified } = dToken;
                            if (email_verified && uid !== '') {
                                // 2
                                getInfoUser(uid).then(async infoUser => {
                                    if (infoUser !== null && infoUser.rol < 2) {
                                        // 3
                                        itinerary.setAuthor(infoUser.id);
                                        const options = options4Request(checkDataSparql(itinerary.points));
                                        fetch(
                                            Mustache.render(
                                                'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                {
                                                    host: options.host,
                                                    port: options.port,
                                                    path: options.path
                                                }),
                                            { headers: options.headers })
                                            .then(async (resp) => {
                                                switch (resp.status) {
                                                    case 200:
                                                        return resp.json();
                                                    default:
                                                        return null;
                                                }
                                            }).then(async (data) => {
                                                //TODO
                                                //if (data !== null && data.boolean === true) {
                                                if (true) {
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
                                                            res.location(itinerary.id).sendStatus(201);
                                                        } else {
                                                            res.sendStatus(500);
                                                        }
                                                    });
                                                } else {
                                                    res.sendStatus(400);
                                                }
                                            }).catch((error) => {
                                                console.log(error);
                                                res.sendStatus(500);
                                            });

                                    } else {
                                        res.sendStatus(401);
                                    }
                                });
                            }
                        }).catch(error => {
                            console.error(error);
                            res.sendStatus(500);
                        });

                } else {
                    res.status(403).send('You have to verify your email!');
                }
            } else {
                res.sendStatus(400);
            }
        } else {
            res.sendStatus(400);
        }
    } catch (error) {
        console.log(error);
        res.sendStatus(500);
    }

}

module.exports = {
    getItineariesServer,
    newItineary
}