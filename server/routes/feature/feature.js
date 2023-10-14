const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const {
    options4Request,
    mergeResults,
    sparqlResponse2Json,
    getTokenAuth,
    logHttp,
    shortId2Id,
    id2ShortId,
    options4RequestOSM,
} = require('../../util/auxiliar');
const {
    isAuthor,
    hasTasksOrInItinerary,
    deleteObject,
    getInfoFeatureWikidata,
    checkInfo,
    deleteInfoFeature,
    addInfoFeature,
    // SPARQLQuery,
    getInfoFeatureEsDBpedia,
    getInfoFeatureDBpedia1,
    getInfoFeatureDBpedia2,
    queryBICJCyL,
    getInfoFeatureOSM,
} = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');
const SPARQLQuery = require('../../util/sparqlQuery');
const { ElementOSM } = require('../../util/pojos/osm');
const { getFeatureCache, InfoFeatureCache, updateFeatureCache, FeatureCache } = require('../../util/cacheFeatures');
const { FeatureWikidata } = require('../../util/pojos/wikidata');
const { FeatureJCyL } = require('../../util/pojos/jcyl');
const { FeatureDBpedia } = require('../../util/pojos/dbpedia');


/**
 * Retrieves a feature from cache or external providers based on the given feature ID.
 * @async
 * @function getFeature
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Promise<void>} - A Promise that resolves when the feature is retrieved or sends an error response if the feature is not found.
 */
