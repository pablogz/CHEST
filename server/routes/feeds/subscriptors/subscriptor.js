const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const winston = require('../../../util/winston');
const { logHttp, getTokenAuth, shortId2Id } = require('../../../util/auxiliar');
const { InfoUser, FeedsUser } = require('../../../util/pojos/user');
const { getInfoUser, getFeedsUser, getInfoSubscriptor } = require('../../../util/bd');
const { Feed } = require('../../../util/pojos/feed');

async function subscriptor(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const user = new InfoUser(await getInfoUser(uid));
                    const subscriptorId = req.params.subscriptor;
                    const feedId = shortId2Id(req.params.feed);
                    if (feedId !== null) {
                        if (user.id === subscriptorId) {
                            // El usuario está solicitando su propia información. Tengo que comprobar si está subscripto al canal. Si es así le envío su información.
                            const infoSubscriptor = getInfoSubscriptor(subscriptorId, feedId);
                            if (infoSubscriptor !== null) {
                                winston.info(Mustache.render('subscriptor || uid: {{{uid}}} feedId: {{{feedId}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        feedId: feedId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 200, 'subscriptor', start);
                                res.send(JSON.stringify(infoSubscriptor));
                            } else {
                                winston.info(Mustache.render('subscriptor || uid: {{{uid}}} feedId: {{{feedId}}} - no subscrito || {{{time}}}',
                                    {
                                        uid: uid,
                                        feedId: feedId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 404, 'subscriptor', start);
                                res.sendStatus(404);
                            }
                        } else {
                            if (user.isTeacher) {
                                // Es posible que el profesor esté solicitando información sobre uno de sus estudiantes. Voy a ver si el feed es de los que ha creado él y si uno de los estudiantes tiene el id subscriptorId. Si es así le envío la información del estudiante.
                                const feedsUser = FeedsUser(await getFeedsUser(user.id));
                                let index = feedsUser.owner.findIndex(f => {
                                    return f.id === feedId;
                                });
                                if (index > - 1) {
                                    const feed = Feed(feedsUser.owner.at(index));
                                    if (feed.subscriptors.includes(subscriptorId)) {
                                        // El profesor puede solicitar la información
                                        const infoSubscriptor = getInfoSubscriptor(subscriptorId, feedId);
                                        if (infoSubscriptor !== null) {
                                            winston.info(Mustache.render('subscriptor || uid: {{{uid}}} feedId: {{{feedId}}} || {{{time}}}',
                                                {
                                                    uid: uid,
                                                    feedId: feedId,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 200, 'subscriptor', start);
                                            res.send(JSON.stringify(infoSubscriptor));
                                        } else {
                                            winston.info(Mustache.render('subscriptor || Profe: {{{profe}}} estudiante: {{{uid}}} feedId: {{{feedId}}} - no subscrito || {{{time}}}',
                                                {
                                                    profe: user.id,
                                                    uid: subscriptorId,
                                                    feedId: feedId,
                                                    time: Date.now() - start
                                                }));
                                            logHttp(req, 404, 'subscriptor', start);
                                            res.sendStatus(404);
                                        }
                                    } else {
                                        winston.info(Mustache.render('subscriptor || Profesor {{{uid}}} solicita {{{subscriptorId}}} en {{{feed}}} - el estudiante no está subscrito || {{{time}}}',
                                            {
                                                uid: uid,
                                                subscriptorId: subscriptorId,
                                                feed: feedId,
                                                time: Date.now() - start
                                            }));
                                        logHttp(req, 404, 'subscriptor', start);
                                        res.sendStatus(404);
                                    }
                                } else {
                                    // El profe está intentando acceder a un estudiante de un canal que no ha creado él
                                    winston.info(Mustache.render('subscriptor || Profesor {{{uid}}} solicita {{{subscriptorId}}} en {{{feed}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            subscriptorId: subscriptorId,
                                            feed: feedId,
                                            time: Date.now() - start
                                        }));
                                    logHttp(req, 401, 'subscriptor', start);
                                    res.sendStatus(401);
                                }
                            } else {
                                // Un usuario sin privilegios está pidiendo la información de otro
                                winston.info(Mustache.render('subscriptor || {{{uid}}} solicita {{{subscriptorId}}} sin tener privilegios || {{{time}}}',
                                    {
                                        uid: uid,
                                        subscriptorId: subscriptorId,
                                        time: Date.now() - start
                                    }));
                                logHttp(req, 401, 'subscriptor', start);
                                res.sendStatus(401);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'subscriptor', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'subscriptor', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'subscriptor || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'subscriptor', start);
        res.sendStatus(500);
    }
}

async function newSubscriptor(req, res) {
    res.sendStatus(418);
}

async function byeSubscriptor(req, res) {
    res.sendStatus(418);
}

module.exports = { subscriptor, newSubscriptor, byeSubscriptor }