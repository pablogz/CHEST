const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../../util/winston');
const { logHttp, shortId2Id, getTokenAuth } = require('../../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../../util/pojos/user');
const {
    getInfoUser, getFeedsUser, getInfoSubscriber, getAnswersDB } = require('../../../../util/bd');
const { FeedSubscriber } = require('../../../../util/pojos/feed');

async function objAnswer(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    // Comparo el uid con el identificador del usuario del canal
                    let { feed, subscriber, answer } = req.params;
                    feed = shortId2Id(feed);
                    if (feed !== null) {
                        if (uid === subscriber) {
                            // Si es el mismo es el propio usuario que está solicitando su respuesta
                            const feeds = new FeedsUser(await getFeedsUser(uid));
                            const index = feeds.subscribed.findIndex(f => {
                                return f.idFeed === feed;
                            });
                            if (index > -1) {
                                const feedSubscriber = new FeedSubscriber(feeds.subscribed.at(index));
                                if (feedSubscriber.answers === undefined || feedSubscriber.answers.length === 0) {
                                    logHttp(req, 404, 'objAnswer', start);
                                    res.sendStatus(404);
                                } else {
                                    const answers = await getAnswersDB(uid);
                                    if (answers !== null && answers !== undefined && Array.isArray(answers) && answers.length > 0) {
                                        let out = null;
                                        answers.forEach(a => {
                                            if (feedSubscriber.answers.includes(a.id) && a.id === answer) {
                                                out = a;
                                            }
                                        });
                                        if (out !== null) {
                                            winston.info(Mustache.render('objAnswer || uid: {{{uid}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feed,
                                                    answer: answer,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 200, 'objAnswer', start);
                                            res.send(JSON.stringify(out));
                                        } else {
                                            logHttp(req, 404, 'objAnswer', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        logHttp(req, 404, 'objAnswer', start);
                                        res.sendStatus(404);
                                    }
                                }
                            } else {
                                logHttp(req, 404, 'objAnswer', start);
                                res.sendStatus(404);
                            }
                        } else {
                            // También puede pasar que su profesor esté solicitando la respuesta
                            const teacher = new InfoUser(await getInfoUser(uid));
                            if (teacher.isTeacher) {
                                const feedsUser = new FeedsUser(await getFeedsUser(uid));
                                const indexFeed = feedsUser.owner.findIndex(f => {
                                    return f.id === feed;
                                });
                                if (indexFeed > -1) {
                                    if (feedsUser.owner.at(indexFeed).subscribers.includes(subscriber)) {
                                        const promesas = [];
                                        promesas.push(getAnswersDB(subscriber));
                                        promesas.push(getInfoSubscriber(subscriber, feed, false));
                                        const arrayDatos = await Promise.all(promesas);
                                        if (arrayDatos.at(0) !== null && arrayDatos.at(0) !== undefined && Array.isArray(arrayDatos.at(0)) && arrayDatos.at(0).length > 0) {
                                            let out = null;
                                            arrayDatos.at(0).forEach(a => {
                                                if (arrayDatos.at(1).answers.includes(a.id) && a.id === answer) {
                                                    out = a;
                                                }
                                            });
                                            if (out !== null) {
                                                winston.info(Mustache.render('objAnswer || uid: {{{uid}}} subscriber: {{{subscriber}}} feedId: {{{feedId}}} - answer: {{{answer}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        subscriber: subscriber,
                                                        feedId: feed,
                                                        answer: answer,
                                                        time: Date.now() - start
                                                    }));
                                                logHttp(req, 200, 'objAnswer', start);
                                                res.send(JSON.stringify(out));
                                            } else {
                                                logHttp(req, 404, 'objAnswer', start);
                                                res.sendStatus(404);
                                            }
                                        } else {
                                            logHttp(req, 404, 'listAnswers', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        logHttp(req, 400, 'listAnswers', start);
                                        res.sendStatus(400);
                                    }
                                } else {
                                    logHttp(req, 401, 'listAnswers', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                logHttp(req, 401, 'objAnswer', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'objAnswer', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'objAnswer', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'objAnswer || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'objAnswer', start);
        res.sendStatus(500);
    }
}

async function updateAnswer(req, res) {
    res.sendStatus(418);
}

async function byeAnswer(req, res) {
    res.sendStatus(418);
}

module.exports = { objAnswer, updateAnswer, byeAnswer }