const Mustache = require('mustache');

class ElementOSM {
    constructor(element) {
        this._id = (element.id).toString();
        this._type = element.type;
        let bounds;
        switch (element.type) {
            case 'node':
                this._lat = element.lat;
                this._long = element.lon;
                break;
            case 'way':
                bounds = element.bounds;
                this._lat = (bounds.maxlat + bounds.minlat) / 2;
                this._long = (bounds.maxlon + bounds.minlon) / 2;
                this._geometry = element.geometry;
                break;
            case 'relation':
                bounds = element.bounds;
                this._lat = (bounds.maxlat + bounds.minlat) / 2;
                this._long = (bounds.maxlon + bounds.minlon) / 2;
                this._members = element.members;
                break;
            default:
                throw Error('Element\'s type undefined');
        }
        this._name = element.tags.name;

        this._author = element.user != undefined ? `OSM - ${element.user}` : 'OSM';

        const tags = element.tags;
        this._tags = tags;
        const labels = [];
        for (const key in tags) {
            switch (key) {
                case 'wikipedia':
                    if (tags.wikipedia.split(":").length > 1) {
                        this._wikipedia = Mustache.render(
                            'https://{{{lang}}}.wikipedia.org/wiki/{{{value}}}',
                            {
                                lang: tags.wikipedia.split(":")[0],
                                value: tags.wikipedia.split(":")[1].replace(/\s+/g, '_')
                            }
                        );
                    } else {
                        this._wikipedia = 'https://wikipedia.org/wiki/' + tags.wikipedia.replace(/\s+/g, '_');
                    }

                    if (this._wikipedia !== undefined) {
                        this._dbpedia = wikipedia2dbpedia(this._wikipedia);
                    }
                    break;
                case 'wikidata':
                    this._wikidata = "wd:" + tags.wikidata;
                    break;
                default:
                    if (key.includes('name')) {
                        if (key.includes(':')) {
                            const lang = key.split(':')[1];
                            if (lang.match(/^\D/) !== null && lang.length === 2) {
                                labels.push(
                                    {
                                        value: tags[key],
                                        lang: lang
                                    }
                                );
                            }
                        } else {
                            if (key === 'name') {
                                labels.push({ value: tags[key] });
                            }
                        }
                    }
                    break;
            }
        }
        if (labels.length > 0) {
            this._labels = labels;
        } else {
            this._labels = { value: this._tags.short_name == undefined ? this._name === undefined ? this._id : this._name : this._tags.short_name };
        }
    }


    get license() { return 'The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.'; }
    get id() { return this._id; }
    get type() { return this._type; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get geometry() { return this.type == 'way' ? this._geometry : [{ lat: this._lat, lon: this._long }]; }
    get name() { return this._tags.short_name == undefined ? this._name === undefined ? this._id : this._name : this._tags.short_name; }
    get wikipedia() { return this._wikipedia; }
    get dbpedia() { return this._dbpedia; }
    get wikidata() { return this._wikidata; }
    get tags() { return this._tags; }
    get author() { return this._author; }
    get labels() { return this._labels; }

    toChestMap() {
        return {
            id: this.id,
            lat: this.lat,
            lng: this.long,
            provider: 'osm',
            geometry: this.geometry,
            tags: this.tags,
            labels: this.labels,
            license: this.license,
            author: this.author,
        };
    }

    toChestFeature() {
        return {
            id: this.id,
            lat: this.lat,
            long: this.long,
            labels: this.labels,
            author: this.author,
            geometry: this.geometry,
            members: this.members,
            license: this.license,
            wikipedia: this.wikipedia,
            tags: this.tags
        };
    }
}

function wikipedia2dbpedia(wikipediaURL) {
    return wikipediaURL
        .replace(/\s+/g, '_')
        .replace('https', 'http')
        .replace('wikipedia', 'dbpedia')
        .replace('wiki', 'resource');
}

module.exports = {
    ElementOSM
}