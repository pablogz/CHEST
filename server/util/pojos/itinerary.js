class Itinerary {
    constructor(id, type, labels, comments, author, points) {
        this._id = typeof id === 'string' ? id : null;
        this._type = typeof id === 'string' ? type : null;
        this._labels = labels !== null && Array.isArray(labels) ?
            labels :
            [];
        this._comments = comments !== null && Array.isArray(comments) ?
            comments :
            [];
        this._author = typeof author === 'string' ? author : null;
        this._points = points !== null && Array.isArray(points) ?
            points :
            [];
    }

    static ItineraryEmpty() {
        return new Itinerary(null, null, null, null, null);
    }

    get id() { return this._id; }
    get type() { return this._type; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get author() { return this._author; }
    get points() { return this._points; }


    setId(id) { this._id = id; }
    setType(type) { this._type = type; }
    setAuthor(author) { this._author = author; }
    setPoints(points) {
        this._points = points !== null && Array.isArray(points) ?
            points :
            [];
    }
    addPoint(point) { if (point !== null) this._points.push(point); }
    setLabels(labels) {
        this._labels = labels !== null && Array.isArray(labels) ?
            labels :
            [];
    }
    addLabel(label) {
        if (label !== null &&
            label.value &&
            label.lang)
            this._points.push(label);
    }
    setComments(comments) {
        this._comments = comments !== null && Array.isArray(comments) ?
            comments :
            [];
    }
    addComment(comment) {
        if (comment !== null &&
            comment.value &&
            comment.lang)
            this._points.push(comment);
    }

}

class PointItinerary {
    constructor(id, altComment, tasks) {
        this._id = typeof id === 'string' ? id : null;
        this._altComment = typeof altComment === 'string' ? altComment : null;
        this._tasks = tasks !== null && Array.isArray(tasks) ?
            tasks :
            [];
    }

    static WitoutComment(id, tasks) {
        return new PointItinerary(id, null, tasks);
    }

    get idPoi() { return this._id; }
    get altCommentPoi() { return this._altComment; }
    get tasks() { return this._tasks; }
}

module.exports = {
    Itinerary,
    PointItinerary,
}