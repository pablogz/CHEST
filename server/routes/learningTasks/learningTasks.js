const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { urlServer } = require('../../util/config');
const { options4Request, sparqlResponse2Json, mergeResults, generateUid, getTokenAuth } = require('../../util/auxiliar');
const { getTasksPoi, insertTask } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
//const { json } = require('express');

/**
 * Required query: north, south, west, east, group
 * Optional query: idStudent
 * @param {*} req
 * @param {*} res
 */
async function getTasks(req, res) {
    try {
        const { idStudent } = req.query;
        if (req.query.poi === undefined) {
            res.sendStatus(400);
        } else {
            //const poi = Mustache.render('http://chest.gsic.uva.es/data/{{{poi}}}', { poi: req.query.poi });
            const poi = req.query.poi;

            //Consulto al punto SPARQL solo por las tareas asociadas al POI indicado por el cliente
            const options = options4Request(getTasksPoi(poi));
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
                        res.send(JSON.stringify(tasks));
                    } else {
                        res.sendStatus(404);
                    }
                })
                .catch(error => {
                    console.error(error);
                    res.sendStatus(500);
                });
        }
    } catch (error) {
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
curl -X POST --user pablo:pablo -H "Content-Type: application/json" -d "{\"aT\": \"photo\", \"inSpace\": \"physical\", \"comment\": [{\"value\": \"Hi!\", \"lang\": \"en\"}, {\"value\": \"Hola caracola\", \"lang\": \"es\"}], \"label\": [{\"value\":\"Título punto\", \"lang\":\"es\"}], \"hasPoi\": \"http://chest.gsic.uva.es/data/Ttulo_punto\"}" "localhost:11110/tasks"
    */
    const needParameters = Mustache.render(
        'Mandatory parameters in the request body are: aT[text/mcq/tf/photo/multiplePhotos/video/photoText/videoText/multiplePhotosText] (answerType); inSpace[virtual/physical] ; comment[string]; hasPoi[uriPoi]\nOptional parameters: image[{image: url, liense: url}], label[string]',
        { urlServer: urlServer });
    try {
        const { body } = req;
        if (body) {
            if (body.aT && body.inSpace && body.comment && body.hasPoi) {
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
                                        hasPoi: body.hasPoi
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
                                                    if (body.singleSelection) {
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
                                            if (body.correct) {
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
                                            res.location(idTask).sendStatus(201);
                                        } else {
                                            res.sendStatus(500);
                                        }
                                    });
                                } else {
                                    res.sendStatus(401);
                                }
                            }).catch(error => {
                                console.error(error);
                                res.sendStatus(500);
                            });
                        } else {
                            res.status(403).send('You have to verify your email!');
                        }
                    })
                    .catch((error) => {
                        console.error(error);
                        res.sendStatus(401);
                    });
            } else {
                res.status(400).send(needParameters);
            }
        } else {
            res.status(400).send(needParameters);
        }
    } catch (error) {
        res.status(400).send(Mustache.render('{{{error}}}\n{{{parameteres}}}', { error: error.menssage, parameters: needParameters }));
    }
}



module.exports = {
    getTasks,
    newTask,
};
