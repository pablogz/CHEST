const { MongoClient } = require('mongodb');

const winston = require('./winston');
const { mongoAdd, mongoName } = require('./config');
const { FeedsUser } = require('./pojos/user');
const { Feed } = require('./pojos/feed');

const client = new MongoClient(
    mongoAdd,
    {
        useNewUrlParser: true,
        useUnifiedTopology: true
    });

const DOCUMENT_INFO = 'infoUser';
const DOCUMENT_ANSWERS = 'answers';
const DOCUMENT_FEEDS = 'feeds';


async function getInfoUser(uid) {
    return await getDocument(uid, DOCUMENT_INFO);
}

async function getFeedsUser(uid) {
    return await getDocument(uid, DOCUMENT_FEEDS)
}

async function getFeed(idOwner, idFeed) {
    const feedsDocument = await getFeedsUser(idOwner);
    if (feedsDocument !== null) {
        const feedsUser = new FeedsUser(feedsDocument);
        const indexFeed = feedsUser.owner.findIndex((f) => {
            const feed = new Feed(f);
            return feed.id == idFeed;
        });
        return indexFeed > -1 ? typeof feedsUser.owner.at(indexFeed) === Feed ?
            feedsUser.owner.at(indexFeed) :
            new Feed(feedsUser.owner.at(indexFeed)) : null;
    } else {
        return null;
    }
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

// async function setVerified(uid, v) {
//     const update = {
//         $set: {
//             verified: v
//         }
//     };
//     try {
//         await client.connect();
//         await client.db(mongoName).collection(uid).updateOne({ _id: DOCUMENT_INFO }, update);
//     }
//     catch (error) {
//         winston.error(error);
//         return null;
//     } finally {
//         client.close();
//     }
// }

async function updateDocument(col, doc, obj) {
    const update = {
        $set: obj
    };
    try {
        await client.connect();
        return await client.db(mongoName).collection(col).updateOne({ _id: doc }, update);
    }
    catch (error) {
        winston.error(error);
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
        winston.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function getAnswerWithoutId(userCol, poi, task) {
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
        if (doc != null) {
            let ans;
            doc.answers.forEach(answer => {
                if (answer.idTask == task && answer.idPoi == poi) {
                    ans = answer;
                }
            });
            return ans;
        }
    } catch (error) {
        winston.error(error);
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
        winston.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function saveAnswer(userCol, feature, task, idAnswer, answerC) {
    try {
        await client.connect();
        var now = Date.now();
        return await client.db(mongoName).collection(userCol).updateOne(
            { _id: DOCUMENT_ANSWERS },
            {
                $push: {
                    answers: {
                        id: idAnswer,
                        idFeature: feature,
                        labelContainer: answerC.labelContainer,
                        idTask: task,
                        commentTask: answerC.commentTask,
                        answerType: answerC.answerType,
                        creation: now,
                        time2Complete: answerC.time2Complete,
                        finishClient: answerC.finishClient,
                        answer: answerC.answer,
                    }
                }
            },
            { upsert: true }
        );
    } catch (error) {
        winston.error(error);
        return null;
    } finally {
        client.close();
    }
}

// async function saveAnswer(idAnswer, idUser, idPoi, idTask, answer) {
//     try {
//         await client.connect();
//         var now = Date.now();
//         return await client.db(mongoName).collection(COLLECTION_ANSWERS).insertOne({
//             idAnswer: idAnswer,
//             idUser: idUser,
//             idPoi: idPoi,
//             idTask: idTask,
//             creation: now,
//             time2Complete: answer.time2Complete,
//             timestampClient: answer.timestamp,
//             hasOptionalText: answer.hasOptionalText
//         });
//     } catch (error) {
//         winston.error(error);
//         return null;
//     } finally {
//         client.close();
//     }
// }

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
        winston.error(error);
        return null;
    } finally {
        client.close();
    }
}

async function deleteCollection(userCol) {
    try {
        await client.connect();
        return await client.db(mongoName).dropCollection(userCol);
    } catch (error) {
        winston.error(error);
        return false;
    } finally {
        client.close();
    }
}

// async function getInfoFeed(feedId, isFeeder, userId) {
//     const feedDoc = await getDocument(COLLECTION_FEEDS, feedId);
//     const out = {
//         id: feedDoc._id,
//         feeder: feedDoc._feeder,
//         password: feedDoc.password,
//         update: feedDoc.update,
//         creation: feedDoc.creation,
//         labels: feedDoc.labels,
//         comments: feedDoc.comments
//     };
//     if(isFeeder) {
//         out['subscriptors'] = feedDoc.subscriptors;
//     } else {
//         feedDoc.subscriptors.forEach(element => {
//             if(element._id == userId) {
//                 out['subscriptors'] = [element];
//             }
//         });
//     }
// }

module.exports = {
    DOCUMENT_INFO,
    DOCUMENT_ANSWERS,
    getInfoUser,
    getFeedsUser,
    getFeed,
    getDocument,
    updateDocument,
    newDocument,
    checkExistenceAnswer,
    saveAnswer,
    getAnswersDB,
    getAnswerWithoutId,
    deleteCollection,
}