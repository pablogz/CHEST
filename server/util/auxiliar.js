const Mustache = require('mustache');
const fs = require('fs');
const short = require('short-uuid');
const fetch = require('node-fetch');

const { addrSparql, portSparql, userSparql, passSparql } = require('./config');
const { City } = require('./pojos/city');
const { json } = require('express');

const vCities = [];

/**
 * Function to generate query options
 * 
 * @param {Strin} query Query to be made to SPARQL endpoint
 * @param {boolean} isAuth Variable to control whether the query must be authenticated or not
 * @returns Query options
 */
function options4Request(query, isAuth = false) {
    // Todas las consultas tienen en común la necesidad de un host, un puerto y una ruta
    const options = {
        host: addrSparql,
        port: portSparql,
        path: Mustache.render('/{{{type}}}?query={{{query}}}', {
            type: isAuth ? 'sparql-auth' : 'sparql',
            query: query
        }),
    };
    // Si la consulta es autenticada se agregan las cabeceras necesarias a la consulta
    if (isAuth) {
        options.headers = {
            Accept: 'application/sparql-results+json',
            Authorization: Mustache.render(
                'Basic {{{userPass}}}',
                {
                    userPass: Buffer.from(Mustache.render(
                        '{{{user}}}:{{{pass}}}',
                        { user: userSparql, pass: passSparql })
                    ).toString('base64')
                }
            )
        };
    } else {
        options.headers = {
            Accept: 'application/sparql-results+json',
        };
    }
    return options;
}

function checkExistenceId(id) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            <{{{id}}}> [] [] .\
        }',
        { id: id }
    ).replace(/\s+/g, ' '));
}

/**
 * Function to adapt the response of the SPARQL endpoint 
 * 
 * @param {Object} response Response provided by SPARQL endpoint (JSON)
 * @returns Data ready for processing
 */
function sparqlResponse2Json(response) {
    // Compruebo que la respuesta tiene los campos necesarios para precesarla
    if (response.head === undefined ||
        response.head.vars === undefined ||
        response.results === undefined ||
        response.results.bindings === undefined) {
        return null;
    } else {
        // Parámetros consultados
        const vars = response.head.vars;
        // Datos de la respuesta
        const bindings = response.results.bindings;
        // Vector que voy a devolver a la función previa
        const results = [];
        bindings.forEach(element => {
            const r = {};
            vars.forEach(v => {
                const ele = element[v];
                if (ele !== undefined && ele.type !== undefined) {
                    // Dependiendo del tipo de dato realizo un procesado u otro
                    switch (ele.type) {
                        case 'typed-literal':
                            r[v] = (ele.datatype === 'http://www.w3.org/2001/XMLSchema#decimal') ?
                                parseFloat(ele.value) :
                                ele.value;
                            break;
                        case 'literal':
                            r[v] = (ele["xml:lang"] === undefined) ?
                                { value: ele.value } :
                                {
                                    lang: ele["xml:lang"],
                                    value: ele.value
                                };
                            break;
                        default:
                            r[v] = ele.value;
                            break;
                    }
                }
            });
            results.push(r);
        });
        return (results);
    }
}

/**
 * Function to merge objects of an array taking into account an identifier.
 * 
 * @param {Array} vector Object array. They all have to have the property that is sent as idKey
 * @param {String} idKey Object identifier key
 * @return Merged array 
 */
