const Mustache = require('mustache');
const fetch = require('node-fetch');

const { tokenCraft } = require('../../util/config');
const { NearSug } = require('../../util/pojos/near_sug');

async function getPOIsLOD(req, res) {
    const { lat, long, incr } = req.query;

    if (lat != undefined && long != undefined && incr != undefined) {
        try {
            const latF = parseFloat(lat), longF = parseFloat(long), incrF = parseFloat(incr);
            const templateNearPois = 'https://crafts.gsic.uva.es/apis/localizarteV2/query?id=places-en&latCenter={{lat}}&lngCenter={{lng}}&halfSideDeg={{incr}}&isNotType=http://dbpedia.org/ontology/PopulatedPlace&limit=800';
            const headers = { Authorization: Mustache.render('Bearer {{{token}}}', { token: tokenCraft }), };
            fetch(
                Mustache.render(
                    templateNearPois,
                    {
                        lat: latF,
                        lng: longF,
                        incr: incrF
                    }
                ),
                { headers: headers }
            ).then((response) => {
                switch (response.status) {
                    case 200:
                        return response.json();
                    default:
                        return null;
                }
            }).then((data) => {
                //{"message":"request to https://crafts.gsic.uva.es/apis/localizarteV2/query?id=places-en&latCenter=40&lngCenter=-4&halfSideDeg=2&isNotType=http://dbpedia.org/ontology/PopulatedPlace&limit=800 failed, reason: unable to verify the first certificate","type":"system","errno":"UNABLE_TO_VERIFY_LEAF_SIGNATURE","code":"UNABLE_TO_VERIFY_LEAF_SIGNATURE"}
                if (data != null && data !== undefined && data.results !== undefined && data.results.bindings !== undefined) {
                    const places = data.results.bindings;
                    const nearSug = [];
                    for (let ns in places) {
                        try {
                            const n = NearSug(ns['place']['value'], ns['lat']['value'], ns['lng']['value']);
                            n.setDistance(lat, long);
                            nearSug.push(n);
                        } catch (error) {
                            console.log(error)
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
                        ).then((response) => { response.status == 200 ? response.json() : null }
                        ).then(data => {
                            if (data != null) {
                                //TODO
                                res.sendStatus(204);
                            } else {
                                res.sendStatus(500);
                            }
                        }).catch(error => {
                            console.log(error);
                            res.sendStatus(500);
                        });
                    } else { res.sendStatus(204); }
                } else {
                    res.sendStatus(204);
                }
            }
            ).catch((error) =>
                res.status(500).send(error)
            );
        } catch (error) {
            res.sendStatus(400);
        }
    } else {
        res.sendStatus(400);
    }
}

module.exports = {
    getPOIsLOD
}