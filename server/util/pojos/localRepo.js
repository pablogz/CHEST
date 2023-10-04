class ElementLocalRepo {
    constructor(element) {
        this._id = element.feature;
        this._lat = element.lat;
        this._long = element.lng;
        this._labels = element.label;
        this._comments = element.comment;
        this._author = element.author;
    }

    get id() { return this._id; }
    get lat() { return this._lat; }
    get long() { return this._long; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get author() { return this._author; }

    toChestMap() {
        return {
            id: this.id,
            lat: this.lat,
            lng: this.long,
            provider: 'localRepo',
            labels: this.labels,
            comments: this.comments,
            author: this.author,
            license: 'CHEST contributors'
        };
    }
}

module.exports = { ElementLocalRepo };

// delete data {
//     graph <http://chest.gsic.uva.es> {
//     <prueba>
//          a cho:Feature ;
//          geo:lat 41.652 ;
//          geo:long  -4.723;
//          rdfs:label "prueba"@es, "test"@en ;
//          rdfs:comment "comentario de prueba"@es, "test comment"@en ;
//          dc:creator <yo> .
//     }
//     }