function mergeResults(vector, idKey) {
    const out = [];
    let element;
    // Extaigo los elementos del vector (empezando por el final ya que utilizo pop)
    while ((element = vector.pop()) !== undefined) {
        let inter = JSON.parse(JSON.stringify(element)); // Copia del objeto
        let repe;
        const id = element[idKey];
        // Busco en el vector la primera coincidencia e itero
        while ((repe = vector.find(e => e[idKey] === id)) !== undefined) {
            // Busco la diferencia entre las dos entradas
            Object.keys(repe).forEach(k => {
                let equals = true;
                // Si es un objeto compruebo cada uno de sus campos (solo un nivel, es decir, 
                // no puede haber un objeto dentro de un objeto).
                if (typeof repe[k] === 'object') {
                    Object.keys(repe[k]).forEach(k2 => {
                        if (element[k][k2] !== undefined && element[k][k2] !== repe[k][k2]) {
                            equals = false;
                        }
                    });
                } else {
                    // Si no es un objeto comparo directamente (no espero funciones)
                    equals = (repe[k] === element[k]);
                }
                // Guardo si no son iguales
                if (!equals) {
                    let save = true;
                    // Compruebo ahora si no lo he guardado previamente
                    if (typeof repe[k] === 'object') {
                        if (Array.isArray(inter[k])) {
                            inter[k].forEach(o => {
                                let save2 = false;
                                Object.keys(o).forEach(k2 => {
                                    if (o[k2] !== repe[k][k2])
                                        save2 = true;
                                });
                                save = save2;
                            });
                        } else {
                            Object.keys(inter[k]).forEach(k2 => {
                                let save2 = false;
                                if (inter[k][k2] !== repe[k][k2]) {
                                    save2 = true;
                                }
                                save = save2;
                            });
                        }
                    } else {
                        if (Array.isArray(inter[k])) {
                            inter[k].forEach(e => { if (e === repe[k]) save = false; });
                        } else {
                            save = inter[k] !== repe[k];
                        }
                    }
                    // Guardo como vector los resultados
                    if (save) {
                        Array.isArray(inter[k]) ?
                            inter[k].push(repe[k]) :
                            inter[k] = [inter[k], repe[k]];
                    }
                }
            });
            // Elimino en el elemento con el que acabo de trabajar
            vector.splice(vector.indexOf(repe), 1);
        }
        //Agrego al vector de salida la fusión
        out.push(inter);
    }
    return out;
}

// function cities() {
//     if (vCities === null || !vCities.length) {
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //Aquí haría la petición a Wikidata en vez de leer de fichero
//         const fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//         //const i = []
//         fCities.forEach(city => {
//             if (typeof city.population !== 'undefined') {
//                 //i.push(new City(city.city, city.lat, city.long, city.population));
//                 vCities.push(new City(city.city, city.lat, city.long, city.population));
//             } else {
//                 //i.push(new City(city.city, city.lat, city.long));
//                 vCities.push(new City(city.city, city.lat, city.long));

//             }
//         });
//         //Ordeno de mayor a menor población
//         vCities.sort((city0, city1) => city1.population - city0.population);
//         //SOLUCIONADO CON LA NUEVA PETICIÓN
//         //Puede traer "filas duplicadas debido "
//         //let inter = {};
//         //let inter2 = i.filter(city => inter[city.id] ? false : inter[city.id] = true);
//         //inter2.forEach(city => vCities.push(city));
//     }
//     return vCities;
// }

