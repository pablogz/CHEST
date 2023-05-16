const Mustache = require('mustache');
const { validURL } = require('./auxiliar');

const winston = require('./winston');

function getLocationFeatures(bounds) {
    return encodeURIComponent(Mustache.render(
        'SELECT DISTINCT ?feature ?lat ?lng WHERE {\
            ?feature \
                a chesto:Feature ;\
                geo:lat ?lat ;\
                geo:long ?lng .\
            FILTER(\
                xsd:decimal(?lat) >= {{{south}}} && \
                xsd:decimal(?lat) < {{{north}}} && \
                xsd:decimal(?lng) >= {{{west}}} && \
                xsd:decimal(?lng) < {{{east}}}) .\
        }',
        {
            north: bounds.north,
            east: bounds.east,
            south: bounds.south,
            west: bounds.west
        }).replace(/\s+/g, ' '));
}

// function getInfoPOIs(bounds) {
//     return encodeURIComponent(Mustache.render(
//         'SELECT DISTINCT ?poi ?lat ?lng ?label ?comment ?author ?thumbnailImg ?thumbnailLic ?category WHERE {\
//                 ?poi \
//                     a chesto:POI ;\
//                     geo:lat ?lat ;\
//                     geo:long ?lng ;\
//                     rdfs:label ?label ;\
//                     rdfs:comment ?comment ;\
//                     dc:creator ?author .\
//                 OPTIONAL{\
//                     ?poi chesto:image ?thumbnailImg .\
//                         OPTIONAL {?thumbnailImg dc:license ?thumbnailLic }.\
//                 }.\
//                 OPTIONAL{ ?poi chesto:hasCategory ?category } .\
//                 FILTER(\
//                     xsd:decimal(?lat) >= {{{south}}} && \
//                     xsd:decimal(?lat) < {{{north}}} && \
//                     xsd:decimal(?lng) >= {{{west}}} && \
//                     xsd:decimal(?lng) < {{{east}}}) .\
//             }',
//         {
//             north: bounds.north,
//             east: bounds.east,
//             south: bounds.south,
//             west: bounds.west
//         }).replace(/\s+/g, ' '));
// }

function getInfoFeatures(bounds, type) {
    let filter = '';
    let listFilter;
    const area = Mustache.render(
        '({{{s}}},{{{w}}},{{{n}}},{{{e}}})',
        {
            s: bounds.south,
            w: bounds.west,
            n: bounds.north,
            e: bounds.east,
        }
    )
    switch (type) {
        case 'forest':
            listFilter = [
                // { key: "natural", value: "^(tree|wood)$", e: false },
                { key: "natural", value: "tree", e: 0 }
            ]
            break;
        case 'schools':
            listFilter = [
                { key: "amenity", value: "^(school|college|university)$", e: 1 },
                { key: "building", value: "^(school|college|university)$", e: 1 },

            ]
            break;
        default:
            listFilter = [
                { key: "building", value: "^(church|cathedral)$", e: 1 },
                { key: "museum", value: "^(history|art)$", e: 1 },
                // { key: "heritage", value: "2", e: 0 },
                // { key: "heritage", value: "1", e: 0 },
                { key: "heritage", e: -1 },
                { key: "historic", e: -1 }
            ];
            break;
    }

    for (let f of listFilter) {
        //f.e: 0 = =; 1 = ~; -1=withoutValue
        filter = Mustache.render(
            '{{{oldF}}}nwr["{{{key}}}"{{{rel}}}{{{value}}}]{{{area}}};',
            {
                oldF: filter,
                key: f.key,
                rel: f.e == 0 ? "=" : f.e == 1 ? "~" : '',
                value: f.e > -1 ? Mustache.render('"{{{v}}}"', { v: f.value }) : '',
                area: area
            }
        );
    }

    return Mustache.render(
        'data=[out:json][timeout:25];({{{filter}}});out body geom;',
        {
            filter: filter
        }).replace(/\s+/g, ' ').replace(RegExp('"', 'g'), '%22').replace(RegExp(/\s/, 'g'), '%20');
}

