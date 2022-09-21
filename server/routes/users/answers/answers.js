const short = require('short-uuid');
const FirebaseAdmin = require('firebase-admin');

const { getTokenAuth } = require('../../../util/auxiliar');
const { checkExistenceAnswer, saveAnswer, getAnswersDB } = require('../../../util/bd');

async function getAnswers(req, res) {
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid, email_verified } = dToken;
                if (email_verified && uid !== '') {
                    const { allAnswers } = req.query;
                    const answers = await getAnswersDB(uid, allAnswers === 'true');
                    if (answers != null) {
                        if (answers.length > 0) {
                            res.send(answers);
                        } else {
                            res.sendStatus(204);
                        }
                    } else {
                        res.sendStatus(400);
                    }
                } else {
                    res.sendStatus(403);
                }
            }).catch(error => {
                console.log(error);
                res.sendStatus(400);
            });
    } catch (error) {
        res.sendStatus(500);
    }
}


/*
body: {
    idTask: chestd:adsf,
    idPoi: chestd:asfdsa,
    answer: 
        {timestamp: 123,
        answerType: mcq,
        answer: "fadsdas"},
    ]
}
*/
// curl -X POST --header "Content-Type: application/json" -d "{\"idPoi\": \"1\", \"idTask\": \"1\", \"answer\": {\"timestamp\": 123, \"answerType\": \"mcq\", \"answer\": \"fasdfsa\"}}" "127.0.0.1:11110/users/user/answers"
async function newAnswer(req, res) {
    try {
        const { body } = req;
        if (body) {
            if (body.idTask && body.idPoi && body.answer) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid, email_verified } = dToken;
                        if (email_verified && uid !== '') {
                            const existe = await checkExistenceAnswer(uid, body.idPoi, body.idTask);
                            if (!existe) {
                                const answerClient = body.answer;
                                //TODO check answer first!!
                                let validAnswer = false;
                                if (answerClient.answerType !== undefined &&
                                    typeof answerClient.answerType === 'string' &&
                                    answerClient.timestamp !== undefined &&
                                    typeof answerClient.timestamp === 'number' &&
                                    answerClient.answer !== undefined) {
                                    switch (answerClient.answerType) {
                                        case 'mcq':
                                        case 'multiplePhotos':
                                        case 'multiplePhotosText':
                                        case 'noAnswer':
                                        case 'photo':
                                        case 'photoText':
                                        case 'text':
                                        case 'tf':
                                        case 'video':
                                        case 'videoText':
                                            validAnswer = true;
                                            break;
                                        default:
                                            break;
                                    }
                                    if (validAnswer) {
                                        const r = await saveAnswer(uid, body.idPoi, body.idTask, short.generate(), answerClient);
                                        if (r.acknowledged && (r.modifiedCount == 1 || r.upsertedCount == 1)) {
                                            res.location(answerClient.id).sendStatus(201);
                                        } else {
                                            res.sendStatus(409);
                                        }
                                    } else {
                                        res.sendStatus(400);
                                    }
                                } else {
                                    res.sendStatus(400);
                                }
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