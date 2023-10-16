const urlClient = 'https://dev-chest.gsic.uva.es';
const urlServer = 'https://dev-chest.gsic.uva.es/server';
const addrSparql = '127.0.0.1';
const portSparql = 8890;
const localSPARQL = `http://${addrSparql}:${portSparql}/sparql`;
const userSparql = 'pablo';
const passSparql = 'pablo';
const tokenCraft = '6d8097f8-9fff-40a2-9043-bd57fe89bcb3';

// const addrOPA = 'https://overpass-api.de/api/interpreter';
// const portOPA = 443;

const addrOPA = 'https://dev-chest.gsic.uva.es/overpass/interpreter';
const portOPA = 443;

// const addrOPA = 'http://10.0.104.91/api/interpreter';
// const portOPA = 80;

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
    portOPA
}