function getInfoFeature(idFeature) {
    return encodeURIComponent(Mustache.render(
        'SELECT ?lat ?lng ?label ?comment ?author ?thumbnailImg ?thumbnailLic ?category WHERE {\
            <{{{id}}}> \
                a chesto:Feature ;\
                geo:lat ?lat ;\
                geo:long ?lng ;\
                rdfs:label ?label ;\
                rdfs:comment ?comment ;\
                dc:creator ?author .\
            OPTIONAL{\
                ?feature chesto:thumbnail ?thumbnailImg .\
                    OPTIONAL {?thumbnailImg dc:license ?thumbnailLic }.\
            }.\
            OPTIONAL{ ?feature chesto:hasCategory ?category } .\
        }',
        {
            id: idFeature
        }).replace(/\s+/g, ' '));
}

function getCitiesWikidata() {
    return encodeURIComponent(
        'SELECT DISTINCT ?city ?lat ?long ?population WHERE {\
            {\
              SELECT (MAX(?la) AS ?lat) ?city WHERE {\
                ?city wdt:P31/wdt:P279* wd:Q515 ;\
                    p:P625/psv:P625/wikibase:geoLatitude ?la .\
              } GROUP BY ?city\
            }\
            {\
              SELECT (MAX(?lo) AS ?long) ?city WHERE {\
                ?city wdt:P31/wdt:P279* wd:Q515 ;\
                    p:P625/psv:P625/wikibase:geoLongitude ?lo .\
              } GROUP BY ?city\
            }\
            OPTIONAL {\
              SELECT (MAX(?p) AS ?population) ?city WHERE {\
                ?city wdt:P1082 ?p .\
              } GROUP BY ?city\
            }\
        }'.replace(/\s+/g, ' '));
}

function checkExistenceId(id) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            <{{{id}}}> [] [] .\
        }',
        { id: id }
    ).replace(/\s+/g, ' '));
}

