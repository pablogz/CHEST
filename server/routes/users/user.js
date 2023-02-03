const FirebaseAdmin = require('firebase-admin');
const EmailValidator = require('email-validator');
const Mustache = require('mustache');

const { getInfoUser, updateDocument, newDocument, DOCUMENT_INFO } = require('../../util/bd');
const { getTokenAuth, generateUid, logHttp } = require('../../util/auxiliar');
const winston = require('../../util/winston');
async function getUser(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            winston.info(Mustache.render(
                                'getUser || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 200, 'getUser', start);
                            res.send(JSON.stringify({
                                rol: (infoUser.rol === 0) ? 'admin' : (infoUser.rol === 1) ? 'teacher' : 'user',
                                id: infoUser.id,
                                firstname: infoUser.firstname,
                                lastname: infoUser.lastname
                            }));
                        } else {
                            winston.info(Mustache.render(
                                'getUser || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 404, 'getUser', start);
                            res.sendStatus(404);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'getUser || {{{uid}}} || {{{time}}}',
                        {
                            uid: uid,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'getUser', start);
                    res.status(403).send('You have to verify your email!');
                }
            })
            .catch((error) => {
                winston.info(Mustache.render(
                    'getUser || {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'getUser', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'getUser || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getUser', start);
        res.status(500).send(error.message);
    }
}

async function editUser(req, res) {
    /*
curl -X PUT -H "Authorization: Bearer 1" -H "Content-Type: application/json" -d "{\"firstname\": \"Pablo\"}" "localhost:11110/users/user"
curl -X PUT -H "Authorization: Bearer 2" -H "Content-Type: application/json" -d "{\"firstname\": \"Pablo\", \"email\": \"pablogz@gsic.uva.es\"}" "localhost:11110/users/user"
     */
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) { //El usuario se encuentra registrado
                            if (email_verified) {
                                //El usuario puede modficar su nombre y apellido
                                if (req.body.firstname !== undefined && req.body.lastname !== undefined) {
                                    const { firstname, lastname } = req.body;
                                    let err = false;
                                    err = err || (await updateDocument(
                                        uid, //colection
                                        DOCUMENT_INFO, //document
                                        {
                                            id: infoUser.id,
                                            rol: infoUser.rol,
                                            firstname: firstname,
                                            lastname: lastname,
                                            lastUpdate: Date.now()
                                        }
                                    ) === null);
                                    if (err) {
                                        winston.info(Mustache.render(
                                            'editUser || editInfo || {{{uid}}} || {{{time}}}',
                                            {
                                                uid: uid,
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 500, 'editUser', start);
                                        res.status(500).send('Update error');
                                    } else {
                                        winston.info(Mustache.render(
                                            'editUser || editInfo || {{{uid}}} || {{{time}}}',
                                            {
                                                uid: uid,
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 200, 'editUser', start);
                                        res.sendStatus(200);
                                    }
                                } else {
                                    winston.info(Mustache.render(
                                        'editUser || editInfo || {{{uid}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 400, 'editUser', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                winston.info(Mustache.render(
                                    'editUser || editInfo || {{{uid}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 403, 'editUser', start);
                                res.status(403).send('You have to verify your email!');
                            }
                        } else {
                            //Nuevo usuario
                            const { email, firstname, lastname } = req.body;
                            if (email && EmailValidator.validate(email)) {
                                if (await newDocument(
                                    uid,
                                    {
                                        _id: DOCUMENT_INFO,
                                        id: await generateUid(),
                                        rol: 2,
                                        email: email,
                                        firstname: firstname,
                                        lastname: lastname,
                                        creation: Date.now()
                                    }) !== null) {
                                    winston.info(Mustache.render(
                                        'editUser || newUser || {{{uid}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 201, 'editUser', start);
                                    res.sendStatus(201);
                                } else {
                                    winston.info(Mustache.render(
                                        'editUser || newUser || {{{uid}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 400, 'editUser', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                winston.info(Mustache.render(
                                    'editUser || newUser || {{{uid}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 400, 'editUser', start);
                                res.sendStatus(400);
                            }
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'editUser || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'editUser', start);
                    res.sendStatus(403);
                }
            })
            .catch((error) => {
                winston.info(Mustache.render(
                    'editUser || {{{error}}} || {{{time}}}',
                    {
                        error: error,
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 401, 'editUser', start);
                res.sendStatus(401);
            });
    } catch (error) {
        winston.error(Mustache.render(
            'editUser || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'editUser', start);
        res.status(500).send(error.message);
    }
}

module.exports = {
    getUser,
    editUser,
}