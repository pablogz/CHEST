const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');
const short = require('short-uuid');

const { urlServer } = require('../../util/config');
const { options4Request, sparqlResponse2Json, mergeResults, cities, checkUID, getTokenAuth, logHttp } = require('../../util/auxiliar');
const { getLocationPOIs, getInfoPOIs, insertPoi } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
const winston = require('../../util/winston');

/**
 * Required query: north, south, west, east, group
 * Optional query: idStudent
 * @param {*} req
 * @param {*} res
 */
async function getPOIs(req, res) {
    const start = Date.now();
    try {
        let { group, north, south, west, east } = req.query;
        const { idStudent } = req.query;
        const bounds = { 'north': north, 'south': south, 'west': west, 'east': east };
        ['north', 'south', 'west', 'east'].forEach(l => {
            if (bounds[l] === undefined) {
                throw new Error('Need location (nort/south/west/east)');
            } else {
                bounds[l] = parseFloat(bounds[l]);
            }
        });
        //Compruebo que la posición enviada por el cliente "tenga sentido"
        if (bounds.north > 90 ||
            bounds.north <= -90 ||
            bounds.south >= 90 ||
            bounds.south < -90 ||
            bounds.north <= bounds.south ||
            bounds.east >= 180 ||
            bounds.east <= -180 ||
            bounds.west >= 180 ||
            bounds.west <= -180 ||
            bounds.east <= bounds.west
        ) {
            throw new Error('Location problem');
        }
        //Ya tengo la información en la variable bounds
        north = null; south = null; west = null; east = null;
        //Compruebo si el cliente quiere agrupar los POI
        if (group !== undefined) {
            group = group.toLowerCase();
            if (group === 'true' || group === 'false') {
                group = group === 'true';
            } else {
                throw new Error('Options for group: true/false');
            }
        } else {
            throw new Error('Need group (true/false)');
        }
        if (group) {
            //Consulto al punto SPARQL solo por la localización de los POI de la tesela indicada
            if (bounds.north - bounds.south > 10 || Math.abs(bounds.east - bounds.west) > 40) {
                throw new Error('The distance between the ends of the bound has to be less than 10 degrees');
            } else {
                const options = options4Request(getLocationPOIs(bounds));
                fetch(
                    Mustache.render(
                        'http://{{{host}}}:{{{port}}}{{{path}}}',
                        {
                            host: options.host,
                            port: options.port,
                            path: options.path
                        }),
                    { headers: options.headers })
                    .then(r => {
                        return r.json();
                    }).then(async json => {
                        const allPoi = mergeResults(sparqlResponse2Json(json), 'poi');
                        if (allPoi.length == 0) {
                            winston.info(Mustache.render(
                                'getPOIs || group || {{{north}}} || {{{east}}} || {{{south}}} || {{{west}}} || {{{time}}}',
                                {
                                    north: bounds.north,
                                    east: bounds.east,
                                    south: bounds.south,
                                    west: bounds.west,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 204, 'getPOIs', start);
                            res.sendStatus(204);
                        } else {
                            const validCities = [];
                            //Me quedo con las ciudades que se encuentren dentro de los límites indicados por el cliente
                            const ciudades = await cities();
                            ciudades.forEach(city => {
                                if (city.inside(bounds)) {
                                    validCities.push(city);
                                }
                            });
                            if (validCities.length == 0) {
                                const response = [];
                                response.push(
                                    {
                                        id: Mustache.render('{{{a}}}{{{b}}}', { a: short.generate(), b: short.generate() }),
                                        lat: (bounds.north - bounds.south) / 2 + bounds.south,
                                        lng: (bounds.east - bounds.west) / 2 + bounds.west,
                                        pois: allPoi.length
                                    }
                                );
                                res.send(JSON.stringify(response));
                            } else {
                                // let validCities2;
                                // //Limito el número máximo de puntos que se van a mostrar al usuario en TAMAMAX
                                // const TAMAMAX = 40;
                                // if (validCities.length > TAMAMAX) {
                                //     validCities2 = [];
                                //     //Doy prioridad a las ciudades que tengan población
                                //     validCities.forEach(city => {
                                //         if (city.hasPopulation) {
                                //             validCities2.push(city);
                                //         }
                                //     });
                                //     //Si ninguna tiene población agrego todas y me quedo con 20
                                //     if (!validCities2.length) {
                                //         const inicio = Math.floor(Math.random() * validCities.length - TAMAMAX);
                                //         validCities2 = validCities.splice(inicio, inicio + TAMAMAX);
                                //     } else {
                                //         // Las ciudades están ordenadas de mayor a menor población, 
                                //         // por lo que me quedo con las 20 más pobladas si la longitud del
                                //         // vector es mayor
                                //         if (validCities2.length > TAMAMAX) {
                                //             validCities2 = validCities2.splice(0, TAMAMAX);
                                //         }
                                //     }
                                // } else {
                                //     //Si no supero las TAMAMAX ciudades me quedo con todas
                                //     validCities2 = validCities.splice(0, validCities.length);
                                // }
                                // const response = [];
                                // //En la respuesta se indica la localización de la ciudad, el id y el número de POI
                                // validCities2.forEach(city => {
                                //     response.push({
                                //         id: city.id,
                                //         lat: parseFloat(city.latitude),
                                //         long: parseFloat(city.longitude),
                                //         pois: 0
                                //     });
                                // });
                                // // Compruebo la distancia de cada poi con cada ciudad 
                                // // e incremento el punto en el que se encuentre más cerca
                                // allPoi.forEach(poi => {
                                //     const nearCity = {
                                //         id: "ciudadFalsa",
                                //         distance: 999999999999999
                                //     }
                                //     validCities2.forEach(city => {
                                //         const d = city.distance(poi.lat, poi.lng);
                                //         if (d < nearCity.distance) {
                                //             nearCity.id = city.id;
                                //             nearCity.distance = d;
                                //         }
                                //     });
                                //     const i = response.findIndex(city => city.id == nearCity.id);
                                //     if (i !== undefined) {
                                //         response[i].pois += 1;
                                //     }
                                // });
                                // const finalResponse = [];
                                // response.forEach(resp => {
                                //     if (resp.pois > 0) {
                                //         finalResponse.push(resp);
                                //     }
                                // });
                                // res.send(JSON.stringify(finalResponse));
                                //Subdivido el mapa en teselas más pequeñas
                                const difLat = bounds.north - bounds.south;
                                const difLong = Math.abs(bounds.east - bounds.west);
                                const wLat = widthTesela(difLat);
                                const wLong = widthTesela(difLong);
                                let continueLat = true, continueLong = true;
                                let cLat = bounds.south, cLong = bounds.west;
                                const response = [];
                                while (continueLat) {
                                    let cLati = Math.min(cLat + wLat, bounds.north);
                                    while (continueLong) {
                                        let cLongi = Math.min(cLong + wLong, bounds.east);
                                        //Me quedo con las ciudades que están dentro de la nueva tesela
                                        let validCitiesTesela = [];
                                        validCities.forEach((city) => {
                                            if (city.inside({
                                                north: cLati,
                                                south: cLat,
                                                east: cLongi,
                                                west: cLong
                                            })) {
                                                validCitiesTesela.push(city);
                                            }
                                        });
                                        // Me quedo con los POI que se encuentren dentro de la nueva Tesela
                                        const poiTesela = [];
                                        allPoi.forEach((poi) => {
                                            if (poi.lat <= cLati && poi.lat >= cLat && poi.lng >= cLong && poi.lng <= cLongi) {
                                                poiTesela.push(poi);
                                            }
                                        });
                                        if (poiTesela.length > 0) {
                                            //La tesela tiene pois
                                            const responseTesela = [];
                                            if (validCitiesTesela.length > 0) {
                                                //La tesela tiene pois y ciudades
                                                //Agrupo los pois en las teselas
                                                validCitiesTesela.forEach(city => {
                                                    responseTesela.push({
                                                        id: city.id,
                                                        lat: parseFloat(city.latitude),
                                                        long: parseFloat(city.longitude),
                                                        pois: 0
                                                    });
                                                });
                                                let validCitiesTeselaFinal = [];
                                                if (validCitiesTesela.length > 20) {
                                                    //En primer lugar me quedo con las que tienen población
                                                    validCitiesTesela.forEach(city => {
                                                        if (city.hasPopulation) {
                                                            validCitiesTeselaFinal.push(city);
                                                        }
                                                    });
                                                    if (validCitiesTeselaFinal.length < 20) {
                                                        //Si no llega a 20 intento agregar las que no tienen población de manera aleatoria
                                                        validCitiesTesela = validCitiesTesela.sort(() => Math.random() > .5);
                                                        validCitiesTesela.forEach(city => {
                                                            if (validCitiesTeselaFinal.length < 20 && !city.hasPopulation) {
                                                                validCitiesTeselaFinal.push(city);
                                                            }
                                                        });
                                                    } else {
                                                        if (validCitiesTeselaFinal.length > 20) {
                                                            //Si hay más de 20 con población me quedo con las primera 20 (las más pobladas)
                                                            validCitiesTeselaFinal = validCitiesTeselaFinal.slice(0, 20);
                                                        }
                                                    }
                                                } else {
                                                    validCitiesTeselaFinal = validCities;
                                                }
                                                poiTesela.forEach(poi => {
                                                    const nearCity = {
                                                        id: "cF",
                                                        distance: 99999999999
                                                    };
                                                    validCitiesTeselaFinal.forEach(city => {
                                                        const d = city.distance(poi.lat, poi.lng);
                                                        if (d < nearCity.distance) {
                                                            nearCity.id = city.id;
                                                            nearCity.distance = d;
                                                        }
                                                    });
                                                    const i = responseTesela.findIndex(city => city.id == nearCity.id);
                                                    if (i !== undefined && i > -1) {
                                                        try {
                                                            responseTesela[i].pois += 1;
                                                        } catch (error) {
                                                            console.error(error);
                                                        }
                                                    }
                                                });
                                                responseTesela.forEach(resp => {
                                                    if (resp.pois > 0) {
                                                        response.push(resp);
                                                    }
                                                });
                                            } else {
                                                //Pongo todos los pois en el centro de la tesela
                                                response.push(
                                                    {
                                                        id: Mustache.render('{{{a}}}{{{b}}}', { a: short.generate(), b: short.generate() }),
                                                        lat: cLat + ((cLati - cLat) / 2),
                                                        lng: cLong + ((cLongi - cLong) / 2),
                                                        pois: poiTesela.length
                                                    }
                                                );
                                            }
                                        } else {
                                            //La tesela no tiene pois (no hago nada)
                                        }
                                        if (cLongi < bounds.east) {
                                            cLong = cLongi;
                                        } else {
                                            continueLong = false;
                                        }
                                    }
                                    if (cLati < bounds.north) {
                                        cLat = cLati;
                                        cLong = bounds.west;
                                        continueLong = true;
                                    } else {
                                        continueLat = false;
                                    }
                                }
                                const out = JSON.stringify(response);
                                winston.info(Mustache.render(
                                    'getPOIs || group || {{{north}}} || {{{east}}} || {{{south}}} || {{{west}}} || {{{out}}} || {{{time}}}',
                                    {
                                        north: bounds.north,
                                        east: bounds.east,
                                        south: bounds.south,
                                        west: bounds.west,
                                        out: out,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 200, 'getPOIs', start);
                                res.send(JSON.stringify(response));
                            }
                        }
                    })
                    .catch(error => {
                        winston.error(Mustache.render(
                            'getPOIs || group || {{{north}}} || {{{east}}} || {{{south}}} || {{{west}}} || {{{error}}} || {{{time}}}',
                            {
                                north: bounds.north,
                                east: bounds.east,
                                south: bounds.south,
                                west: bounds.west,
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 500, 'getPOIs', start);
                        res.sendStatus(500);
                    });
            }
        } else {
            if (bounds.north - bounds.south > 0.2 || Math.abs(bounds.east - bounds.west) > 0.2) {
                throw new Error('The distance between the ends of the bound has to be less than 0.2 degrees');
            } else {
                //Consulto al punto SPARQL por todos los puntos en la tesela
                //Tengo que agrupar los resultados por el POI
                const options = options4Request(getInfoPOIs(bounds));
                fetch(
                    Mustache.render(
                        'http://{{{host}}}:{{{port}}}{{{path}}}',
                        {
                            host: options.host,
                            port: options.port,
                            path: options.path
                        }),
                    { headers: options.headers })
                    .then(r => {
                        return r.json();
                    }).then(json => {
                        const out = JSON.stringify(mergeResults(sparqlResponse2Json(json), 'poi'));
                        winston.info(Mustache.render(
                            'getPOIs || !group || {{{north}}} || {{{east}}} || {{{south}}} || {{{west}}} || {{{out}}} || {{{time}}}',
                            {
                                north: bounds.north,
                                east: bounds.east,
                                south: bounds.south,
                                west: bounds.west,
                                out: out,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 200, 'getPOIs', start);
                        res.send(out);
                    })
                    .catch(error => {
                        winston.error(Mustache.render(
                            'getPOIs || !group || {{{north}}} || {{{east}}} || {{{south}}} || {{{west}}} || {{{error}}} || {{{time}}}',
                            {
                                north: bounds.north,
                                east: bounds.east,
                                south: bounds.south,
                                west: bounds.west,
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 500, 'getPOIs', start);
                        res.sendStatus(500);
                    });
            }
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getPOIs || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getPOIs', start);
        res.status(400).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/pois?north=41.664319&south=41.660319&west=-4.707917&east=-4.703917&group=false',
            { error: error, urlServer: urlServer }));
    }
}

function widthTesela(difL) {
    let widthLat = 0;
    let prevWidth = 361;
    for (let i = 1; i < 20; i++) {
        let p = difL / i;
        if (p == 1) {
            widthLat = p;
            break;
        } else {
            if (p > 1) {
                prevWidth = p;
            } else {
                widthLat = prevWidth;
                break;
            }
        }
    }
    return widthLat;
}

/**
 *
 * @param {*} req
 * @param {*} res
 */
async function newPOI(req, res) {
    /*
curl -X POST --user pablo:pablo -H "Content-Type: application/json" -d "{\"lat\": 4, \"long\": 5, \"comment\": [{\"value\": \"Hi!\", \"lang\": \"en\"}, {\"value\": \"Hola caracola\", \"lang\": \"es\"}], \"label\": [{\"value\":\"Título punto\", \"lang\":\"es\"}]}" "localhost:11110/pois"
    */
    const needParameters = Mustache.render(
        'Mandatory parameters in the request body are: lat[double] (latitude); long[double] (longitude); comment[string]; label[string]\nOptional parameters: thumbnail[url]; thumbnailLicense[url]; category[uri]',
        { urlServer: urlServer });
    const start = Date.now();
    try {
        const { body } = req;
        if (body) {
            if (body.lat && body.long && body.comment && body.label) {
                FirebaseAdmin.auth().verifyIdToken(getTokenAuth(req.headers.authorization))
                    .then(async dToken => {
                        const { uid, email_verified } = dToken;
                        if (email_verified && uid !== '') {
                            getInfoUser(uid).then(async infoUser => {
                                if (infoUser !== null && infoUser.rol < 2) {
                                    let labelEs;
                                    body.label.some(label => {
                                        labelEs = label.value;
                                        return label.lang && label.lang === 'es';
                                    });
                                    const idPoi = Mustache.render(
                                        'http://chest.gsic.uva.es/data/{{{idPoi}}}',
                                        { idPoi: labelEs.replace(/ /g, '_').replace('/', '') }
                                        // { idPoi: encodeURIComponent(labelEs.replace(/ /g, '_')) }
                                        // { idPoi: labelEs.replace(/ /g, '_').replace(/[^a-zA-Z:_]/g, '') }
                                    );
                                    //Compruebo que el id del POI no exista. Si existe rechazo
                                    const repeatedId = await checkUID(idPoi);
                                    if (repeatedId === true) {
                                        //Inserto el nuevo POI al no existir el id en el repositorio
                                        const p4R = {
                                            id: idPoi,
                                            author: infoUser.id,
                                            lat: body.lat,
                                            long: body.long,
                                            label: body.label,
                                            comment: body.comment
                                        };
                                        //TODO necesito comprobar si vienen parámetros adicionales (fijos, como el thumbnail)
                                        /*
                                        PARA LAS IMÁGENES
                                        image = [
                                            ...
                                            {
                                                image: url,
                                                license: url || string,
                                                thumbnail: true/false
                                            },
                                            ...
                                        ]
                                        */
                                        if (body.image) {
                                            p4R.image = body.image;
                                        }

                                        if (body.categories) {
                                            p4R.categories = body.categories;
                                        }

                                        const requests = insertPoi(p4R);
                                        const promises = [];
                                        requests.forEach(request => {
                                            const options = options4Request(request, true);
                                            promises.push(
                                                fetch(
                                                    Mustache.render(
                                                        'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                        {
                                                            host: options.host,
                                                            port: options.port,
                                                            path: options.path
                                                        }),
                                                    { headers: options.headers }
                                                )
                                            );
                                        });
                                        Promise.all(promises).then((values) => {
                                            let sendOK = true;
                                            values.forEach(v => {
                                                if (v.status !== 200) {
                                                    sendOK = false;
                                                }
                                            });
                                            if (sendOK) {
                                                winston.info(Mustache.render(
                                                    'newPOI || {{{uid}}} || {{{idPoi}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        idPoi: idPoi,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 201, 'newPOI', start);
                                                res.location(idPoi).sendStatus(201);
                                            } else {
                                                winston.error(Mustache.render(
                                                    'newPOI || {{{uid}}} || {{{time}}}',
                                                    {
                                                        uid: uid,
                                                        time: Date.now() - start
                                                    }
                                                ));
                                                logHttp(req, 500, 'newPOI', start);
                                                res.sendStatus(500);
                                            }
                                        });
                                    } else {
                                        winston.info(Mustache.render(
                                            'newPOI || {{{uid}}} || Label used || {{{time}}}',
                                            {
                                                uid: uid,
                                                time: Date.now() - start
                                            }
                                        ));
                                        logHttp(req, 400, 'newPOI', start);
                                        res.status(400).send('Label used in other POI');
                                    }
                                } else {
                                    winston.info(Mustache.render(
                                        'newPOI || {{{uid}}} || {{{time}}}',
                                        {
                                            uid: uid,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 401, 'newPOI', start);
                                    res.sendStatus(401);
                                }
                            }).catch(error => {
                                winston.error(Mustache.render(
                                    'newPOI || {{{uid}}} || {{{error}}} || {{{time}}}',
                                    {
                                        uid: uid,
                                        error: error,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 500, 'newPOI', start);
                                res.sendStatus(500);
                            });
                        } else {
                            winston.info(Mustache.render(
                                'newPOI || {{{uid}}} || {{{time}}}',
                                {
                                    uid: uid,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 403, 'newPOI', start);
                            res.status(403).send('You have to verify your email!');
                        }
                    })
                    .catch((error) => {
                        winston.info(Mustache.render(
                            'newPOI || {{{error}}} || {{{time}}}',
                            {
                                error: error,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 401, 'newPOI', start);
                        res.sendStatus(401);
                    });
            } else {
                winston.info(Mustache.render(
                    'newPOI || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'newPOI', start);
                res.status(400).send(needParameters);
            }
        } else {
            winston.info(Mustache.render(
                'newPOI || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'newPOI', start);
            res.status(400).send(needParameters);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'newPOI || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 400, 'newPOI', start);
        res.status(400).send(Mustache.render('{{{error}}}\n{{{parameteres}}}', { error: error, parameters: needParameters }));
    }
}

module.exports = {
    getPOIs,
    newPOI,
};
