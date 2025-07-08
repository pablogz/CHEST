const Mustache = require('mustache');
const FirebaseAdmin = require('firebase-admin');

const { logHttp, getTokenAuth, shortId2Id } = require('../../util/auxiliar');
const winston = require('../../util/winston');
const { InfoUser, FeedsUser } = require('../../util/pojos/user');
const { getInfoUser, getFeedsUser, getFeed } = require('../../util/bd');
const { Feed, FeedSubscriptor } = require('../../util/pojos/feed');


async function objFeed(req, res) {
    const start = Date.now();
    try {
        // Recupero el identificador del usuario
        FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async dToken => {
                const { uid } = dToken;
                if (uid !== '') {
                    const user = new InfoUser(await getInfoUser(uid));
                    // Recupero la lista de canales a los que está subscrito o es propietario
                    const feedsUser = new FeedsUser(await getFeedsUser(user.id))
                    // Compruebo si el cliente ha enviado un identificador como parámetro de la consulta
                    const shortIdFeed = req.params.feed;
                    const idFeed = shortId2Id(shortIdFeed);
                    if (idFeed !== null) {
                        // Compruebo si el id del canal solicitado por el usuario está entre los suyos
                        let out = null;
                        feedsUser.owner.forEach(feed => {
                            feed = new Feed(feed);
                            if (feed.id === idFeed) {
                                out = feed.toMap();
                            }
                        });
                        if (out !== null) {
                            winston.info(Mustache.render('objFeed || idUser: {{{idUser}}} - feed: {{{feed}}} || {{{time}}}', {
                                idUser: user.id,
                                feed: out.id,
                                time: Date.now() - start
                            }));
                            logHttp(req, 200, 'objFeed', start);
                            res.send(JSON.stringify(out));
                        } else {
                            // Compruebo si es uno en los que está subscrito
                            feedsUser.subscribed.forEach(feedSubscriptor => {
                                feedSubscriptor = new FeedSubscriptor(feedSubscriptor);
                                if (feedSubscriptor.idFeed === idFeed) {
                                    out = feedSubscriptor;
                                }
                            });
                            if (out !== null) {
                                // Me falta recuperar el resto de información del canal
                                const feed = await getFeed(out.idOwner, out.idFeed);
                                if (typeof feed === Feed) {
                                    out = Object.assign({ id: out.idFeed, date: out.date }, feed.toSubscriber());
                                    winston.info(Mustache.render('objFeed || idUser: {{{idUser}}} - feed: {{{feed}}} || {{{time}}}', {
                                        idUser: user.id,
                                        feed: out.id,
                                        time: Date.now() - start
                                    }));
                                    logHttp(req, 200, 'objFeed', start);
                                    res.send(JSON.stringify(out));
                                } else {
                                    logHttp(req, 400, 'objFeed', start);
                                    res.sendStatus(400);
                                }
                            } else {
                                logHttp(req, 400, 'objFeed', start);
                                res.sendStatus(400);
                            }
                        }
                    } else {
                        logHttp(req, 400, 'objFeed', start);
                        res.sendStatus(400);
                    }
                } else {
                    logHttp(req, 401, 'objFeed', start);
                    res.sendStatus(401);
                }
            });
    } catch (error) {
        winston.error(Mustache.render(
            'objFeed || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'objFeed', start);
        res.sendStatus(500);
    }

}

async function updateFeed(req, res) {
    // Recupero el identificador del usuario
    // Compruebo los datos enviados por el cliente
    // Compruebo la lista de los canales que son de su propiedad
    // Actualizo (BBDD) los valores indicados por el cliente
}

async function byeFeed(req, res) {
    // Recupero el identificador del usuario
    // Compruebo si el cliente ha enviado un identificador como parámetro de la consulta
    // Recupero la lista de canales que son propiedad del cliente
    // Si es suyo lo elimino
}

module.exports = { objFeed, updateFeed, byeFeed }