function fields(uid, p4R) {
    const triples = [];
    let vector;
    for (const key in p4R) {
        switch (key) {
            case 'lat':
            case 'long':
                triples.push(Mustache.render(
                    '<{{{uid}}}> geo:{{{key}}} {{{value}}} . ',
                    {
                        uid: uid,
                        key: key,
                        value: p4R[key]
                    }
                ));
                break;
            case 'label':
            case 'comment':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(p => {
                    if (p.lang && p.value) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}"""@{{{lang}}} . ',
                            {
                                uid: uid,
                                key: key,
                                // value: p.value.replace(/"/g, "\\\"").replace(/(\r\n|\n|\r)/gm, ""),
                                value: p.value.replace(/"/g, "\\\""),
                                lang: p.lang
                            }
                        ));
                    } else {
                        throw new Error(Mustache.render('{{{key}}} malformed', { key: key }));
                    }
                });
                break;
            case 'author':
                triples.push(Mustache.render(
                    '<{{{uid}}}> dc:creator <{{{value}}}> . ',
                    {
                        uid: uid,
                        value: p4R[key]
                    }
                ));
                break;
            case 'aT':
                var type;
                switch (p4R[key]) {
                    case 'mcq':
                    case 'tf':
                    case 'photo':
                    case 'multiplePhotos':
                    case 'video':
                    case 'photoText':
                    case 'videoText':
                    case 'multiplePhotosText':
                    case 'text':
                    case 'noAnswer':
                        type = p4R[key];
                        break;
                    default:
                        throw new Error('Problem with the client aT');
                }
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:answerType chesto:{{{aT}}} . ',
                    {
                        uid: uid,
                        aT: type
                    }
                ));
                break;
            case 'inSpace':
                var v = [];
                if (!Array.isArray(p4R[key])) {
                    v.push(p4R[key]);
                } else {
                    v = p4R[key];
                }
                v.forEach(spa => {
                    let value;
                    switch (spa) {
                        case 'physical':
                            value = 'PhysicalSpace';
                            break;
                        case 'virtual':
                            value = 'VirtualSpace';
                            break;
                        default:
                            throw new Error('Problem with the client aT');
                    }
                    triples.push(Mustache.render(
                        '<{{{uid}}}> chesto:inSpace chesto:{{{space}}} . ',
                        {
                            uid: uid,
                            space: value
                        }
                    ));
                });
                break;
            case 'hasFeature':
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:hasFeature <{{{idFeature}}}> . ',
                    {
                        uid: uid,
                        idFeature: p4R[key]
                    }
                ));
                break;
            case 'image':
                /*
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
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(img => {
                    triples.push(Mustache.render(
                        '<{{{uid}}}> chesto:image <{{{image}}}> . ',
                        {
                            uid: uid,
                            image: img.image
                        }));
                    triples.push(Mustache.render(
                        '<{{{image}}}> a chesto:Image . ',
                        {
                            image: img.image
                        }));
                    if (img.license) {
                        const tL = validURL(img.license);
                        triples.push(Mustache.render(
                            '<{{{image}}}> dc:license {{{license}}} . ',
                            {
                                image: img.image,
                                license: tL ?
                                    Mustache.render('<{{{l}}}>', { l: img.license }) :
                                    Mustache.render('"{{{l}}}"', { l: img.license })
                            }));
                    }
                    if (img.thumbnail) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> chesto:thumbnail <{{{image}}}> . ',
                            {
                                uid: uid,
                                image: img.image
                            }));
                    }
                });
                break;
            case 'categories':
                // categories = [
                //     ...
                //     {
                //         iri: url,
                //     },
                //     {
                //         iri: url,
                //         label: [
                //             ...
                //             {
                //                 value: string,
                //                 lang: string
                //             },
                //             {
                //                 value: string
                //             }
                //                     ...
                //                 ],
                //     },
                //     {
                //         iri: url,
                //         broader: [
                //             ...
                //             url,
                //             ...
                //                 ]
                //     }
                //             {
                //         iri: url,
                //         label: [
                //             ...
                //             {
                //                 value: string,
                //                 lang: string
                //             },
                //             {
                //                 value: string
                //             }
                //                     ...
                //                 ],
                //         broader: [
                //             ...
                //             url,
                //             ...
                //                 ]
                //     }
                //         ...
                //     ]
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(category => {
                    if (category.iri !== undefined) {
                        triples.push(Mustache.render(
                            '<{{{uid}}}> skos:broader <{{{iri}}}> . ',
                            {
                                uid: uid,
                                iri: category.iri
                            }
                        ));
                        if (category.label) {
                            if (Array.isArray(category.label)) {
                                vector = category.label;
                            } else {
                                vector = [];
                                vector.push(category.label);
                            }
                            vector.forEach(p => {
                                if (p.lang && p.value) {
                                    triples.push(Mustache.render(
                                        '<{{{iri}}}> rdfs:label """{{{value}}}"""@{{{lang}}} . ',
                                        {
                                            iri: category.iri,
                                            value: p.value.replace(/"/g, "\\\"").replace(/(\r\n|\n|\r)/gm, ""),
                                            lang: p.lang
                                        }
                                    ));
                                } else {
                                    throw new Error('Category label malformed');
                                }
                            });
                        }
                        if (category.broader) {
                            let aux;
                            if (Array.isArray(category.broader)) {
                                aux = category.broader;
                            } else {
                                aux = [];
                                aux.push(category.broader);
                            }
                            aux.forEach(broader => {
                                triples.push(Mustache.render(
                                    '<{{{iri}}}> skos:broader <{{{broader}}}> . ',
                                    {
                                        iri: category.iri,
                                        broader: broader
                                    }
                                ));
                                triples.push(Mustache.render(
                                    '<{{{broader}}}> skos:narrower <{{{iri}}}> . ',
                                    {
                                        iri: category.iri,
                                        broader: broader
                                    }
                                ));
                            });
                        }
                    }
                });
                break;
            case 'distractors':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(ele => {
                    if (ele['value'] && ele['lang'])
                        triples.push(Mustache.render(
                            '<{{{uid}}}> chesto:distractor """{{{v}}}"""@{{{lang}}} . ',
                            {
                                uid: uid,
                                v: ele['value'],
                                lang: ele['lang']
                            }
                        ));
                });
                break;
            case 'correct':
                if (Array.isArray(p4R[key])) {
                    vector = p4R[key];
                } else {
                    vector = [];
                    vector.push(p4R[key]);
                }
                vector.forEach(ele => {
                    if (typeof ele == 'boolean' || ele["value"] && ele["lang"])
                        triples.push(Mustache.render(
                            '<{{{uid}}}> chesto:correct {{{d}}} . ',
                            {
                                uid: uid,
                                d: typeof ele == 'boolean' ?
                                    ele :
                                    Mustache.render(
                                        '"""{{{dd}}}"""@{{{lang}}}',
                                        {
                                            dd: ele["value"],
                                            lang: ele["lang"]
                                        }
                                    )
                            }
                        ));
                });
                break;
            case 'singleSelection':
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:singleSelection {{{d}}} . ',
                    {
                        uid: uid,
                        d: p4R[key]
                    }
                ));
                break;
            default:
                break;
        }
    }
    return triples;
}

function insertFeature(p4R) {
    const uid = p4R.id;
    const triples = fields(uid, p4R);
    triples.push(Mustache.render(
        '<{{{uid}}}> a <http://chest.gsic.uva.es/ontology/Feature> . ',
        {
            uid: uid
        }
    ));
    return spliceQueries('insertData', [{ id: 'http://chest.gsic.uva.es', triples: triples }]);
}

function addInfoFeature(uid, p4R) {
    const triples = fields(uid, p4R);
    return spliceQueries('insertData', [{ id: 'http://chest.gsic.uva.es', triples: triples }]);
}

function deleteInfoFeature(uid, p4R) {
    const triples = fields(uid, p4R);
    return spliceQueries('deleteData', [{ id: 'http://chest.gsic.uva.es', triples: triples }]);
}


/*
    triples = [
        ...
        {
            id: graph0
            triples: [
                label: ...,
                comment: ...,
            ]
        },
        ...
    ]
    */
function spliceQueries(action, triples) {
    let head;
    switch (action) {
        case 'insertData':
            head = 'INSERT DATA { ';
            break;
        case 'deleteData':
            head = 'DELETE DATA { ';
            break;
        default:
            throw new Error('Error in action');
    }

    const requests = [];
    triples.forEach(graphData => {
        let i = 0;
        const parts = [];
        const graph = Mustache.render('GRAPH <{{{id}}}> {', { id: graphData.id });
        graphData.triples.forEach(triple => {
            if (triple.length + graph.length + 2 >= 1000) {
                throw new Error(Mustache.render('{{{triple}}} is too long!!', { triple: triple }));
            } else {
                if (parts[i] === null || parts[i] === undefined) {
                    parts[i] = [];
                    parts[i].push(triple);
                } else {
                    let tama = 0;
                    parts[i].forEach(v => tama += v.length);
                    if (tama + triple.length + 2 >= 1000) {
                        i += 1;
                        parts[i] = [];
                        parts[i].push(triple);
                    } else {
                        parts[i].push(triple);
                    }
                }
            }
        });
        parts.forEach(part => {
            requests.push(Mustache.render(
                '{{{graph}}}{{{part}}}',
                {
                    graph: graph,
                    part: function () {
                        let o = '';
                        part.forEach(p => o = Mustache.render('{{{o}}}{{{p}}}', { o: o, p: p }));
                        return o;
                    }
                }));
        });
    });
    const out = [];
    while (requests.length > 0) {
        let r = requests.shift();
        const s = [];
        let t = r.length;
        for (let i = 0, tama = requests.length; i < tama; i++) {
            if (t + requests[i].length < 1000) {
                t += requests[i].length;
                s.push(i);
            }
        }
        s.forEach(position => {
            r = Mustache.render('{{{r}}}} {{{n}}}', { r: r, n: requests.splice(position, 1) });
        });
        const query = Mustache.render('{{{head}}}{{{r}}}}}', { head: head, r: r });
        winston.info(query);
        out.push(encodeURIComponent(query));
    }
    return out;
}

function isAuthor(uid, author) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            <{{{id}}}> dc:creator <{{{author}}}> .\
        }',
        {
            id: uid,
            author: author
        }
    ).replace(/\s+/g, ' '));
}

function hasTasksOrInItinerary(uid) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            ?s chesto:hasFeature <{{{id}}}>\
        }',
        { id: uid }
    ).replace(/\s+/g, ' '));
}

function taskInIt0(uid) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            ?s rdf:next <{{{id}}}>\
        }',
        { id: uid }
    ).replace(/\s+/g, ' '));
}

function taskInIt1(uid) {
    return encodeURIComponent(Mustache.render(
        'ASK {\
            ?s rdf:first <{{{id}}}>\
        }',
        { id: uid }
    ).replace(/\s+/g, ' '));
}

function deleteObject(uid) {
    const query = Mustache.render(
        'WITH <http://chest.gsic.uva.es> DELETE WHERE {\
            <{{{id}}}> ?p ?o .\
        }',
        { id: uid }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return encodeURIComponent(query);
}

function getAllInfo(uid) {
    return encodeURIComponent(Mustache.render(
        'SELECT ?p ?o WHERE {\
            <{{{id}}}> ?p ?o .\
        }',
        { id: uid }
    ).replace(/\s+/g, ' '));
}

function checkInfo(uid, p4R) {
    const triples = [];
    for (const key in p4R) {
        switch (key) {
            case 'lat':
            case 'long':
                triples.push(Mustache.render(
                    '<{{{uid}}}> geo:{{{key}}} {{{value}}} . ',
                    {
                        uid: uid,
                        key: key,
                        value: p4R[key]
                    }
                ));
                break;
            case 'label':
            case 'comment':
                triples.push(Mustache.render(
                    '<{{{uid}}}> rdfs:{{{key}}} """{{{value}}}"""@{{{lang}}} . ',
                    {
                        uid: uid,
                        key: key,
                        value: p4R[key].value,
                        lang: p4R[key].lang
                    }
                ));
                break;
            case 'image':
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:image <{{{image}}}> . ',
                    {
                        uid: uid,
                        image: p4R[key].image
                    }));
                if (p4R[key].license) {
                    triples.push(Mustache.render(
                        '<{{{image}}}> dc:license {{{license}}} . ',
                        {
                            image: p4R[key].image,
                            license: validURL(p4R[key].license) ?
                                Mustache.render('<{{{l}}}>', { l: p4R[key].license }) :
                                Mustache.render('"{{{l}}}"', { l: p4R[key].license })
                        }));
                }
                break;
            case 'thumbnail':
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:thumbnail <{{{image}}}> . ',
                    {
                        uid: uid,
                        image: p4R[key].image
                    }));
                triples.push(Mustache.render(
                    '<{{{image}}}> a chesto:Image . ',
                    {
                        image: p4R[key].image
                    }
                ));
                if (p4R[key].license) {
                    triples.push(Mustache.render(
                        '<{{{image}}}> dc:license {{{license}}} . ',
                        {
                            image: p4R[key].image,
                            license: validURL(p4R[key].license) ?
                                Mustache.render('<{{{l}}}>', { l: p4R[key].license }) :
                                Mustache.render('"{{{l}}}"', { l: p4R[key].license })
                        }));
                }
                break;
            case 'aT':
                var type;
                switch (p4R[key]) {
                    case 'mcq':
                    case 'tf':
                    case 'photo':
                    case 'multiplePhotos':
                    case 'video':
                    case 'photoText':
                    case 'videoText':
                    case 'multiplePhotosText':
                    case 'text':
                    case 'noAnswer':
                        type = p4R[key];
                        break;
                    default:
                        throw new Error('Problem with the client aT');
                }
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:answerType chesto:{{{aT}}} . ',
                    {
                        uid: uid,
                        aT: type
                    }
                ));
                break;
            case 'inSpace':
                var v = [];
                if (!Array.isArray(p4R[key])) {
                    v.push(p4R[key]);
                } else {
                    v = p4R[key];
                }
                v.forEach(spa => {
                    let value;
                    switch (spa) {
                        case 'physical':
                            value = 'PhysicalSpace';
                            break;
                        case 'virtual':
                            value = 'VirtualSpace';
                            break;
                        default:
                            throw new Error('Problem with the client aT');
                    }
                    triples.push(Mustache.render(
                        '<{{{uid}}}> chesto:inSpace chesto:{{{space}}} . ',
                        {
                            uid: uid,
                            space: value
                        }
                    ));
                });
                break;
            case 'hasFeature':
                triples.push(Mustache.render(
                    '<{{{uid}}}> chesto:hasFeature <{{{idFeature}}}> . ',
                    {
                        uid: uid,
                        idFeature: p4R[key]
                    }
                ));
                break;
            default:
                throw new Error('401');
        }
    }

    let out = 'ASK { ';
    triples.forEach(triple => {
        out = Mustache.render('{{{o}}}{{{t}}}', { o: out, t: triple });
    });
    return encodeURIComponent(Mustache.render('{{{o}}}}', { o: out }));
}

function getTasksFeature(idFeature) {
    return encodeURIComponent(Mustache.render(
        'SELECT DISTINCT ?task ?at ?space ?author ?label ?comment ?distractor ?correct ?singleSelection WHERE {\
            ?task \
                a chesto:LearningTask ; \
                chesto:hasFeature <{{{feature}}}> ; \
                chesto:inSpace ?space ; \
                chesto:answerType ?at ; \
                rdfs:comment ?comment ; \
                dc:creator ?author . \
            OPTIONAL {?task rdfs:label ?label .} \
            OPTIONAL {?task chesto:distractor ?distractor .} \
            OPTIONAL {?task chesto:correct ?correct .} \
            OPTIONAL {?task chesto:singleSelection ?singleSelection .} \
        }',
        {
            feature: idFeature
        }).replace(/\s+/g, ' '));
}

function insertTask(p4R) {
    const uid = p4R.id;
    const triples = fields(uid, p4R);
    triples.push(Mustache.render(
        '<{{{uid}}}> a <http://chest.gsic.uva.es/ontology/LearningTask> . ',
        {
            uid: uid
        }
    ));
    return spliceQueries('insertData', [{ id: 'http://chest.gsic.uva.es', triples: triples }]);
}

function getInfoTask(idTask) {
    return encodeURIComponent(Mustache.render(
        'SELECT DISTINCT ?feature ?at ?space ?author ?label ?comment ?distractor ?correct WHERE {\
            <{{{task}}}> \
                a chesto:LearningTask ; \
                chesto:hasFeature ?feature ; \
                chesto:inSpace ?space ; \
                chesto:answerType ?at ; \
                rdfs:comment ?comment ; \
                dc:creator ?author . \
            OPTIONAL {<{{{task}}}> rdfs:label ?label .} \
            OPTIONAL {<{{{task}}}> chesto:distractor ?distractor .} \
            OPTIONAL {<{{{task}}}> chesto:correct ?correct .} \
            OPTIONAL {<{{{task}}}> chesto:singleSelection ?singleSelection .} \
        }',
        {
            task: idTask
        }).replace(/\s+/g, ' '));
}

function checkDataSparql(points) {
    let query = 'ASK {';
    for (let point of points) {
        if (point.tasks.length > 0) {
            for (let task of point.tasks) {
                // query = Mustache.render(
                //     '{{{q}}} chestd:{{{t}}} chesto:hasPoi chestd:{{{p}}} .',
                //     {
                //         q: query,
                //         t: task.replace('http://chest.gsic.uva.es/data/', ''),
                //         p: point.idPoi.replace('http://chest.gsic.uva.es/data/', '')
                //     }
                // );
                query = Mustache.render(
                    '{{{q}}} <{{{t}}}> chesto:hasFeature <{{{p}}}> .',
                    {
                        q: query,
                        t: task,
                        p: point.idFeature
                    }
                );
            }
        } else {
            query = Mustache.render(
                // '{{{q}}} chestd:{{{p}}} a chesto:POI .',
                // {
                //     q: query,
                //     p: point.idPoi.replace('http://chest.gsic.uva.es/data/', '')
                // }
                '{{{q}}} <{{{p}}}> a chesto:Feature .',
                {
                    q: query,
                    p: point.idFeature
                }
            );
        }
    }
    winston.info(Mustache.render('{{{q}}} }', { q: query }));
    return encodeURIComponent(Mustache.render('{{{q}}} }', { q: query }));
}

function insertItinerary(itinerary) {
    //Inserto en el grafo de chest y creo el grafo propio del itinerario
    const grafoComun = [], grafoItinerario = [];
    grafoComun.push(Mustache.render(
        '<{{{id}}}> a <http://chest.gsic.uva.es/ontology/Itinerary> . ',
        {
            id: itinerary.id
        }
    ));
    grafoComun.push(Mustache.render(
        '<{{{id}}}> a <{{{typeIt}}}> . ',
        {
            id: itinerary.id,
            typeIt: itinerary.type
        }
    ));
    itinerary.labels.forEach(l => {
        if (Array.isArray(l.value)) {
            l.value.forEach(v => {
                grafoComun.push(Mustache.render(
                    '<{{{id}}}> rdfs:label """{{{label}}}"""@{{{lang}}} . ',
                    {
                        id: itinerary.id,
                        label: v,
                        lang: l.lang
                    }
                ));
            });
        } else {
            grafoComun.push(Mustache.render(
                '<{{{id}}}> rdfs:label """{{{label}}}"""@{{{lang}}} . ',
                {
                    id: itinerary.id,
                    label: l.value,
                    lang: l.lang
                }
            ));
        }
    });
    itinerary.comments.forEach(c => {
        if (Array.isArray(c.value)) {
            c.value.forEach(v => {
                grafoComun.push(Mustache.render(
                    '<{{{id}}}> rdfs:comment """{{{comment}}}"""@{{{lang}}} . ',
                    {
                        id: itinerary.id,
                        comment: v,
                        lang: c.lang
                    }
                ));
            });
        } else {
            grafoComun.push(Mustache.render(
                '<{{{id}}}> rdfs:comment """{{{comment}}}"""@{{{lang}}} . ',
                {
                    id: itinerary.id,
                    comment: c.value,
                    lang: c.lang
                }
            ));
        }
    });
    grafoComun.push(Mustache.render(
        '<{{{id}}}> dc:creator <{{{author}}}> . ',
        {
            id: itinerary.id,
            author: itinerary.author,
        }
    ));
    let prevFeature = '';
    for (let index = 0, tama = itinerary.points.length; index < tama; index++) {
        const point = itinerary.points[index];
        grafoItinerario.push(Mustache.render(
            '<{{{id}}}> <http://chest.gsic.uva.es/ontology/hasFeature> <{{{feature}}}> . ',
            {
                id: itinerary.id,
                feature: point.idFeature,
            }
        ));
        if (itinerary.type === 'order' && index === 0) {
            grafoItinerario.push(Mustache.render(
                '<{{{id}}}> rdf:first <{{{firstPoint}}}> . ',
                {
                    id: itinerary.id,
                    firstPoint: point.idFeature,
                }
            ));
            prevFeature = point.idFeature;
        }
        if (itinerary.type === 'order' && index > 0) {
            grafoItinerario.push(Mustache.render(
                '<{{{prev}}}> rdf:next <{{{current}}}> . ',
                {
                    prev: prevFeature,
                    current: point.idFeature,
                }
            ));
            prevFeature = point.idFeature;
        }
        if (point.altCommentFeature !== null) {
            grafoItinerario.push(Mustache.render(
                '<{{{id}}}> rdfs:comment "{{{comment}}}" . ',
                {
                    id: point.idFeature,
                    comment: point.altCommentFeature,
                }
            ));
        }
        let prevTask = '';
        for (let indexTask = 0, tamaTask = point.tasks.length; indexTask < tamaTask; indexTask++) {
            const task = point.tasks[indexTask];
            grafoItinerario.push(Mustache.render(
                '<{{{idFeature}}}> <http://chest.gsic.uva.es/ontology/hasTask> <{{{idTask}}}> . ',
                {
                    idFeature: point.idFeature,
                    idTask: task,
                }
            ));
            if (itinerary.type !== 'noOrder' && indexTask === 0) {
                grafoItinerario.push(Mustache.render(
                    '<{{{idFeature}}}> rdf:first <{{{idTask}}}> . ',
                    {
                        idFeature: point.idFeature,
                        idTask: task,
                    }
                ));
                prevTask = task;
            }
            if (itinerary.type !== 'noOrder' && indexTask > 0) {
                grafoItinerario.push(Mustache.render(
                    '<{{{preTask}}}> rdf:next <{{{currentTask}}}> . ',
                    {
                        preTask: prevTask,
                        currentTask: task,
                    }
                ));
                prevTask = task;
            }
        }
    }
    const t = new Date();
    grafoComun.push(Mustache.render(
        '<{{{id}}}> <http://chest.gsic.uva.es/ontology/creation> "{{{time}}}"^^xsd:dateTime . ',
        {
            id: itinerary.id,
            time: t.toISOString()
        }));

    grafoComun.push(Mustache.render(
        '<{{{id}}}> <http://chest.gsic.uva.es/ontology/update> "{{{time}}}"^^xsd:dateTime . ',
        {
            id: itinerary.id,
            time: t.toISOString()
        }));

    return spliceQueries('insertData', [
        {
            id: 'http://chest.gsic.uva.es',
            triples: grafoComun
        },
        {
            id: itinerary.id,
            triples: grafoItinerario
        }
    ]);
}

function getAllItineraries() {
    return encodeURIComponent(
        'SELECT ?it ?type ?label ?comment ?author ?authorLbl ?update WHERE { \
            ?it \
                a chesto:Itinerary ; \
                a ?type ; \
                rdfs:label ?label ; \
                rdfs:comment ?comment ; \
                <http://chest.gsic.uva.es/ontology/update> ?update ; \
                dc:creator ?author . \
                OPTIONAL {?author rdfs:label ?authorLbl} . \
            }'.replace(/\s+/g, ' ')
    );
}

function getFeaturesItinerary(itinerary) {
    return encodeURIComponent(
        Mustache.render(
            'SELECT DISTINCT ?feature ?first ?next ?lat ?long ?label ?comment ?commentIt ?author WHERE { \
                GRAPH <{{{itinerario}}}> { \
                    <{{{itinerario}}}> chesto:hasFeature ?feature . \
                    OPTIONAL { <{{{itinerario}}}> rdf:first ?first . } \
                    OPTIONAL {?feature rdf:next ?next . } \
                    OPTIONAL {?feature rdfs:comment ?commentIt . } \
                } . \
                GRAPH <http://chest.gsic.uva.es> { \
                ?feature \
                    geo:lat ?lat ; \
                    geo:long ?long ; \
                    rdfs:label ?label ; \
                    rdfs:comment ?comment ; \
                    dc:creator ?author . \
                } \
            }',
            {
                itinerario: itinerary
            }).replace(/\s+/g, ' '));
}

function getTasksFeatureIt(it, feature) {
    return encodeURIComponent(
        Mustache.render(
            'SELECT DISTINCT ?task ?aT ?label ?comment ?first ?next WHERE { \
                <{{{feature}}}> chesto:hasTask ?task . \
                ?task \
                    chesto:answerType ?aT ; \
                    rdfs:comment ?comment . \
                OPTIONAL { ?task rdfs:label ?label . } \
                GRAPH <{{{it}}}> { \
                    <{{{feature}}}> chesto:hasTask ?task . \
                    OPTIONAL { <{{{feature}}}> rdf:first ?first . } \
                    OPTIONAL {?task rdf:next ?next . } \
                } \
            }',
            {
                feature: feature,
                it: it
            }
        ).replace(/\s+/g, ' ')
    );
}

function getTasksItinerary(itinerary, Feature) {
    return encodeURIComponent(
        Mustache.render(
            'SELECT DISTINCT ?task ?aT ?label ?comment ?first ?next WHERE { \
                <{{{Feature}}}> chesto:hasTask ?task . \
                ?task \
                    chesto:answerType ?aT ; \
                    rdfs:label ?label ; \
                    rdfs:comment ?comment . \
                GRAPH <{{{itinerario}}}> { \
                    <{{{Feature}}}> chesto:hasTask ?task . \
                    OPTIONAL { <{{{Feature}}}> rdf:first ?first . } \
                    OPTIONAL {?task rdf:next ?next . } \
                } \
            }',
            {
                Feature: Feature,
                itineario: itinerary
            }
        )
    );
}

function deleteItinerarySparql(itinerary) {
    const query = Mustache.render(
        'DELETE WHERE { \
            GRAPH <http://chest.gsic.uva.es> { \
                <{{{itinerario}}}> ?p ?o \
            } \
        .} \
        CLEAR GRAPH <{{{itinerario}}}>',
        {
            itinerario: itinerary
        }
    ).replace(/\s+/g, ' ');
    winston.info(query);
    return encodeURIComponent(query);
}

module.exports = {
    getInfoFeature,
    getLocationFeatures,
    getInfoFeatures,
    getCitiesWikidata,
    checkExistenceId,
    insertFeature,
    isAuthor,
    hasTasksOrInItinerary,
    deleteObject,
    getAllInfo,
    checkInfo,
    addInfoFeature,
    deleteInfoFeature,
    getTasksFeature,
    insertTask,
    getInfoTask,
    taskInIt0,
    taskInIt1,
    checkDataSparql,
    insertItinerary,
    getAllItineraries,
    getFeaturesItinerary,
    getTasksItinerary,
    deleteItinerarySparql,
    getTasksFeatureIt,
}