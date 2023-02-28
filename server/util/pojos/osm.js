const Mustache = require('mustache');

class ElementOSM {
    constructor(element) {
        this._id = "OSM-" + element.id;
        this._type = element.type;
        switch (element.type) {
            case 'node':
                this._lat = element.lat;
                this._long = element.lon;
                break;
            case 'way':
                var bounds = element.bounds;
                this._lat = (bounds.maxlat + bounds.minlat) / 2;
                this._long = (bounds.maxlon + bounds.minlon) / 2;
                this._geometry = element.geometry;
                break;
            default:
                throw Error('Element\'s type undefined');
        }
        this._name = element.tags.name;

        const tags = element.tags;

        if (tags.wikipedia !== undefined) {
            if (tags.wikipedia.split(":").length > 1) {
                this._wikipedia = Mustache.render(
                    'https://{{{lang}}}.wikipedia.org/wiki/{{{value}}}',
                    {
                        lang: tags.wikipedia.split(":")[0],
                        value: tags.wikipedia.split(":")[1]
                    }
                );
            } else {
                this._wikipedia = 'https://wikipedia.org/wiki/' + tags.wikipedia;
            }
        }
        if (tags.wikidata !== undefined) {
            this._wikidata = "wd:" + tags.wikidata;
        }
        this._tags = tags;
    }

    get license() { return 'The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.'; }
    get id() { return this._id; }
    get type() { return this._type; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get geometry() { return this.type == 'way' ? this._geometry : [{ lat: this._lat, lon: this._long }]; }
    get name() { return this._name === undefined ? this._id : this._name + " " + this._id; }
    get wikipedia() { return this._wikipedia; }
    get wikidata() { return this._wikidata; }
    get tags() { return this._tags; }

    toChestPoint() {
        return {
            poi: this.id,
            lat: this.lat,
            lng: this.long,
            geometry: this.geometry,
            label: { lang: "es", value: this.name },
            comment: { lang: "es", value: this.name },
            wikipedia: this.wikipedia,
            wikidata: this.wikidata,
            tags: this.tags,
            license: this.license,
            author: "OSM"
        }
    }
}

module.exports = {
    ElementOSM
}