const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
// const logger = require('morgan');
const cors = require('cors');
const FirebaseAdmin = require('firebase-admin');
require('https').globalAgent.options.ca = require('ssl-root-cas').create();

const winston = require('./util/winston');

const config = require('./util/config');
const fileFirebaseAdmin = require('./util/chest-firebase.json');
const { cities } = require('./util/auxiliar');

const index = require('./routes/index');
const pois = require('./routes/poi/pois');
const poisLOD = require('./routes/poi/poisLOD');
const poi = require('./routes/poi/poi');
const tasks = require('./routes/learningTasks/learningTasks');
const task = require('./routes/learningTasks/learningTask');
const user = require('./routes/users/user');
const answers = require('./routes/users/answers/answers');
const answer = require('./routes/users/answers/answer');
const itineraries = require('./routes/itineraries/itineraries');
const itinerary = require('./routes/itineraries/itinerary');

const app = express();

// app.use(logger('dev'));
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.disable('etag');

const rutas = {
    raiz: '/',
    pois: '/pois/',
    poisLOD: '/pois/lod/',
    poi: '/pois/:poi',
    tasks: '/tasks',
    task: '/tasks/:task',
    users: '/users/',
    user: '/users/:user',
    answers: '/users/user/answers/',
    answer: '/users/user/answers/:answer',
    userItineraries: '/users/user/itineraries/',
    userStatusItinerary: '/users/user/itineraries/:itinerary/status',
    reports: '/users/user/reports/',
    report: '/users/user/reports/:report',
    notifications: '/users/user/notifications/',
    notification: '/users/user/notifications/:notification',
    itineraries: '/itineraries/',
    itinerary: '/itineraries/:itinerary',
    itineraryPois: 'itineraries/:itinerary/pois',
    itineraryPoi: 'itineraries/:itinerary/pois/:poi'
};

FirebaseAdmin.initializeApp({
    credential: FirebaseAdmin.credential.cert(fileFirebaseAdmin)
})

const error405 = (req, res) => {
    winston.http(`405 || Method Not Allowed - ${req.originalUrl} - ${req.method} - ${req.ip}`);
    res.sendStatus(405);
}

winston.info('START');

