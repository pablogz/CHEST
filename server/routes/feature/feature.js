const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json, getTokenAuth, logHttp } = require('../../util/auxiliar');
const { isAuthor, hasTasksOrInItinerary, deleteObject, getInfoFeature, checkInfo, deleteInfoFeature, addInfoFeature } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');

const { getFeatureCache } = require('../../util/cacheFeatures');

/**
 *
 * @param {*} req
 * @param {*} res
 */
function getFeature(req, res) {
    /*
curl "localhost:11110/features/Ttulo_punto"
    */
    // const start = Date.now();
    // try {
    //     const idFeature = Mustache.render('http://chest.gsic.uva.es/data/{{{feature}}}', { feature: req.params.feature });
    //     const options = options4Request(getInfoFeature(idFeature));
    //     fetch(
    //         Mustache.render(
    //             'http://{{{host}}}:{{{port}}}{{{path}}}',
    //             {
    //                 host: options.host,
    //                 port: options.port,
    //                 path: options.path
    //             }),
    //         { headers: options.headers })
    //         .then(r => {
    //             return r.json();
    //         }).then(json => {
    //             const feature = mergeResults(sparqlResponse2Json(json), 'feature');
    //             if (!feature.length) {
    //                 winston.info(Mustache.render(
    //                     'getFeature || {{{feature}}} || {{{time}}}',
    //                     {
    //                         feature: feature,
    //                         time: Date.now() - start
    //                     }
    //                 ));
    //                 logHttp(req, 404, 'getFeature', start);
    //                 res.sendStatus(404);
    //             } else {
    //                 const out = JSON.stringify(feature.pop());
    //                 winston.info(Mustache.render(
    //                     'getFeature || {{{feature}}} || {{{out}}} || {{{time}}}',
    //                     {
    //                         feature: feature,
    //                         out: out,
    //                         time: Date.now() - start
    //                     }
    //                 ));
    //                 logHttp(req, 200, 'getFeature', start);
    //                 res.send(out)
    //             }
    //         });
    // } catch (error) {
    // winston.error(Mustache.render(
    //     'getFeature || {{{error}}} || {{{time}}}',
    //     {
    //         error: error,
    //         time: Date.now() - start
    //     }
    // ));
    // logHttp(req, 500, 'getFeature', start);
    // res.status(500).send(error);
    // }
    const start = Date.now();
    try {
        const idFeature = req.params.feature;
        const feature = getFeatureCache(idFeature); // aqui miro los providers. Si tengo OSM y Wikidata está completo por ahora. Luego tengo que meter SPARQL local
        const infoFeature = feature.infoFeature;
        const data = infoFeature.dataProvider;
        data != null ? res.send(data) : res.sendStatus(404);
    } catch (error) {
        winston.error(Mustache.render(
            'getFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getFeature', start);
        res.status(500).send(error);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function editFeature(req, res) {
    /*
curl -X PUT -H "Authorization: Bearer adfasd" -H "Content-Type: application/json" -d "{\"body\": [ {\"lat\": {\"action\": \"UPDATE\", \"newValue\": 12, \"oldValue\": 4}}, {\"comment\": {\"action\": \"REMOVE\", \"value\": {\"lang\": \"en\", \"value\": \"Hi!\"}}}, {\"comment\": {\"action\": \"ADD\", \"value\": {\"lang\": \"it\", \"value\": \"Chao!\"}}}]}" "localhost:11110/features/Ttulo_punto"

    */
    const start = Date.now();
    try {
        const idFeature = Mustache.render('http://chest.gsic.uva.es/data/{{{feature}}}', { feature: req.params.feature });
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            let { body } = req;
                            if (body && body.body) {
                                body = body.body;
                                //Compruebo que el feature pertenezca al usuario
                                let options = options4Request(isAuthor(idFeature, infoUser.id));
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
                                                options = options4Request(checkInfo(idFeature, remove));
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
                                                            const requestsDelete = deleteInfoFeature(idFeature, remove);
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
                                                            const requestsAdd = addInfoFeature(idFeature, add);
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
                                                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    feature: idFeature,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 202, 'editFeature', start);
                                                            res.sendStatus(202);
                                                        } else {
                                                            winston.info(Mustache.render(
                                                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                                {
                                                                    feature: idFeature,
                                                                    uid: uid,
                                                                    time: Date.now() - start
                                                                }
                                                            ));
                                                            logHttp(req, 400, 'editFeature', start);
                                                            res.sendStatus(400);
                                                        }
                                                    });
                                            } catch (error) {
                                                winston.info(Mustache.render(
                                                    'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                                    {
                                                        feature: idFeature,
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 400, 'editFeature', start);
                                                res.sendStatus(400);
                                            }
                                        } else {
                                            winston.info(Mustache.render(
                                                'editFeature || {{{feature}}} || {{{uid}}} || User is not the author || {{{time}}}',
                                                {
                                                    feature: idFeature,
                                                    uid: uid,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 401, 'editFeature', start);
                                            res.status(401).send('User is not the author of the feature');
                                        }
                                    });

                            } else {
                                winston.info(Mustache.render(
                                    'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                    {
                                        feature: idFeature,
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 400, 'editFeature', start);
                                res.sendStatus(400);
                            }
                        } else {
                            winston.info(Mustache.render(
                                'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                                {
                                    feature: idFeature,
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'editFeature', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'editFeature || {{{feature}}} || {{{uid}}} || {{{time}}}',
                        {
                            feature: idFeature,
                            uid: uid,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'editFeature', start);
                    res.status(403).send('You have to verify your email!');
                }
            }).catch(error => {
                winston.info(Mustache.render(
                    'editFeature || {{{feature}}} || {{{error}}} || {{{time}}}',
                    {
                        feature: idFeature,
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'editFeature', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editFeature || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'editFeature', start);
        res.sendStatus(500);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function deleteFeature(req, res) {
    /*
curl -X DELETE --user pablo:pablo "localhost:11110/features/Ttulo_punto"
    */
    // const idFeature = Mustache.render('http://chest.gsic.uva.es/data/{{{feature}}}', { feature: encodeURIComponent(req.params.feature) });
    const idFeature = Mustache.render('http://chest.gsic.uva.es/data/{{{feature}}}', { feature: req.params.feature });
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            //Compruebo que el feature pertenezca al usuario
                            let options = options4Request(isAuthor(idFeature, infoUser.id));
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
                                        //Compruebo que el feature no tiene ninguna tarea ni itinerario asociado
                                        options = options4Request(hasTasksOrInItinerary(idFeature));
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
                                                    //Elimino el feature
                                                    options = options4Request(deleteObject(idFeature), true);
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
                                                    res.status(401).send('This feature has associated tasks or itineraries');
                                                }
                                            });
                                    } else {
                                        res.status(401).send('User is not the author of the feature');
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
    getFeature,
    editFeature,
    deleteFeature,
};
