const Mustache = require('mustache');
const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');

const { urlServer } = require('../../util/config');
const { options4Request, sparqlResponse2Json, mergeResults, cities, checkUID, getTokenAuth } = require('../../util/auxiliar');
const { getLocationPOIs, getInfoPOIs, insertPoi } = require('../../util/queries');
const { getInfoUser } = require('../../util/bd');
//const { json } = require('express');

/**
 * Required query: north, south, west, east, group
 * Optional query: idStudent
 * @param {*} req
 * @param {*} res
 */
async function getPOIs(req, res) {
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
                }).then(json => {
                    const allPoi = mergeResults(sparqlResponse2Json(json), 'poi');
                    const validCities = [];
                    //Me quedo con las ciudades que se encuentren dentro de los límites indicados por el cliente
                    cities().forEach(city => {
                        if (city.inside(bounds)) {
                            validCities.push(city);
                        }
                    });
                    if (!validCities.length || !allPoi.length) {
                        res.send(JSON.stringify(validCities.push({
                            id: 'boundsCenter',
                            lat: (bounds.north - bounds.south) / 2,
                            lng: (bounds.east - bounds.west) / 2,
                            pois: allPoi.length
                        })));
                    } else {
                        let validCities2;
                        //Limito el número máximo de puntos que se van a mostrar al usuario en 20
                        if (validCities.length > 20) {
                            validCities2 = [];
                            //Doy prioridad a las ciudades que tengan población
                            validCities.forEach(city => {
                                if (city.hasPopulation) {
                                    validCities2.push(city);
                                }
                            });
                            //Si ninguna tiene población agrego todas y me quedo con 20
                            if (!validCities2.length) {
                                const inicio = Math.floor(Math.random() * validCities.length - 20);
                                validCities2 = validCities.splice(inicio, inicio + 20);
                            } else {
                                // Las ciudades están ordenadas de mayor a menor población, 
                                // por lo que me quedo con las 20 más pobladas si la longitud del
                                // vector es mayor
                                if (validCities2.length > 20) {
                                    validCities2 = validCities2.splice(0, 20);
                                }
                            }
                        } else {
                            //Si no supero las 20 ciudades me quedo con todas
                            validCities2 = validCities.splice(0, validCities.length);
                        }
                        const response = [];
                        //En la respuesta se indica la localización de la ciudad, el id y el número de POI
                        validCities2.forEach(city => {
                            response.push({
                                id: city.id,
                                lat: city.latitude,
                                long: city.longitude,
                                pois: 0
                            });
                        });
                        // Compruebo la distancia de cada poi con cada ciudad 
                        // e incremento el punto en el que se encuentre más cerca
                        allPoi.forEach(poi => {

                            /*const poiCities = [];
                            validCities2.forEach(city => {
                                poiCities.push({
                                    id: city.id,
                                    distance: city.distance(poi.lat, poi.lng)
                                });
                            });
                            //Ordeno de menor a mayor distancia
                            poiCities.sort((a, b) => a - b);
                            const nearCity = poiCities[0].id;*/
                            const nearCity = {
                                id: "ciudadFalsa",
                                distance: 999999999999999
                            }
                            validCities2.forEach(city => {
                                const d = city.distance(poi.lat, poi.lng);
                                if (d < nearCity.distance) {
                                    nearCity.id = city.id;
                                    nearCity.distance = d;
                                }
                            });
                            const i = response.findIndex(city => city.id == nearCity.id);
                            if (i !== undefined) {
                                response[i].pois += 1;
                            }
                        });
                        const finalResponse = [];
                        response.forEach(resp => {
                            if (resp.pois > 0) {
                                finalResponse.push(resp);
                            }
                        });
                        res.send(JSON.stringify(finalResponse));
                    }
                })
                .catch(error => {
                    console.error(error);
                    res.sendStatus(500);
                });
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
                        res.send(JSON.stringify(mergeResults(sparqlResponse2Json(json), 'poi')));
                    })
                    .catch(error => {
                        console.error(error);
                        res.sendStatus(500);
                    });
            }
        }
    } catch (error) {
        res.status(400).send(Mustache.render(
            '{{{error}}}\nEx. {{{urlServer}}}/pois?north=41.664319&south=41.660319&west=-4.707917&east=-4.703917&group=false',
            { error: error, urlServer: urlServer }));
    }
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
                                        { idPoi: labelEs.replace(/ /g, '_').replace(/[^a-zA-Z:_]/g, '') });
                                    //Compruebo que el id del POI no exista. Si existe rechazo
                                    const repeatedId = await checkUID(idPoi);
                                    if (repeatedId === false) {
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
                                        const requests = insertPoi(p4R);
                                        requests.forEach(request => {
                                            const options = options4Request(request, true);
                                            fetch(
                                                Mustache.render(
                                                    'http://{{{host}}}:{{{port}}}{{{path}}}',
                                                    {
                                                        host: options.host,
                                                        port: options.port,
                                                        path: options.path
                                                    }),
                                                { headers: options.headers });
                                        });
                                        res.location(idPoi).sendStatus(201);
                                    } else {
                                        res.status(400).send('Label used in other POI');
                                    }
                                } else {
                                    res.sendStatus(401);
                                }
                            }).catch(error => {
                                console.error(error);
                                res.sendStatus(500);
                            });
                        } else {
                            res.status(403).send('You have to verify your email!');
                        }
                    })
                    .catch((error) => {
                        console.error(error);
                        res.sendStatus(401);
                    });
            } else {
                res.status(400).send(needParameters);
            }
        } else {
            res.status(400).send(needParameters);
        }
    } catch (error) {
        res.status(400).send(Mustache.render('{{{error}}}\n{{{parameteres}}}', { error: error, parameters: needParameters }));
    }
}

module.exports = {
    getPOIs,
    newPOI,
};
