const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json, getTokenAuth, logHttp } = require('../../util/auxiliar');
const { isAuthor, hasTasksOrInItinerary, deleteObject, getInfoPOI, checkInfo, deleteInfoPoi, addInfoPoi } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');

/**
 *
 * @param {*} req
 * @param {*} res
 */
function getPOI(req, res) {
    /*
curl "localhost:11110/pois/Ttulo_punto"
    */
    const start = Date.now();
    try {
        const idPoi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: req.params.poi });
        const options = options4Request(getInfoPOI(idPoi));
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
                const poi = mergeResults(sparqlResponse2Json(json), 'poi');
                if (!poi.length) {
                    winston.info(Mustache.render(
                        'getPOI || {{{poi}}} || {{{time}}}',
                        {
                            poi: poi,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 404, 'getPOI', start);
                    res.sendStatus(404);
                } else {
                    const out = JSON.stringify(poi.pop());
                    winston.info(Mustache.render(
                        'getPOI || {{{poi}}} || {{{out}}} || {{{time}}}',
                        {
                            poi: poi,
                            out: out,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 200, 'getPOI', start);
                    res.send(out)
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getPOI || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getPOI', start);
        res.status(500).send(error);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function editPOI(req, res) {
    /*
curl -X PUT -H "Authorization: Bearer adfasd" -H "Content-Type: application/json" -d "{\"body\": [ {\"lat\": {\"action\": \"UPDATE\", \"newValue\": 12, \"oldValue\": 4}}, {\"comment\": {\"action\": \"REMOVE\", \"value\": {\"lang\": \"en\", \"value\": \"Hi!\"}}}, {\"comment\": {\"action\": \"ADD\", \"value\": {\"lang\": \"it\", \"value\": \"Chao!\"}}}]}" "localhost:11110/pois/Ttulo_punto"

    */
    const start = Date.now();
    try {
        const idPoi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: req.params.poi });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            let { body } = req;
                            if (body && body.body) {
                                body = body.body;
                                //Compruebo que el POI pertenezca al usuario
                                let options = options4Request(isAuthor(idPoi, infoUser.id));
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
                                        if (json.boolean === true || infoUser.rol === 0) {
                                            //Compruebo el formato de la petición del cliente
                                            //Obtengo todas las eliminaciones e inserciones                                
                                            /*
                                             [
                                                 {
                                                    lat: {
                                                     action: 'UPDATE'
                                                     newValue: 12
                                                     oldValue: 10
                                                 }},
                                                 {
                                                    label: {
                                                     action: 'ADD',
                                                     value: {
                                                         lang: 'it',
                                                         value: 'Chao'
                                                     }
                                                 }},
                                                 {
                                                    thumbnail: {
                                                     action: 'REMOVE',
                                                     value: 'url'
                                                 }}
                                             ]
                                             */
                                            const add = {};
                                            const remove = {};
                                            try {
                                                body.forEach(v => {
                                                    const k = Object.keys(v);
                                                    switch (v[k[0]].action) {
                                                        case 'UPDATE':
                                                            if (!v[k[0]].newValue || !v[k[0]].oldValue) {
                                                                throw new Error('400');
                                                            } else {
                                                                add[k[0]] = v[k[0]].newValue;
                                                                remove[k[0]] = v[k[0]].oldValue;
                                                            }
                                                            break;
                                                        case 'ADD':
                                                            if (!v[k[0]].value) {
                                                                throw new Error('400');
                                                            } else {
                                                                add[k[0]] = v[k[0]].value;
                                                            }
                                                            break;
                                                        case 'REMOVE':
                                                            if (!v[k[0]].value) {
                                                                throw new Error('400');
                                                            } else {
                                                                remove[k[0]] = v[k[0]].value;
                                                            }
                                                            break;
                                                        default:
                                                            throw new Error('400');
                                                    }
                                                });
                                                //Compruebo que los parámetros de las eliminaciones estuvieran en el repositorio (ASK)
                                                options = options4Request(checkInfo(idPoi, remove));
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
                                                        if (json.boolean === true) {
                                                            //Realizo las eliminaciones y, posteriormente, las inserciones
                                                            //TODO tengo que controlar cuando han finalizado las promesas
                                                            const requestsDelete = deleteInfoPoi(idPoi, remove);
                                                            requestsDelete.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(
                                                                    Mustache.render(
                                                                        'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                                        {
                                                                            host: options.host,
                                                                            port: options.port,
                                                                            path: options.path
                                                                        }),
                                                                    { headers: options.headers });
                                                            });
                                                            const requestsAdd = addInfoPoi(idPoi, add);
                                                            requestsAdd.forEach(request => {
                                                                options = options4Request(request, true);
                                                                fetch(
                                                                    Mustache.render(
                                                                        'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                                        {
                                                                            host: options.host,
                                                                            port: options.port,
                                                                            path: options.path
                                                                        }),
                                                                    { headers: options.headers });
                                                            });
                                                            winston.info(Mustache.render(
                                                                'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    poi: idPoi,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 202, 'editPOI', start);
                                                            res.sendStatus(202);
                                                        } else {
                                                            winston.info(Mustache.render(
                                                                'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    poi: idPoi,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 400, 'editPOI', start);
                                                            res.sendStatus(400);
                                                        }
                                                    });
                                            } catch (error) {
                                                winston.info(Mustache.render(
                                                    'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                                                    {
                                                        poi: idPoi,
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 400, 'editPOI', start);
                                                res.sendStatus(400);
                                            }
                                        } else {
                                            winston.info(Mustache.render(
                                                'editPOI || {{{poi}}} || {{{uid}}} || User is not the author || {{{time}}}',
                                                {
                                                    poi: idPoi,
                                                    uid: uid,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 401, 'editPOI', start);
                                            res.status(401).send('User is not the author of the POI');
                                        }
                                    });

                            } else {
                                winston.info(Mustache.render(
                                    'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                                    {
                                        poi: idPoi,
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 400, 'editPOI', start);
                                res.sendStatus(400);
                            }
                        } else {
                            winston.info(Mustache.render(
                                'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                                {
                                    poi: idPoi,
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'editPOI', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'editPOI || {{{poi}}} || {{{uid}}} || {{{time}}}',
                        {
                            poi: idPoi,
                            uid: uid,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'editPOI', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'editPOI || {{{poi}}} || {{{error}}} || {{{time}}}',
                    {
                        poi: idPoi,
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'editPOI', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editPOI || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'editPOI', start);
        res.sendStatus(500);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function deletePOI(req, res) {
    /*
curl -X DELETE --user pablo:pablo "localhost:11110/pois/Ttulo_punto"
    */
    // const idPoi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: encodeURIComponent(req.params.poi) });
    const idPoi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: req.params.poi });
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            //Compruebo que el poi pertenezca al usuario
                            let options = options4Request(isAuthor(idPoi, infoUser.id));
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
                                    if (json.boolean === true || infoUser.rol === 0) {
                                        //Compruebo que el poi no tiene ninguna tarea ni itinerario asociado
                                        options = options4Request(hasTasksOrInItinerary(idPoi));
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
                                                if (json.boolean === false) {
                                                    //Elimino el POI
                                                    options = options4Request(deleteObject(idPoi), true);
                                                    fetch(
                                                        Mustache.render(
                                                            'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                            {
                                                                host: options.host,
                                                                port: options.port,
                                                                path: options.path
                                                            }),
                                                        { headers: options.headers })
                                                        .then(r =>
                                                            res.sendStatus(r.status)
                                                        ).catch(error => res.status(500).send(error));
                                                } else {
                                                    res.status(401).send('This POI has associated tasks or itineraries');
                                                }
                                            });
                                    } else {
                                        res.status(401).send('User is not the author of the POI');
                                    }
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
        res.status(500).send(error);
    }
}

module.exports = {
    getPOI,
    editPOI,
    deletePOI,
};
