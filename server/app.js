const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const cors = require('cors');
const FirebaseAdmin = require('firebase-admin');


const config = require('./util/config');
const fileFirebaseAdmin = require('./util/chest-firebase.json');
const index = require('./routes/index');
const pois = require('./routes/poi/pois');
const poi = require('./routes/poi/poi');
const tasks = require('./routes/learningTasks/learningTasks');
const task = require('./routes/learningTasks/learningTask');
const user = require('./routes/users/user');

const app = express();

app.use(logger('dev'));
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));
app.disable('etag');

const rutas = {
    raiz: '/',
    pois: '/pois/',
    poi: '/pois/:poi',
    tasks: '/tasks',
    task: '/tasks/:task',
    users: '/users/',
    user: '/users/:user',
    answers: '/users/user/answers/',
    answer: '/users/user/answers/:answer',
    statusItineraries: '/users/user/statusitineraries/',
    statusItinerary: '/users/user/statusitineraries/:statusitinerary',
    reports: '/users/user/reports/',
    report: '/users/user/reports/:report',
    notifications: '/users/user/notifications/',
    notification: '/users/user/notifications/:notification',
    itineraries: '/itineraries/',
    itinerary: '/itineraries/:itinerary'
};

FirebaseAdmin.initializeApp({
    credential: FirebaseAdmin.credential.cert(fileFirebaseAdmin)
})

const error405 = (req, res) => res.sendStatus(405);

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
        origin: config.urlClient
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
    //POI
    .get(rutas.poi, cors({
        origin: '*'
    }), (req, res) => poi.getPOI(req, res))
    .put(rutas.poi, cors({
        origin: config.urlClient
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            poi.editPOI(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.poi, cors({
        origin: config.urlClient
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
        origin: config.urlClient
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
        origin: config.urlClient
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            task.editTask(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .delete(rutas.task, cors({
        origin: config.urlClient
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
        origin: config.urlClient
    }), (req, res) => req.headers.authorization ?
        user.getUser(req, res) :
        res.sendStatus(401))
    .put(rutas.user, cors({
        origin: config.urlClient
    }), (req, res) => req.headers.authorization ?
        req.is('application/json') ?
            user.editUser(req, res) :
            res.sendStatus(415) :
        res.sendStatus(401))
    .options(rutas.task, cors({
        origin: '*',
        methods: ['GET', 'PUT', 'OPTIONS']
    }), (req, res) => {
        res.sendStatus(204);
    })
    .all(rutas.task, cors({
        origin: '*'
    }), error405);

module.exports = app;