// TODO
const inicio = Date.now()
winston.info('Started request to recover cities');
cities().then(async () => {
    winston.info('Finished request. Time: ' + (Date.now() - inicio) + 'ms');
}
).finally(() => {
    app
        //Index
        .get(rutas.raiz, cors({
            origin: '*'
        }), (req, res) => index.getIndex(req, res))
        .options(rutas.raiz, cors({
            origin: '*',
            methods: ['GET', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        //POIs
        .all(rutas.raiz, cors({
            origin: '*'
        }), error405)
        .get(rutas.pois, cors({
            origin: '*'
        }), (req, res) => pois.getPOIs(req, res))
        .post(rutas.pois, cors({
            // origin: config.urlClient
            origin: '*',
            exposedHeaders: ['Location']
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                pois.newPOI(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .options(rutas.pois, cors({
            origin: '*',
            methods: ['GET', 'POST', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.pois, cors({
            origin: '*'
        }), error405)
        //POILOD
        .get(rutas.poisLOD, cors({
            origin: '*'
        }), (req, res) => poisLOD.getPOIsLOD(req, res))
        .options(rutas.poisLOD, cors({
            origin: '*',
            methods: ['GET', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.poisLOD, cors({
            origin: '*'
        }), error405)
        //POI
        .get(rutas.poi, cors({
            origin: '*'
        }), (req, res) => poi.getPOI(req, res))
        .put(rutas.poi, cors({
            // origin: config.urlClient
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                poi.editPOI(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .delete(rutas.poi, cors({
            // origin: config.urlClient
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            poi.deletePOI(req, res) : res.sendStatus(401))
        .options(rutas.poi, cors({
            origin: '*',
            methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        //Tasks
        .get(rutas.tasks, cors({
            origin: '*'
        }), (req, res) => tasks.getTasks(req, res))
        .post(rutas.tasks, cors({
            // origin: config.urlClient
            origin: '*',
            exposedHeaders: ['Location']
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                tasks.newTask(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .options(rutas.tasks, cors({
            origin: '*',
            methods: ['GET', 'POST', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.tasks, cors({
            origin: '*'
        }), error405)
        //Task
        .get(rutas.task, cors({
            origin: '*'
        }), (req, res) => task.getTask(req, res))
        .put(rutas.task, cors({
            // origin: config.urlClient
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                task.editTask(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .delete(rutas.task, cors({
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            task.deleteTask(req, res) : res.sendStatus(401))
        .options(rutas.task, cors({
            origin: '*',
            methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.task, cors({
            origin: '*'
        }), error405)
        //Users
        .all(rutas.task, cors({
            origin: '*'
        }), error405)
        //User
        .get(rutas.user, cors({
            // origin: config.urlClient
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            user.getUser(req, res) :
            res.sendStatus(401))
        .put(rutas.user, cors({
            //origin: config.urlClient
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                user.editUser(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .options(rutas.user, cors({
            origin: '*',
            methods: ['GET', 'PUT', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.user, cors({
            origin: '*'
        }), error405)
        // ANSWERS
        // .get(rutas.answers, cors({
        //     origin: '*'
        // }), (req, res) => req.headers.authorization ? answers.getAnswers(req, res) : res.sendStatus(401))
        .post(rutas.answers, cors({
            origin: '*',
            exposedHeaders: ['Location']
            // }), (req, res) =>  req.headers.authorization ? answers.newAnswer(req, res) : res.sendStatus(401))
        }), (req, res) => answers.newAnswer(req, res))
        .all(rutas.answers, cors({
            origin: '*'
        }), error405)
        // ANSWER
        // .get(rutas.answer, cors({
        //     origin: '*'
        // }), (req, res) => req.headers.authorization ?
        //     answer.getAnswer(req, res) :
        //     res.sendStatus(401))
        // .put(rutas.answer, cors({
        //     origin: '*'
        // }), (req, res) => req.headers.authorization ?
        //     req.is('application/json') ?
        //         answer.putAnswer(req, res) :
        //         res.sendStatus(415) :
        //     res.sendStatus(401))
        // .delete(rutas.answer, cors({
        //     origin: '*'
        // }), (req, res) => req.headers.authorization ?
        //     answer.deleteAnswer(req, res) : res.sendStatus(401))
        // .options(rutas.answer, cors({
        //     origin: '*',
        //     methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
        // }), (req, res) => {
        //     res.sendStatus(204);
        // })
        .all(rutas.answer, cors({
            origin: '*'
        }), error405)
        //ITINERARIES
        .get(rutas.itineraries, cors({
            origin: '*'
        }), (req, res) => itineraries.getItineariesServer(req, res))
        .post(rutas.itineraries, cors({
            origin: '*',
            exposedHeaders: ['Location']
        }), (req, res) => itineraries.newItineary(req, res))
        .options(rutas.itineraries, cors({
            origin: '*',
            methods: ['GET', 'POST', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.itineraries, cors({
            origin: '*'
        }), error405)
        //ITINERARY
        .get(rutas.itinerary, cors({
            origin: '*'
        }), (req, res) => itinerary.getItineraryServer(req, res))
        .put(rutas.itinerary, cors({
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            req.is('application/json') ?
                itinerary.updateItineraryServer(req, res) :
                res.sendStatus(415) :
            res.sendStatus(401))
        .delete(rutas.itinerary, cors({
            origin: '*'
        }), (req, res) => req.headers.authorization ?
            itinerary.deleteItineraryServer(req, res) : res.sendStatus(401))
        .options(rutas.itinerary, cors({
            origin: '*',
            methods: ['GET', 'PUT', 'DELETE', 'OPTIONS']
        }), (req, res) => {
            res.sendStatus(204);
        })
        .all(rutas.itinerary, cors({
            origin: '*'
        }), error405)
        ;
    winston.info("Server started");
});

module.exports = app;
