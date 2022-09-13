const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { getTokenAuth } = require('../../../util/auxiliar');
const { checkExistenceAnswer } = require('../../../util/bd');

async function getAnswers(req, res) {
    res.sendStatus(200);
}


/*
body: {
    idTask: chestd:adsf,
    idPoi: chestd:asfdsa,
    response: 
        {timestamp: 123,
        answerType: mcq,
        value: "fadsdas"},
    ]
}
*/

async function newAnswer(req, res) {
    try {
        const { body } = req;
        if (body) {
            if (body.idTask && body.idPoi && body.response) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid, email_verified } = dToken;
                        if (email_verified && uid !== '') {
                            const existe = await checkExistenceAnswer(body.idPoi, body.idTask);
                            if (!existe) {
                                res.sendStatus(200);
                            } else {
                                res.sendStatus(400);
                            }
                        } else {
                            res.sendStatus(403);
                        }
                    }).catch(error => {
                        console.log(error);
                        res.sendStatus(500);
                    });
            } else {
                res.sendStatus(400);
            }
        } else {
            res.sendStatus(400);
        }
    } catch (error) {
        res.sendStatus(500);
    }
}

module.exports = {
    getAnswers,
    newAnswer,
}