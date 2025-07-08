const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const { logHttp, getTokenAuth, generateUid } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { getInfoUser, getInfoFeed } = require('../../util/bd');
const { Feeder, Feed } = require('../../util/pojos/feed');
const { User } = require('../../util/pojos/user')

async function listFeeds(req, res) {
    const start = Date.now();
    try {
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    getInfoUser(uid).then(async infoUser => {
                        if (infoUser !== null) {
                            // Creo al usuario con sus datos
                            const user = new User(infoUser);
                            // Si es profe compruebo los canales que ha creado
                            const feedIds = [];
                            const feedsTeacherIds = [];
                            if (user.roles.includes('TEACHER')) {
                                if (Array.isArray(user.feeder)) {
                                    user.feeder.forEach(idFeed => {
                                        feedsTeacherIds.push(idFeed);
                                        feedIds.push(idFeed);
                                    });
                                }
                            }

                            // Agrego los identificadores de los canales en los que es subscriptor
                            if (Array.isArray(user.subscriptor)) {
                                user.subscriptor.forEach(idFeed => {
                                    feedIds.push(idFeed);
                                });
                            }
                            if (feedIds.length == 0) {
                                winston.info(Mustache.render('listFeeds || empty || {{{time}}}', { time: Date.now() - start }));
                                logHttp(req, 204, 'listFeeds', start);
                                res.sendStatus(204);
                            } else {
                                // Recupero de la base de datos la información de cada Feed.
                                const feeds = [];
                                const out = {};
                                out.feeder = [];
                                out.subscriptor = [];

                                feedIds.forEach(async feedId => {
                                    const isFeeder = feedIds.findIndex(ele => feedsTeacherIds.includes(ele.id)) == -1;
                                    const feed = new Feed(await getInfoFeed(feedId, isFeeder));
                                    feeds.push(feed);
                                    // Preparo la información para el usuario.
                                    if (isFeeder) {
                                        // (a) Si es feeder del feed tengo que enviar la información del Feed y la lista de subscriptores
                                        out.feeder.push(feed);
                                    } else {
                                        // (b) Si es subscriptor tengo que enviar la información del Feed y sus respuestas asociadas
                                        out.subscriptor.push(feed);
                                    }
                                });
                                // Envío la lista al cliente
                                winston.info(Mustache.render('listFeeds || idUser: {{{idUser}}} - nFeeds: {{{nFeeds}}} || {{{time}}}', {
                                    idUser: user.id,
                                    nFeeds: feeds.length,
                                    time: Date.now() - start
                                }));
                                logHttp(req, 200, 'listFeeds', start);
                                res.send(JSON.stringify(out));
                            }
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
            });
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
                                let { feeder, label, comment } = req.body;
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
                                    const feed = new Feed({id: await generateUid(), feeder: feeder});
                                    feed.setLabels(label);
                                    feed.setComments(comment);

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