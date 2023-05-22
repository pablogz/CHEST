const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json, getTokenAuth, logHttp } = require('../../util/auxiliar');
const { isAuthor, hasTasksOrInItinerary, deleteObject, getInfoFeature, checkInfo, deleteInfoFeature, addInfoFeature, SPARQLQuery } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');

const { getFeatureCache, InfoFeatureCache } = require('../../util/cacheFeatures');

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function getFeature(req, res) {
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
        const feature = getFeatureCache(idFeature);
        // Mi base está en OSM (y en la información del SPARQL local). Si solo tengo OSM compruebo si referencia a Wikidata. Si tengo info del repositorio local devuelvo directamente esta info
        if (feature != null) {
            if (feature.providers.includes('localRepo')) {
                // TODO
                feature.infoFeature != null ? res.send(feature.infoFeature) : res.sendStatus(feature);
            } else {
                // Tengo datos de OSM, ¿Tengo datos de algo más?
                // if (feature.providers.includes('wikidata')) {
                //     res.send(feature.infoFeature);
                // } else {
                // Compruebo si en los datos de OSM tiene enlace de Wikidata. Si los tiene los solicito, guardo y envío todo al cliente.
                const infoFeatureOSM = feature.infoFeature.find((element) => element.provider == 'osm');
                let query;
                if (infoFeatureOSM.dataProvider.wikidata != null) {
                    const idWikidata = infoFeatureOSM.dataProvider.wikidata;
                    query = Mustache.render('SELECT ?type ?label ?description ?image ?licImage WHERE {\
                            {{{idWiki}}}\
                             wdt:P31 ?type .\
                             OPTIONAL {\
                                {{{idWiki}}} rdfs:label ?label .\
                                FILTER(lang(?label)="es" || lang(?label)="en" || lang(?label)="pt").\
                             }\
                             OPTIONAL {\
                                {{{idWiki}}} schema:description ?description .\
                               FILTER(lang(?description)="es" || lang(?description)="en" || lang(?description)="pt").\
                             }\
                             OPTIONAL {\
                                {{{idWiki}}} wdt:P18 ?image .\
                             }\
                           }', { idWiki: idWikidata });
                    // console.log(query.replace(/\s+/g, ' '));
                    const wikidataQuery = new SPARQLQuery("https://query.wikidata.org/sparql");
                    const wikidataResult = await wikidataQuery.query(query);
                    if (wikidataResult != null) {
                        let wdR = mergeResults(sparqlResponse2Json(wikidataResult)).pop();
                        if (wdR.image !== undefined && typeof wdR.image === 'string') {
                            wdR.licenseImage = wdR.image.replace("Special:FilePath/", "File:");
                        }
                        const ifc = new InfoFeatureCache('wikidata', idWikidata, wdR);
                        feature.addInfoFeatureCache(ifc);
                    }
                }
                if (infoFeatureOSM.dataProvider.dbpedia != null) {
                    const idDbpedia = infoFeatureOSM.dataProvider.dbpedia;
                    if (idDbpedia.includes('http://es')) {
                        //Además de a la versión internacional tengo que solicitar info a la española
                        const esDBpediaQuery = new SPARQLQuery('https://es.dbpedia.org/sparql');
                        query = Mustache.render('select distinct ?comment where {\
                                <{{{idDb}}}>\
                                  rdfs:comment ?comment .\
                                FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .\
                                }', { idDb: idDbpedia });
                        let esDBpediaResult = await esDBpediaQuery.query(query);
                        if (esDBpediaResult != null) {
                            esDBpediaResult = mergeResults(sparqlResponse2Json(esDBpediaResult));
                            if (esDBpediaResult.length > 0) {
                                const ifc = new InfoFeatureCache('esDBpedia', idDbpedia, esDBpediaResult.pop());
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                    }
                    const dbPediaQuery = new SPARQLQuery('https://dbpedia.org/sparql');
                    query = Mustache.render('select distinct ?comment where {\
                            <{{{idDb}}}>\
                            rdfs:comment ?comment .\
                            FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .\
                        }', { idDb: idDbpedia });
                    let dbpedia1 = await dbPediaQuery.query(query);
                    if (dbpedia1 != null) {
                        dbpedia1 = sparqlResponse2Json(dbpedia1);
                    }
                    query = Mustache.render('select distinct ?place ?comment where {\
                            ?place\
                              rdfs:comment ?comment ;\
                              owl:sameAs <{{{idDb}}}> .\
                            FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .\
                            }', { idDb: idDbpedia });
                    let dbpedia2 = await dbPediaQuery.query(query);
                    if (dbpedia2 != null) {
                        dbpedia2 = sparqlResponse2Json(dbpedia2);
                    }
                    const dbpedia = mergeResults(dbpedia1.concat(dbpedia2));
                    if (dbpedia.length > 0) {
                        const ifc = new InfoFeatureCache('dbpedia', idDbpedia, dbpedia.pop());
                        feature.addInfoFeatureCache(ifc);
                    }
                }
                const out = [];
                feature.infoFeature.forEach((infoFeature) => {
                    const dataProvider = infoFeature.dataProvider;
                    switch (infoFeature.provider) {
                        case 'osm':
                            out.push({
                                provider: infoFeature.provider,
                                data: {
                                    id: infoFeature._id,
                                    lat: dataProvider._lat,
                                    long: dataProvider._long,
                                    name: dataProvider._name,
                                    wikipedia: dataProvider._wikipedia,
                                    tags: dataProvider._tags
                                }
                            });
                            break;
                        case 'wikidata':
                            out.push({
                                provider: infoFeature.provider,
                                data: {
                                    id: infoFeature._id,
                                    label: dataProvider.label,
                                    description: dataProvider.description,
                                    image: dataProvider.image,
                                    licenseImage: dataProvider.licenseImage,
                                    type: dataProvider.type
                                }
                            });
                            break;
                        case 'esDBpedia':
                            out.push({
                                provider: infoFeature.provider,
                                data: {
                                    id: infoFeature._id,
                                    comment: dataProvider.comment,
                                }
                            });
                            break;
                        case 'dbpedia':
                            out.push({
                                provider: infoFeature.provider,
                                data: {
                                    id: infoFeature._id,
                                    comment: dataProvider.comment,
                                }
                            });
                            break;
                        default:
                            out.push({
                                provider: infoFeature.provider,
                                data: infoFeature.dataProvider
                            });
                            break;
                    }
                });
                res.send(out);
            }
            // }
        } else {
            res.sendStatus(404);
        }

        // const wikidataQuery = new SPARQLQuery("https://query.wikidata.org/sparql");

        // //San Pablo: Q3031934 http://es.dbpedia.org/resource/Iglesia_de_San_Pablo_(Valladolid)
        // //Palacio del Marqués de Valverde: Q6058611 http://es.dbpedia.org/resource/Palacio_del_Marqu%C3%A9s_de_Valverde
        // let query = `SELECT ?type ?label ?description ?image ?licImage WHERE {
        //     wd:Q6058611
        //      wdt:P31 ?type ;
        //      rdfs:label ?label .
        //      FILTER(lang(?label)="es" || lang(?label)="en" || lang(?label)="pt").
        //      OPTIONAL {
        //        wd:Q6058611 schema:description ?description .
        //        FILTER(lang(?description)="es" || lang(?description)="en" || lang(?description)="pt").
        //      }
        //      OPTIONAL {
        //        wd:Q6058611 wdt:P18 ?image .
        //      }
        //    }`;
        // const wikidataResult = await wikidataQuery.query(query);
        // let out = "WIKIDATA:<br>";
        // out += wikidataResult == null ? "" : JSON.stringify(mergeResults(sparqlResponse2Json(wikidataResult)));
        // const esDBpediaQuery = new SPARQLQuery('https://es.dbpedia.org/sparql');
        // query = `select distinct ?comment where {
        //     <http://es.dbpedia.org/resource/Palacio_del_Marqués_de_Valverde>
        //       rdfs:comment ?comment .
        //     FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .
        //     }`;
        // const esDBpediaResult = await esDBpediaQuery.query(query);
        // out += "<br><br>esDBPEDIA:<br>";
        // out += esDBpediaResult == null ? "" : JSON.stringify(mergeResults(sparqlResponse2Json(esDBpediaResult)));
        // const dbPediaQuery = new SPARQLQuery('https://dbpedia.org/sparql');
        // query = `select distinct ?comment where {
        //     <http://es.dbpedia.org/resource/Palacio_del_Marqués_de_Valverde>
        //       rdfs:comment ?comment .
        //     FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .
        //     }`;
        // const dbpedia1 = await dbPediaQuery.query(query);
        // out += "<br><br>DBPEDIA1:<br>"
        // out += dbpedia1 == null ? "" : JSON.stringify(mergeResults(sparqlResponse2Json(dbpedia1)));
        // query = `select distinct ?place ?comment where {
        //     ?place
        //       rdfs:comment ?comment ;
        //       [] <http://es.dbpedia.org/resource/Palacio_del_Marqués_de_Valverde> .
        //     FILTER(lang(?comment)="es" || lang(?comment)="en" || lang(?comment)="pt") .
        //     }`;
        // const dbpedia2 = await dbPediaQuery.query(query);
        // out += '<br><br>DBPEDIA2:<br>';
        // out += dbpedia2 == null ? '' : JSON.stringify(mergeResults(sparqlResponse2Json(dbpedia2)));

        // res.send(out);

    } catch (error) {
        console.error(error);
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
