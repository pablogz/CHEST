const fetch = require('node-fetch');
const FirebaseAdmin = require('firebase-admin');
const winston = require('../../util/winston');
const { getTokenAuth, logHttp } = require('../../util/auxiliar');
const { getInfoUser } = require('../../util/bd');

const AI_SERVER_URL = process.env.AI_SERVER_URL || 'http://localhost:3001';

/**
 * POST /ai/generate-task?feature=<shortId>
 *
 * Recibe los parámetros pedagógicos opcionales del docente, llama al
 * orquestador MCP-CHv2 y devuelve la tarea generada en formato JSON.
 *
 * Requiere autenticación Firebase con rol TEACHER.
 */
async function generateTask(req, res) {
    const start = Date.now();
    try {
        const feature = req.query.feature;
        if (!feature) {
            logHttp(req, 400, 'generateTask', start);
            return res.sendStatus(400);
        }

        FirebaseAdmin.auth()
            .verifyIdToken(getTokenAuth(req.headers.authorization))
            .then(async (dToken) => {
                const { uid } = dToken;
                if (!uid) {
                    logHttp(req, 401, 'generateTask-401', start);
                    return res.sendStatus(401);
                }

                const infoUser = await getInfoUser(uid);
                if (!infoUser || !infoUser.rol.includes('TEACHER')) {
                    logHttp(req, 403, 'generateTask', start);
                    return res.sendStatus(403);
                }

                const {
                    educational_level,
                    subject_area,
                    bloom_level,
                    pedagogical_approach,
                    skills_to_develop,
                    teacher_notes,
                } = req.body ?? {};

                // El nombre del lugar viene del cliente; el shortId se usa como spatial_thing_id
                const placeDescription = req.body.placeDescription || feature;

                const aiPayload = {
                    placeDescription,
                    spatial_thing_id: feature,
                };
                if (educational_level)    aiPayload.educational_level    = educational_level;
                if (subject_area)         aiPayload.subject_area         = subject_area;
                if (bloom_level)          aiPayload.bloom_level          = bloom_level;
                if (pedagogical_approach) aiPayload.pedagogical_approach = pedagogical_approach;
                if (skills_to_develop)    aiPayload.skills_to_develop    = skills_to_develop;
                if (teacher_notes)        aiPayload.teacher_notes        = teacher_notes;

                const aiResponse = await fetch(`${AI_SERVER_URL}/api/generate-task`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(aiPayload),
                });

                if (!aiResponse.ok) {
                    const err = await aiResponse.text();
                    winston.error(`generateTask || AI server error ${aiResponse.status} || ${err}`);
                    logHttp(req, 502, 'generateTask', start);
                    return res.status(502).json({ error: 'AI server error', detail: err });
                }

                const taskJson = await aiResponse.json();
                winston.info(`generateTask || ${feature} || ${Date.now() - start}ms`);
                logHttp(req, 200, 'generateTask', start);
                return res.json(taskJson);
            })
            .catch((err) => {
                winston.error(`generateTask || auth error || ${err.message}`);
                logHttp(req, 401, 'generateTask', start);
                return res.sendStatus(401);
            });
    } catch (err) {
        winston.error(`generateTask || ${err.message}`);
        logHttp(req, 500, 'generateTask', start);
        return res.sendStatus(500);
    }
}

module.exports = { generateTask };
