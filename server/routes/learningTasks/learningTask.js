const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { options4Request, mergeResults, sparqlResponse2Json, getTokenAuth } = require('../../util/auxiliar');
const { isAuthor, taskInIt0, taskInIt1, getInfoTask, checkInfo, deleteInfoPoi, addInfoPoi, deleteObject } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');

/**
 *
 * @param {*} req
 * @param {*} res
 */
function getTask(req, res) {
    const idTask = Mustache.render('http://chest.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
    try {
        const options = options4Request(getInfoTask(idTask));
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
                const task = mergeResults(sparqlResponse2Json(json), 'task');
                if (!task.length) {
                    res.sendStatus(404);
                } else {
                    res.send(JSON.stringify(task.pop()))
                }
            });
    } catch (error) {
        res.status(500).send(error);
    }
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function editTask(req, res) {
    const idTask = Mustache.render('http://chest.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            let { body } = req;
                            if (body && body.body) {
                                body = body.body;
                                let options = options4Request(isAuthor(idTask, infoUser.id));
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
                                                options = options4Request(checkInfo(idTask, remove));
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
                                                            //TODO tengo que controlar cuando han finalizado las promesas
                                                            const requestsDelete = deleteInfoPoi(idTask, remove);
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
                                                            const requestsAdd = addInfoPoi(idTask, add);
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
                                                            res.sendStatus(202);
                                                        } else {
                                                            res.sendStatus(400);
                                                        }
                                                    });
                                            } catch (error) {
                                                res.sendStatus(400);
                                            }
                                        } else {
                                            res.status(401).send('User is not the author of the POI');
                                        }
                                    });

                            } else {
                                res.sendStatus(400);
                            }
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

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function deleteTask(req, res) {
    const idTask = Mustache.render('http://chest.gsic.uva.es/data/{{{task}}}', { task: req.params.task });
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol < 2) {
                            let options = options4Request(isAuthor(idTask, infoUser.id));
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
                                        options = options4Request(taskInIt0(idTask));
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
                                                    options = options4Request(taskInIt1(idTask));
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
                                                                options = options4Request(deleteObject(idTask), true);
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
                                                                res.status(401).send('This task has associated itineraries');
                                                            }
                                                        });
                                                } else {
                                                    res.status(401).send('This task has associated itineraries');
                                                }
                                            });
                                    } else {
                                        res.status(401).send('User is not the author of the task');
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
        res.status(500).send(error.menssage);
    }
}

module.exports = {
    getTask,
    editTask,
    deleteTask,
};
