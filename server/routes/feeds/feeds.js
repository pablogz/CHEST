const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const { logHttp, getTokenAuth, generateUid } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { getInfoUser, getFeedsUser, getFeed } = require('../../util/bd');
const { Feeder, Feed, FeedSubscriptor } = require('../../util/pojos/feed');
const { InfoUser, FeedsUser } = require('../../util/pojos/user')

async function listFeeds(req, res) {
    const start = Date.now();
    try {
        // FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
        //     .then(async dToken => {
        //         const { uid } = dToken;
        const uid = 'gOjTNGOA4AgiJtxPMBiVhPetFmD3';
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            // Creo al usuario con sus datos
                            const user = new InfoUser(infoUser);
                            // Recupero la lista de feeds
                            getFeedsUser(user.id).then(async feedsUserDocument => {
                                const feedsToClient = {};
                                let nFeeds = 0;
                                const feedsUser = new FeedsUser(feedsUserDocument);

                                if (user.roles.includes('TEACHER')) {
                                    // Compruebo si ha creado algún canal. Si es así lo agrego para enviárselo al cliente
                                    feedsToClient['owner'] = feedsUser.owner;
                                    nFeeds += feedsUser.owner.length;
                                }

                                if (feedsUser.subscribed.length > 0) {
                                    // Compruebo si está subscrito a algún canal. Si es así, recupero la información del canal para enviárselo al cliente
                                    const promesas = [];
                                    const feedsSubscriptor = [];
                                    for (let i = 0, tama = feedsUser.subscribed.length; i < tama; i++) {
                                        const feedSubscriptor = new FeedSubscriptor(feedsUser.subscribed.at(i));
                                        feedsSubscriptor.push(feedSubscriptor);
                                        promesas.push(getFeed(feedSubscriptor.idOwner, feedSubscriptor.idFeed));
                                    }

                                    const arrayFeeds = await Promise.all(promesas);
                                    feedsToClient.subscribed = [];
                                    for (let i = 0, tama = arrayFeeds.length; i < tama; i++) {
                                        const feed = arrayFeeds.at(i);
                                        const feedSubscriptor = feedsSubscriptor.at(i);
                                        const f = feed.toSubscriber();
                                        f.date = feedSubscriptor.date;
                                        f.owner = {id: feedSubscriptor.idOwner};
                                        f.answers = feedSubscriptor.answers;
                                        feedsToClient.subscribed.push(f);
                                        nFeeds += 1;
                                    }
                                }

                                if (nFeeds > 0) {
                                    winston.info(Mustache.render('listFeeds || idUser: {{{idUser}}} - nFeeds: {{{nFeeds}}} || {{{time}}}', {
                                        idUser: user.id,
                                        nFeeds: nFeeds,
                                        time: Date.now() - start
                                    }));
                                    logHttp(req, 200, 'listFeeds', start);
                                    res.send(JSON.stringify(feedsToClient));
                                } else {
                                    winston.info(Mustache.render('listFeeds || empty || {{{time}}}', { time: Date.now() - start }));
                                    logHttp(req, 204, 'listFeeds', start);
                                    res.sendStatus(204);
                                }
                            });
                        } else {
                            // El usuario no está en la base de datos
                            logHttp(req, 404, 'listFeeds', start);
                            res.sendStatus(404);
                        }
                    });
                } else {
                    logHttp(req, 401, 'listFeeds', start);
                    res.sendStatus(401);
                }
            // });
    } catch (error) {
        winston.error(Mustache.render(
            'listFeeds || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'listFeeds', start);
        res.sendStatus(500);
    }
}

async function newFeed(req, res) {
    const start = Date.now();
    try {
        // (1) Obtener el identificador del usuario y comprobar que puede crear canales (es profe)
        // (2) Comprobar los datos, crear un identificador para el itinerario y almacenar LOD
        // (3) Responder al usaurio con un 201 indicando el identificador único en el Location

        // (1)
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null && infoUser.rol.includes('TEACHER')) {
                            // (2)
                            if (req.body) {
                                let { feeder, label, comment, password } = req.body;
                                if (typeof feeder == 'object' && feeder['id'] != undefined && feeder['alias'] != undefined) {
                                    feeder = new Feeder(feeder['id'], feeder['alias']);
                                }
                                if (typeof label === 'object') {
                                    label = [label];
                                }
                                if (typeof comment === 'object') {
                                    comment = [comment];
                                }


                                if (typeof feeder == Feeder && feeder.id == `http://moult.gsic.uva.es/data/${uid}` && Array.isArray(label) && Array.isArray(comment)) {
                                    const feed = new Feed({ id: await generateUid(), feeder: feeder });
                                    feed.setLabels(label);
                                    feed.setComments(comment);
                                    feed.password = password;
                                } else {
                                    logHttp(req, 400, 'newFeed', start);
                                    res.sendStatus(400);
                                }
                            }
                        } else {
                            winston.info(Mustache.render(
                                'newFeed || 401 || {{{time}}}',
                                {
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 401, 'newFeed', start);
                            res.sendStatus(401);
                        }
                    });
                } else {
                    winston.info(Mustache.render(
                        'newFeed || 403 - Verify email || {{{time}}}',
                        {
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 403, 'newFeed', start);
                    res.status(403).send('You have to verify your email!');
                }
            })
    } catch (error) {
        winston.error(Mustache.render(
            'newFeed || 500 || {{{time}}}',
            {
                time: Date.now() - start
            }
        ));
        res.sendStatus(500);
    }
}

module.exports = {
    listFeeds,
    newFeed,
}