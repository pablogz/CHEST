const { MongoClient } = require('mongodb');

const mongoName = 'bdCHEST';
const mongoAdd = 'mongodb://localhost:27017';

const client = new MongoClient(
    mongoAdd,
    {
        useNewUrlParser: true,
        useUnifiedTopology: true
    });

const DOCUMENT_INFO = 'infoUser';
const DOCUMENT_ANSWERS = 'answers';


async function getInfoUser(uid) {
    return await getDocument(uid, DOCUMENT_INFO);
}

async function getDocument(colId, id) {
    try {
        await client.connect();
        return await client.db(mongoName).collection(colId).findOne({ _id: id });
    }
    catch (error) {
        return null;
    } finally {
        client.close();
    }
}

async function setVerified(uid, v) {
    const update = {
        $set: {
            verified: v
        }
    };
    try {
        await client.connect();
        await client.db(mongoName).collection(uid).updateOne({ _id: DOCUMENT_INFO }, update);
    }
    catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function updateDocument(col, doc, obj) {
    const update = {
        $set: obj
    };
    try {
        await client.connect();
        return await client.db(mongoName).collection(col).updateOne({ _id: doc }, update);
    }
    catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function newDocument(col, doc) {
    try {
        await client.connect();
        return await client.db(mongoName).collection(col).insertOne(doc);
    }
    catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}


module.exports = {
    DOCUMENT_INFO,
    getInfoUser,
    getDocument,
    updateDocument,
    newDocument,
}