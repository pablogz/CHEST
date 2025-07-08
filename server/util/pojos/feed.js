class Feed {
    constructor(data) {
        if (data !== null && typeof data === 'object') {
            this._id = data.id !== undefined && typeof data.id === 'string' ? data.id : null;
            // this._feeder = data.feeder !== undefined && Array.isArray(data.feeder) ? data.feeder : null;
            this._labels = data.labels !== undefined && Array.isArray(data.labels) ? data.labels : [];
            this._comments = data.comments !== undefined && Array.isArray(data.comments) ? data.comments : [];
            this._subscriptors = data.subscriptors !== undefined && Array.isArray(data.subscriptors) ? data.subscriptors : [];
            this._password = data.password !== undefined && typeof data.password === 'string' ? data.password : null;
            this._date = data.date !== undefined && typeof data.date === 'string' ? data.date : null;
        } else {
            throw new Error("Data is not an object");
        }
    }

    get id() { return this._id; }
    get labels() { return this._labels; }
    get comments() { return this._comments; }
    get subscriptors() { return this._subscriptors; }
    get password() { return this._password; }
    get date() {return this._date; }

    setLabels(labels) {
        this._labels = Array.isArray(labels) ? labels : null;
    }

    addLabel(label) {
        this._labels.push(label);
    }

    setComments(comments) {
        this._comments = Array.isArray(comments) ? comments : null;
    }

    addComment(comment) {
        this._comments.push(comment);
    }

    addSubscriptor(subscriptor) {
        if (typeof subscriptor === 'string') {
            const index = this._subscriptors.indexOf(subscriptor);
            if (index == -1) {
                this._subscriptors.push(subscriptor);
            }
        }
    }

    removeSubscriptor(subscriptor) {
        if (typeof subscriptor === 'string') {
            this._subscriptors = this._subscriptors.filter(ele => ele.id != subscriptor);
        }
    }

    setPassword(password) {
        this._password = typeof password === 'string' ? password : null;
    }

    toSubscriber() {
        return {
            id: this._id,
            labels: this._labels,
            comments: this._comments,
        }
    }
}

class FeedSubscriptor {
    constructor(data) {
        if (data !== null && typeof data === 'object') {
            this._idFeed = data.idFeed !== undefined && typeof data.idFeed === 'string' ? data.idFeed : null;
            this._idOwner = data.idOwner !== undefined && typeof data.idOwner === 'string' ? data.idOwner : null;
            this._date = data.date !== undefined && typeof data.date === 'string' ? data.date : (new Date.now()).toISOString();
            this._answers = data.answers !== undefined && Array.isArray(data.answers) ? data.answers : [];
        } else {
            Error('Data is not an object');
        }
    }

    get idFeed() { return this._idFeed }
    set idFeed(v) {
        this._idFeed = v !== undefined && typeof v === 'string' ? v : this._idFeed;
    }

    get idOwner() { return this._idOwner }
    set idOwner(v) {
        this._idOwner = v !== undefined && typeof v === 'string' ? v : this._idOwner;
    }

    get date() { return this._date }
    set date(v) {
        this._date = v !== undefined && typeof v === 'string' ? v : this._date;
    }

    get answers() { return this._answers }
    set answers(v) {
        this._answers = v !== undefined && Array.isArray(v) ? v : this._answers;
    }
}

module.exports = {
    Feed,
    FeedSubscriptor,
}