async function getFeature(req, res) {
    const start = Date.now();
    try {
        const idFeature = shortId2Id(req.params.feature);
        if (idFeature !== null) {
            let feature = await getFeatureCache(idFeature);
            let update = false;
            if (feature === null) {
                // No está en la caché
                // Tengo que averiguar el proveedor de la feature a través del identificador
                const shortProvider = req.params.feature.split(':')[0];
                switch (shortProvider) {
                    case 'osmn':
                    case 'osmr':
                    case 'osmw': {
                        const options = options4RequestOSM(getInfoFeatureOSM(idFeature.split('/').pop(), shortProvider == 'osmw' ? 'way' : shortProvider == 'osmn' ? 'node' : 'relation'));
                        console.log(options.host + options.path);
                        const data = await fetch(options.host + options.path, { headers: options.headers }).then(r => {
                            return r.status == 200 ? r.json() : null;
                        });
                        if (data != null && data.elements != null && data.elements.length > 0) {
                            const elementOSM = new ElementOSM(data.elements[0]);
                            feature = new FeatureCache(elementOSM.id);
                            feature.addInfoFeatureCache(new InfoFeatureCache('osm', elementOSM.id, elementOSM));
                        }
                        break;
                    }
                    case 'wd': {
                        const query = getInfoFeatureWikidata(id2ShortId(idFeature));
                        const wikidataQuery = new SPARQLQuery("https://query.wikidata.org/sparql");
                        const data = await wikidataQuery.query(query);
                        if (data != null) {
                            let wdR = mergeResults(sparqlResponse2Json(data)).pop();
                            if (wdR != undefined) {
                                const fWd = new FeatureWikidata(id2ShortId(idFeature), wdR);
                                await fWd.initialize();
                                const ifc = new InfoFeatureCache('wikidata', fWd.id, fWd);
                                feature = new FeatureCache(fWd.id);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'dbpedia': {
                        const dbpediaQuery = new SPARQLQuery('https://dbpedia.org/sparql');
                        const query = getInfoFeatureDBpedia1(idFeature);
                        const data = await dbpediaQuery.query(query);
                        if (data != null) {
                            const dbpedia = mergeResults(sparqlResponse2Json(data)).pop();
                            if (dbpedia != undefined) {
                                const ifc = new InfoFeatureCache('dbpedia', idFeature, new FeatureDBpedia(idFeature, dbpedia));
                                feature = new FeatureCache(idFeature);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'esdbpedia': {
                        const dbpediaQuery = new SPARQLQuery('https://es.dbpedia.org/sparql');
                        const query = getInfoFeatureEsDBpedia(idFeature);
                        const data = await dbpediaQuery.query(query);
                        if (data != null) {
                            const esdbpedia = mergeResults(sparqlResponse2Json(data)).pop();
                            if (esdbpedia != undefined) {
                                const ifc = new InfoFeatureCache('esDBpedia', idFeature, new FeatureDBpedia(idFeature, esdbpedia));
                                feature = new FeatureCache(idFeature);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        break;
                    }
                    case 'chd':
                        // TODO Petición al repositorio local de CHEST para comenzar a crear la feature
                        break;
                    default:
                        // Nunca se va a entrar aqui porque ya se ha hecho la comprobación de que el shortID es válido
                        logHttp(req, 400, 'getFeature', start);
                        res.sendStatus(400);
                        break;
                }
                if (feature === null) {
                    // No se ha encontrado la feature que solicita el cliente
                    logHttp(req, 404, 'getFeature', start);
                    res.sendStatus(404);
                }
            } else {
                update = true;
            }
            if (feature !== null) {
                let sigueBuscando = true;
                while (sigueBuscando) {
                    if (feature.providers.length == 1) {
                        // Compruebo qué peticiones puedo realizar con la información que tengo
                        const listPromise = [];
                        let idOSM = '';
                        let idWikidata = '';
                        let idDBpedia = '';
                        switch (feature.providers[0]) {
                            case 'osm': {
                                listPromise.push(Promise.resolve(null));
                                let query;
                                const infoFeatureOSM = feature.infoFeature[0];
                                if (infoFeatureOSM.dataProvider.wikidata != null) {
                                    idWikidata = infoFeatureOSM.dataProvider.wikidata;
                                    query = getInfoFeatureWikidata(idWikidata);
                                    const wikidataQuery = new SPARQLQuery("https://query.wikidata.org/sparql");
                                    listPromise.push(wikidataQuery.query(query));
                                } else {
                                    listPromise.push(Promise.resolve(null));
                                }
                                if (infoFeatureOSM.dataProvider.dbpedia != null) {
                                    idDBpedia = infoFeatureOSM.dataProvider.dbpedia;
                                    if (idDBpedia.includes('http://es')) {
                                        //Además de a la versión internacional tengo que solicitar info a la española
                                        const esDBpediaQuery = new SPARQLQuery('https://es.dbpedia.org/sparql');
                                        query = getInfoFeatureEsDBpedia(idDBpedia);
                                        listPromise.push(esDBpediaQuery.query(query));

                                    } else {
                                        listPromise.push(Promise.resolve(null));
                                    }
                                    const dbPediaQuery = new SPARQLQuery('https://dbpedia.org/sparql');
                                    query = getInfoFeatureDBpedia1(idDBpedia);
                                    listPromise.push(dbPediaQuery.query(query));
                                    query = getInfoFeatureDBpedia2(idDBpedia);
                                    listPromise.push(dbPediaQuery.query(query));
                                } else {
                                    listPromise.push(Promise.resolve(null));
                                    listPromise.push(Promise.resolve(null));
                                    listPromise.push(Promise.resolve(null));
                                }
                                break;
                            }
                            case 'wikidata':
                                // TODO
                                break;
                            case 'esDBpedia':
                                // TODO
                                break;
                            case 'dbpedia':
                                // TODO
                                break;
                            default:
                                break;
                        }
                        let [osmResults, wikidataResult, esDBpediaResult, dbpedia1, dbpedia2] = await Promise.all(listPromise);
                        if (osmResults != null && osmResults.elements != null && osmResults.elements.length > 0) {
                            const elementOSM = new ElementOSM(osmResults.elements[0]);
                            const ifc = new InfoFeatureCache('osm', elementOSM.id, elementOSM);
                            feature.addInfoFeatureCache(ifc);
                        } else {
                            if (!feature.providers.includes('osm')) {
                                const ifc = new InfoFeatureCache('osm', idOSM, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                        if (wikidataResult != null) {
                            let wdR = mergeResults(sparqlResponse2Json(wikidataResult)).pop();
                            if (wdR != undefined) {
                                const fWd = new FeatureWikidata(idWikidata, wdR);
                                await fWd.initialize();
                                const ifc = new InfoFeatureCache('wikidata', fWd.id, fWd);
                                feature.addInfoFeatureCache(ifc);
                            } else {
                                const ifc = new InfoFeatureCache('wikidata', idWikidata, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        } else {
                            if (!feature.providers.includes('wikidata')) {
                                const ifc = new InfoFeatureCache('wikidata', idWikidata, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }

                        if (esDBpediaResult != null) {
                            esDBpediaResult = mergeResults(sparqlResponse2Json(esDBpediaResult));
                            if (esDBpediaResult.length > 0) {
                                const ifc = new InfoFeatureCache('esDBpedia', idDBpedia, new FeatureDBpedia(idDBpedia, esDBpediaResult.pop()));
                                feature.addInfoFeatureCache(ifc);
                            } else {
                                const ifc = new InfoFeatureCache('esDBpedia', idDBpedia, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        } else {
                            if (!feature.providers.includes('esDBpedia')) {
                                const ifc = new InfoFeatureCache('esDBpedia', idDBpedia, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }

                        if (dbpedia1 != null) {
                            dbpedia1 = sparqlResponse2Json(dbpedia1);
                        }
                        if (dbpedia2 != null) {
                            dbpedia2 = sparqlResponse2Json(dbpedia2);
                        }
                        const dbpedia = dbpedia1 != null && dbpedia2 != null ?
                            mergeResults(dbpedia1.concat(dbpedia2)) :
                            dbpedia1 != null ?
                                mergeResults(dbpedia1) :
                                dbpedia2 != null ?
                                    mergeResults(dbpedia2) :
                                    [];
                        if (dbpedia.length > 0) {
                            const ifc = new InfoFeatureCache('dbpedia', idDBpedia, new FeatureDBpedia(idDBpedia, dbpedia.pop()));
                            feature.addInfoFeatureCache(ifc);
                        } else {
                            if (!feature.providers.includes('dbpedia')) {
                                const ifc = new InfoFeatureCache('dbpedia', idDBpedia, null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        }
                    } else {
                        if (feature.providers.includes('wikidata') && !feature.providers.includes('jcyl')) {
                            // Compruebo si tengo que solicitar a JCyL
                            const fWididata = feature.infoFeature.find((element) => element.provider == 'wikidata');
                            if (fWididata.dataProvider != null && fWididata.dataProvider.bicJCyL != null) {
                                const query = queryBICJCyL(fWididata.dataProvider.bicJCyL);
                                const localQuery = new SPARQLQuery("http://127.0.0.1:8890/sparql");
                                const resp = await localQuery.query(query);
                                const bicJCyL = mergeResults(sparqlResponse2Json(resp)).pop();
                                if (bicJCyL != undefined && bicJCyL != null) {
                                    const fJCyL = new FeatureJCyL('chd:'.concat(bicJCyL['id'].split('/').pop()), bicJCyL)
                                    const ifc = new InfoFeatureCache('jcyl', fJCyL.id, fJCyL);
                                    feature.addInfoFeatureCache(ifc);
                                } else {
                                    const ifc = new InfoFeatureCache('jcyl', '', null);
                                    feature.addInfoFeatureCache(ifc);
                                }
                            } else {
                                const ifc = new InfoFeatureCache('jcyl', '', null);
                                feature.addInfoFeatureCache(ifc);
                            }
                        } else {
                            sigueBuscando = false;
                            if (update) {
                                updateFeatureCache(feature);
                            }
                            const out = [];
                            feature.infoFeature.forEach(async (infoFeature) => {
                                const dataProvider = infoFeature.dataProvider;
                                if (dataProvider != null) {
                                    switch (infoFeature.provider) {
                                        case 'osm':
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: dataProvider.toCHESTFeature(),
                                            });
                                            break;
                                        case 'wikidata':
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: dataProvider.toCHESTFeature(),
                                            });
                                            break;
                                        case 'esDBpedia':
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: dataProvider.toCHESTFeature(),
                                            });
                                            break;
                                        case 'dbpedia':
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: dataProvider.toCHESTFeature(),
                                            });
                                            break;
                                        case 'jcyl':
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: infoFeature.dataProvider.toCHESTFeature(),
                                            });
                                            break;
                                        default:
                                            out.push({
                                                provider: infoFeature.provider,
                                                data: infoFeature.dataProvider
                                            });
                                            break;
                                    }
                                }
                            });
                            logHttp(req, 200, 'getFeature', start);
                            res.send(out);
                        }
                    }
                }
            }
        } else {
            // El cliente no ha enviado ningún shortID o no es válido el que ha enviado
            logHttp(req, 400, 'getFeature', start);
            res.sendStatus(400);
        }

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
 * Edits a feature.
 * @async
 * @function editFeature
 * @param {Object} req - The request object.
 * @param {Object} res - The response object.
 * @returns {Promise<void>} - A Promise that resolves when the feature is edited.
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
