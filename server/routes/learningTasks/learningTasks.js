const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../util/winston');
const { urlServer } = require('../../util/config');
const { options4Request, sparqlResponse2Json, mergeResults, generateUid, getTokenAuth, logHttp, rebuildURI, shortId2Id } = require('../../util/auxiliar');
const { getTasksFeature, insertTask } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
//const { json } = require('express');

/**
 * Required query: north, south, west, east, group
 * Optional query: idStudent
 * @param {*} req
 * @param {*} res
 */
async function getTasks(req, res) {
    const start = Date.now();
    try {
        if (req.query.feature === undefined /*|| req.query.provider === undefined*/) {
            winston.info(Mustache.render(
                'getTasks || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'getTasks', start);
            res.sendStatus(400);
        } else {
            //const poi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: req.query.poi });
            // const provider = req.query.provider;
            // const feature = rebuildURI(req.params.feature, provider);
            const feature = shortId2Id(req.query.feature);
            if (feature !== null) {
                //Consulto al punto SPARQL solo por las tareas asociadas al POI indicado por el cliente
                const options = options4Request(getTasksFeature(feature));
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
                        const tasks = mergeResults(sparqlResponse2Json(json), 'task');
                        if (tasks.length > 0) {
                            const out = JSON.stringify(tasks);
                            winston.info(Mustache.render(
                                'getTasks || {{{feature}}} || {{{out}}} || {{{time}}}',
                                {
                                    feature: feature,
                                    out: out,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 200, 'getTasks', start);
                            res.send(out);
                        } else {
                            winston.info(Mustache.render(
                                'getTasks || {{{feature}}} || {{{time}}}',
                                {
                                    feature: feature,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 204, 'getTasks', start);
                            res.sendStatus(204);
                        }
                    })
                    .catch(error => {
                        winston.info(Mustache.render(
                            'getTasks || {{{poi}}} || {{{error}}} || {{{time}}}',
                            {
                                feature: feature,
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 500, 'getTasks', start);
                        console.error(error);
                        res.sendStatus(500);
                    });
            } else {
                winston.info(Mustache.render(
                    'getTasks || {{{error}}} || {{{time}}}',
                    {
                        error: "error id feature",
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'getTasks', start);
                res.status(400).send(Mustache.render(
                    '{{{error}}}\nEx. {{{urlServer}}}/tasks?poi=exPoi',
                    { error: "error id feature", urlServer: urlServer }));
            }
        }
    } catch (error) {
        winston.info(Mustache.render(
            'getTasks || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 400, 'getTasks', start);
        res.status(400).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/tasks?poi=exPoi',
            { error: error, urlServer: urlServer }));
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function newTask(req, res) {
    /*
curl -X POST --user pablo:pablo -H "Content-Type: application/json" -d "{\"aT\": \"photo\", \"inSpace\": \"physical\", \"comment\": [{\"value\": \"Hi!\", \"lang\": \"en\"}, {\"value\": \"Hola caracola\", \"lang\": \"es\"}], \"label\": [{\"value\":\"Título punto\", \"lang\":\"es\"}], \"hasPoi\": \"http://chest.gsic.uva.es/data/tp\"}" "localhost:11110/tasks?feature=http://chest.gsic.uva.es/data/tp"
    */
    const needParameters = Mustache.render(
        'Mandatory parameters in the request body are: aT[text/mcq/tf/photo/multiplePhotos/video/photoText/videoText/multiplePhotosText] (answerType); inSpace[virtual/physical] ; comment[string]; hasFeature[uriFeature]\nOptional parameters: image[{image: url, liense: url}], label[string]',
        { urlServer: urlServer });
    const start = Date.now();
    try {
        const feature = req.query.feature;
        const { body } = req;
        if (body) {
            if (body.aT && body.inSpace && body.comment && feature) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid, email_verified } = dToken;
                        if (email_verified && uid !== '') {
                            getInfoUser(uid).then(async infoUser => {
                                if (infoUser !== null && infoUser.rol < 2) {
                                    const idTask = await generateUid();
                                    //Inserto la tarea de aprendizaje
                                    const p4R = {
                                        id: idTask,
                                        author: infoUser.id,
                                        aT: body.aT,
                                        inSpace: body.inSpace,
                                        comment: body.comment,
                                        hasFeature: feature
                                    };
                                    //TODO necesito comprobar si vienen parámetros adicionales
                                    if (body.label) {
                                        p4R.label = body.label;
                                    }
                                    if (body.image) {
                                        p4R.image = body.image;
                                    }
                                    switch (p4R.aT) {
                                        case 'mcq':
                                            if (body.distractors) {
                                                p4R.distractors = body.distractors;
                                                if (body.correct) {
                                                    p4R.correct = body.correct;
                                                    if (body["singleSelection"] != undefined) {
                                                        p4R.singleSelection = body.singleSelection;
                                                    } else {
                                                        throw new Error('MCQ without singleSelection');
                                                    }
                                                }
                                            } else {
                                                throw new Error('MCQ without distractors');
                                            }
                                            break;
                                        case 'tf':
                                            if (body.correct != undefined) {
                                                p4R.correct = body.correct;
                                            }
                                            break;
                                        default:
                                            break;
                                    }
                                    const requests = insertTask(p4R);
                                    const promises = [];
                                    requests.forEach(request => {
                                        const options = options4Request(request, true);
                                        promises.push(
                                            fetch(
                                                Mustache.render(
                                                    'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                    {
                                                        host: options.host,
                                                        port: options.port,
                                                        path: options.path
                                                    }),
                                                { headers: options.headers }
                                            )
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
                                                'newTask || {{{uid}}} || {{{idTask}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    idTask: idTask,
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 201, 'newTask', start);
                                            res.location(idTask).sendStatus(201);
                                        } else {
                                            winston.info(Mustache.render(
                                                'newTask || SPARQL-UPDATE ERROR || {{{time}}}',
                                                {
                                                    time: Date.now() - start
                                                }
                                            ));
                                            logHttp(req, 500, 'newTask', start);
                                            res.sendStatus(500);
                                        }
                                    });
                                } else {
                                    winston.info(Mustache.render(
                                        'newTask || uid || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 401, 'newTask', start);
                                    res.sendStatus(401);
                                }
                            }).catch(error => {
                                winston.info(Mustache.render(
                                    'newTask || {{{error}}} || {{{time}}}',
                                    {
                                        error: error,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 500, 'newTask', start);
                                res.sendStatus(500);
                            });
                        } else {
                            winston.info(Mustache.render(
                                'newTask || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 403, 'newTask', start);
                            res.status(403).send('You have to verify your email!');
                        }
                    })
                    .catch((error) => {
                        winston.info(Mustache.render(
                            'newTask || {{{error}}} || {{{time}}}',
                            {
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 401, 'newTask', start);
                        res.sendStatus(401);
                    });
            } else {
                winston.info(Mustache.render(
                    'newTask|| {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newTask', start);
                res.status(400).send(needParameters);
            }
        } else {
            winston.info(Mustache.render(
                'newTask || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newTask', start);
            res.status(400).send(needParameters);
        }
    } catch (error) {
        winston.info(Mustache.render(
            'newTask || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 400, 'newTask', start);
        res.status(400).send(Mustache.render('{{{error}}}\n{{{parameteres}}}', { error: error.menssage, parameters: needParameters }));
    }
}



module.exports = {
    getTasks,
    newTask,
};