async function cities() {
    if (vCities === null || !vCities.length) {
        // await fetch(
        //     Mustache.render(
        //         'https://query.wikidata.org/sparql?query={{{path}}}',
        //         {
        //             path: encodeURIComponent(
        //                 'SELECT DISTINCT ?city ?lat ?long ?population WHERE {\
        //                 {\
        //                   SELECT (MAX(?la) AS ?lat) ?city WHERE {\
        //                     ?city wdt:P31/wdt:P279* wd:Q515 ;\
        //                         p:P625/psv:P625/wikibase:geoLatitude ?la .\
        //                   } GROUP BY ?city\
        //                 }\
        //                 {\
        //                   SELECT (MAX(?lo) AS ?long) ?city WHERE {\
        //                     ?city wdt:P31/wdt:P279* wd:Q515 ;\
        //                         p:P625/psv:P625/wikibase:geoLongitude ?lo .\
        //                   } GROUP BY ?city\
        //                 }\
        //                 OPTIONAL {\
        //                   SELECT (MAX(?p) AS ?population) ?city WHERE {\
        //                     ?city wdt:P1082 ?p .\
        //                   } GROUP BY ?city\
        //                 }\
        //             }'.replace(/\s+/g, ' '))
        //         }),
        //     {
        //         headers: {
        //             Accept: 'application/json',
        //         }
        //     }).then(async result => {
        //         switch (result.status) {
        //             case 200:
        //                 return result.json();
        //             default:
        //                 return null;
        //         }
        //     }).then(async data => {
        const data = null; //TODO ELIMINAR CUANDO SE VUELVA A HACER LA PETICIÓN
        let fCities;
        if (data !== null) {
            fCities = data.results.bindings;
            fCities.forEach(city => {
                if (typeof city.population !== 'undefined') {
                    vCities.push(new City(
                        city.city.value,
                        parseFloat(city.lat.value),
                        parseFloat(city.long.value),
                        parseInt(city.population.value)
                    ));
                } else {
                    vCities.push(new City(
                        city.city,
                        parseFloat(city.lat.value),
                        parseFloat(city.long.value)
                    ));

                }
            });
        } else {
            fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
            fCities.forEach(city => {
                if (typeof city.population !== 'undefined') {
                    vCities.push(new City(city.city, city.lat, city.long, city.population));
                } else {
                    vCities.push(new City(city.city, city.lat, city.long));
                }
            });
        }

        //Ordeno de mayor a menor población
        vCities.sort((city0, city1) => city1.population - city0.population);
        return vCities;
        // })
        // .catch(error => {
        //     console.log(error);
        //     const fCities = JSON.parse(fs.readFileSync('./data/cities.json'));
        //     fCities.forEach(city => {
        //         if (typeof city.population !== 'undefined') {
        //             vCities.push(new City(city.city, city.lat, city.long, city.population));
        //         } else {
        //             vCities.push(new City(city.city, city.lat, city.long));

        //         }
        //     });
        // vCities.sort((city0, city1) => city1.population - city0.population);
        // return vCities;
        // });
    } else {
        return vCities;
    }
}

/**
* https://stackoverflow.com/a/5717133
*/
function validURL(str) {
    /*const pattern = new RegExp(
        Mustache.render(
            '{{{protocol}}}{{{domainName}}}{{{ipAdd}}}{{{portPath}}}{{{queryString}}}{{{fragmentLocator}}}',
            {
                protocol: '^(https?:\\/\\/)?', // protocol
                domainName: '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|', // domain name
                ipAdd: '((\\d{1,3}\\.){3}\\d{1,3}))', // OR ip (v4) address
                portPath: '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*', // port and path
                queryString: '(\\?[;&a-z\\d%_.~+=-]*)?', // query string
                fragmentLocator: '(\\#[-a-z\\d_]*)?$' // fragment locator
            }
        ),
        'i');*/
    const pattern = new RegExp('^(https?:\\/\\/)?' + // protocol
        '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|' + // domain name
        '((\\d{1,3}\\.){3}\\d{1,3}))' + // OR ip (v4) address
        '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*' + // port and path
        '(\\?[;&a-z\\d%_.~+=-]*)?' + // query string
        '(\\#[-a-z\\d_]*)?$', 'i'); // fragment locator
    console.log(pattern);

    return !!pattern.test(str);
}

async function generateUid() {
    let uid;
    let isUid = false;
    while (!isUid) {
        uid = Mustache.render(
            'http://chest.gsic.uva.es/data/{{{uid}}}',
            {
                uid: short.generate()
            }
        );
        isUid = await checkUID(uid);
    }
    return uid;
}

async function checkUID(uid) {
    const options = options4Request(checkExistenceId(uid));
    return await fetch(
        Mustache.render(
            'http://{{{host}}}:{{{port}}}{{{path}}}',
            {
                host: options.host,
                port: options.port,
                path: options.path
            }),
        { headers: options.headers })
        .then(async r => {
            return await r.json();
        })
        .then(async j => { return !j.boolean; });
    //.catch(async error => { return true; });
}

function getTokenAuth(authorization) {
    const parts = authorization.split(' ');
    switch (parts.length) {
        case 1:
            return authorization;
        case 2:
            if (parts[0] === 'Bearer') {
                return parts[1];
            } else {
                throw new Error('401 Unauthorized');
            }
        default:
            throw new Error('401 Unauthorized');
    }
}

module.exports = {
    options4Request,
    sparqlResponse2Json,
    mergeResults,
    cities,
    validURL,
    generateUid,
    checkUID,
    getTokenAuth,
}