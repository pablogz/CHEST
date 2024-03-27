const urlClient = 'https://chest.gsic.uva.es';
const urlServer = 'https://chest.gsic.uva.es/server';
const addrSparql = '127.0.0.1';
const serverPort = 11110;
const portSparql = 8890;
const localSPARQL = `http://${addrSparql}:${portSparql}/sparql`;
const userSparql = 'pablo';
const passSparql = 'pablo';
const tokenCraft = '6d8097f8-9fff-40a2-9043-bd57fe89bcb3';
const primaryGraph = '<http://chest.gsic.uva.es>';

// const addrOPA = 'https://overpass-api.de/api/interpreter';
// const portOPA = 443;

const addrOPA = 'https://dev-chest.gsic.uva.es/overpass/interpreter';
const portOPA = 443;

// const addrOPA = 'http://10.0.104.91/api/interpreter';
// const portOPA = 80;

const mongoName = 'bdCHEST2';
const mongoAdd = 'mongodb://localhost:27017';

module.exports = {
    urlClient,
    urlServer,
    addrSparql,
    portSparql,
    localSPARQL,
    userSparql,
    passSparql,
    tokenCraft,
    addrOPA,
    portOPA,
    serverPort,
    mongoName,
    mongoAdd,
    primaryGraph,
}