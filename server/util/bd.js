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

async function checkExistenceAnswer(userCol, poi, task) {
    try {
        await client.connect();
        const doc = await client.db(mongoName).collection(userCol).findOne(
            {
                $and: [
                    { _id: DOCUMENT_ANSWERS },
                    { "answers.idTask": task },
                    { "answers.idPoi": poi }
                ]
            });
        return doc != null;
    } catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function saveAnswer(userCol, poi, task, idAnswer, answerC) {
    try {
        await client.connect();
        return await client.db(mongoName).collection(userCol).updateOne(
            { _id: DOCUMENT_ANSWERS },
            {
                $push: {
                    answers: {
                        id: idAnswer,
                        idPoi: poi,
                        idTask: task,
                        lastUpdate: Date.now(),
                        answer: [answerC]
                    }
                }
            },
            { upsert: true }
        );
    } catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function getAnswersDB(userCol, allAnswers = true) {
    try {
        await client.connect();
        const docAnswers = await client.db(mongoName).collection(userCol).findOne({ _id: DOCUMENT_ANSWERS });
        if (docAnswers !== null) {
            if (docAnswers.answers !== undefined && Array.isArray(docAnswers.answers) && docAnswers.answers.length > 0) {
                if (allAnswers) {
                    return docAnswers.answers.sort((a, b) => b.lastUpdate - a.lastUpdate);
                } else {
                    return docAnswers.answers.sort((a, b) => b.lastUpdate - a.lastUpdate).splice(0, Math.min(docAnswers.answers.length, 20));
                }
            } else {
                return [];
            }
        } else {
            return docAnswers;
        }
    } catch (error) {
        console.error(error);
        return null;
    } finally {
        client.close();
    }
}

module.exports = {
    DOCUMENT_INFO,
    DOCUMENT_ANSWERS,
    getInfoUser,
    getDocument,
    updateDocument,
    newDocument,
    checkExistenceAnswer,
    saveAnswer,
    getAnswersDB,
}