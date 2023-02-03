const Mustache = require('mustache');
const fetch = require('node-fetch');

const { tokenCraft } = require('../../util/config');
const { NearSug } = require('../../util/pojos/near_sug');
const { logHttp } = require('../../util/auxiliar');
const winston = require('../../util/winston');

async function getPOIsLOD(req, res) {
    const start = Date.now();
    try {
        const { lat, long, incr } = req.query;
        if (lat != undefined && long != undefined && incr != undefined) {
            try {
                const latF = parseFloat(lat), longF = parseFloat(long), incrF = parseFloat(incr);
                const templateNearPois = 'https://crafts.gsic.uva.es/apis/localizarteV2/query?id=places-en&latCenter={{lat}}&lngCenter={{lng}}&halfSideDeg={{incr}}&isNotType=http://dbpedia.org/ontology/PopulatedPlace&limit=800';
                const headers = {
                    Authorization: Mustache.render(
                        'Bearer {{{token}}}',
                        {
                            token: tokenCraft
                        }),
                    Accept: 'application/json'
                };
                fetch(
                    Mustache.render(
                        templateNearPois,
                        {
                            lat: latF,
                            lng: longF,
                            incr: incrF
                        }
                    ),
                    { headers: headers },
                ).then((response) => {
                    switch (response.status) {
                        case 200:
                            return response.json();
                        default:
                            return null;
                    }
                }).then((data) => {
                    if (data != null && data !== undefined && data.results !== undefined && data.results.bindings !== undefined) {
                        const places = data.results.bindings;
                        const nearSug = [];
                        for (let ns of places) {
                            try {
                                const n = new NearSug(ns['place']['value'], parseFloat(ns['lat']['value']), parseFloat(ns['lng']['value']));
                                n.setDistance(latF, longF);
                                nearSug.push(n);
                            } catch (error) {
                                //console.log(error)
                            }
                        }
                        if (nearSug.length > 0) {
                            nearSug.sort((a, b) => a.distance - b.distance);
                            let q2 =
                                'https://crafts.gsic.uva.es/apis/localizarteV2/resources?id=Place-en&ns=http://dbpedia.org/resource/&nspref=p';
                            const nearSugRequest = nearSug.slice(0, Math.min(10, nearSug.length));
                            nearSugRequest.forEach(n => {
                                q2 = Mustache.render(
                                    '{{{s}}}&iris={{{p}}}',
                                    {
                                        s: q2,
                                        p: n.id.replace('http://dbpedia.org/resource/', 'p:')
                                    });
                            });
                            fetch(q2, { headers: headers }
                            ).then((response) => {
                                if (response.status == 200) { return response.json(); } else { return null; }
                            }
                            ).then(data => {
                                if (data != null) {
                                    if (!Array.isArray(data)) {
                                        data = [data];
                                    }

                                    let pois = [];
                                    for (let d of data) {
                                        try {
                                            let poi = {};
                                            for (let p in d) {

                                                switch (p) {
                                                    case 'iri':
                                                        poi['poi'] = d[p];
                                                        for (let i = 0, tama = nearSugRequest.length; i < tama; i++) {
                                                            if (nearSugRequest[i].id == d[p]) {
                                                                poi['lat'] = nearSugRequest[i].lat;
                                                                poi['lng'] = nearSugRequest[i].long;
                                                                break;
                                                            }
                                                        }
                                                        break;
                                                    case 'label':
                                                    case 'comment': {
                                                        poi[p] = procesaPairLang(d[p]);
                                                        break;
                                                    }
                                                    case 'image':
                                                        d[p].iri = d[p].iri.replace('?width=300', '');
                                                        poi['thumbnailImg'] = d[p].iri;
                                                        if (d[p].rights !== undefined) {
                                                            poi['thumbnailLic'] = d[p].rights;
                                                        }
                                                        break;
                                                    case 'categories': {
                                                        let categories = [];
                                                        let auxiliar;
                                                        if (Array.isArray(d[p])) {
                                                            auxiliar = d[p];
                                                        } else {
                                                            auxiliar = [d[p]];
                                                        }
                                                        for (let categoryRaw of auxiliar) {
                                                            let category = {};
                                                            if (categoryRaw['iri'] !== undefined) {
                                                                category['iri'] = categoryRaw['iri'].trim();
                                                                if (categoryRaw['label'] !== undefined) {
                                                                    category['label'] = procesaPairLang(categoryRaw['label']);
                                                                }
                                                                if (categoryRaw['broader'] !== undefined) {
                                                                    if (Array.isArray(categoryRaw['broader'])) {
                                                                        category['broader'] = categoryRaw['broader'];
                                                                    } else {
                                                                        category['broader'] = [categoryRaw['broader']];
                                                                    }
                                                                }
                                                                categories.push(category);
                                                            }
                                                        }
                                                        poi['categories'] = categories;
                                                        break;
                                                    }
                                                    default:
                                                        break;
                                                }
                                            }
                                            pois.push(poi);
                                        } catch (error) {
                                            //console.log(error);
                                        }
                                    }
                                    winston.info(Mustache.render(
                                        'getPOIsLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{pois}}} || {{{time}}}',
                                        {
                                            latF: latF,
                                            longF: longF,
                                            incrF: incrF,
                                            pois: JSON.stringify(pois),
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 200, 'getPOIsLOD', start);
                                    res.send(JSON.stringify(pois));
                                } else {
                                    winston.info(Mustache.render(
                                        'getPOIsLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                                        {
                                            latF: latF,
                                            longF: longF,
                                            incrF: incrF,
                                            time: Date.now() - start
                                        }
                                    ));
                                    logHttp(req, 204, 'getPOIsLOD', start);
                                    res.sendStatus(204);
                                }
                            }).catch(error => {
                                winston.info(Mustache.render(
                                    'getPOIsLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{error}}} || {{{time}}}',
                                    {
                                        latF: latF,
                                        longF: longF,
                                        incrF: incrF,
                                        error: error,
                                        time: Date.now() - start
                                    }
                                ));
                                logHttp(req, 500, 'getPOIsLOD', start);
                                res.sendStatus(500);
                            });
                        } else {
                            winston.info(Mustache.render(
                                'getPOIsLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                                {
                                    latF: latF,
                                    longF: longF,
                                    incrF: incrF,
                                    time: Date.now() - start
                                }
                            ));
                            logHttp(req, 204, 'getPOIsLOD', start);
                            res.sendStatus(204);
                        }
                    } else {
                        winston.info(Mustache.render(
                            'getPOIsLOD || {{{latF}}} || {{{longF}}} || {{{incrF}}} || {{{time}}}',
                            {
                                latF: latF,
                                longF: longF,
                                incrF: incrF,
                                time: Date.now() - start
                            }
                        ));
                        logHttp(req, 204, 'getPOIsLOD', start);
                        res.sendStatus(204);
                    }
                }
                ).catch((error) => {
                    winston.info(Mustache.render(
                        'getPOIsLOD || {{{error}}} || {{{time}}}',
                        {
                            error: error,
                            time: Date.now() - start
                        }
                    ));
                    logHttp(req, 500, 'getPOIsLOD', start);
                    res.status(500).send(error);
                }
                );
            } catch (error) {
                winston.info(Mustache.render(
                    'getPOIsLOD || {{{time}}}',
                    {
                        time: Date.now() - start
                    }
                ));
                logHttp(req, 400, 'getPOIsLOD', start);
                res.sendStatus(400);
            }
        } else {
            winston.info(Mustache.render(
                'getPOIsLOD || {{{time}}}',
                {
                    time: Date.now() - start
                }
            ));
            logHttp(req, 400, 'getPOIsLOD', start);
            res.sendStatus(400);
        }
    } catch (error) {
        winston.error(Mustache.render(
            'getPOIsLOD || {{{error}}} || {{{time}}}',
            {
                error: error,
                time: Date.now() - start
            }
        ));
        logHttp(req, 500, 'getPOIsLOD', start);
        res.sendStatus(500);
    }
}

function procesaPairLang(raw) {
    let valorCampo = [];
    let idiomas = [];
    let auxiliar;
    if (Array.isArray(raw)) {
        auxiliar = raw;
    } else {
        auxiliar = [raw];
    }
    for (let par of auxiliar) {
        for (let idioma in par) {
            if (idiomas.includes(idioma) == false) {
                valorCampo.push({
                    'lang': idioma,
                    'value': par[idioma]
                });
                idiomas.push(idioma);
            } else {
                valorCampo.forEach(vC => {
                    if (vC.lang === idioma) {
                        if (!Array.isArray(vC.value)) {
                            let value = [];
                            value.push(vC.value);
                            vC.value = value;
                        }
                        vC.value.push(par[idioma]);
                    }
                });
            }
        }
    }
    return valorCampo;
}

module.exports = {
    getPOIsLOD
}