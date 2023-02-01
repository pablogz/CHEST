const FirebaseAdmin = require('firebase-admin');
const EmailValidator = require('email-validator');

const { getInfoUser, updateDocument, newDocument, DOCUMENT_INFO } = require('../../util/bd');
const { getTokenAuth, generateUid } = require('../../util/auxiliar');

async function getUser(req, res) {
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            res.send(JSON.stringify({
                                rol: (infoUser.rol === 0) ? 'admin' : (infoUser.rol === 1) ? 'teacher' : 'user',
                                id: infoUser.id,
                                firstname: infoUser.firstname,
                                lastname: infoUser.lastname
                            }));
                        } else {
                            res.sendStatus(404);
                        }
                    });
                } else {
                    res.status(403).send('You have to verify your email!');
                }
            })
            .catch((error) => {
                console.error(error.message);
                res.sendStatus(401);
            });
    } catch (error) {
        res.status(500).send(error.message);
    }
}

async function editUser(req, res) {
    /*
curl -X PUT -H "Authorization: Bearer 1" -H "Content-Type: application/json" -d "{\"firstname\": \"Pablo\"}" "localhost:11110/users/user"
curl -X PUT -H "Authorization: Bearer 2" -H "Content-Type: application/json" -d "{\"firstname\": \"Pablo\", \"email\": \"pablogz@gsic.uva.es\"}" "localhost:11110/users/user"
     */
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

                                    // if (!err) {
                                    //     err = err || (await updateDocument(
                                    //         uid,
                                    //         DOCUMENT_INFO,
                                    //         {
                                    //             firstname: infoUser.firstname,
                                    //             lastname: lastname,
                                    //             lastUpdate: Date.now()
                                    //         }
                                    //     ) === null);
                                    // }
                                    if (err) {
                                        res.status(500).send('Update error');
                                    } else {
                                        res.sendStatus(200);
                                    }
                                } else {
                                    res.sendStatus(400);
                                }
                            } else {
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
                                    res.sendStatus(201);
                                } else {
                                    res.sendStatus(400);
                                }
                            } else {
                                res.sendStatus(400);
                            }
                        }
                    });
                } else {
                    res.status(403).send('You have to verify your email!');
                }
            })
            .catch((error) => {
                console.error(error);
                res.sendStatus(401);
            });
    } catch (error) {
        res.status(500).send(error.message);
    }
}

module.exports = {
    getUser,
    editUser,
}