'use strict';
const cache = require('memory-cache'); // opcional, puedes quitarlo
const { Annotation, jsonEncoder: { JSON_V2 } } = require('zipkin');

const OPERATION_CREATE = 'CREATE',
      OPERATION_DELETE = 'DELETE';

class TodoController {
    constructor({ tracer, redisClient, logChannel, CACHE_TTL = 60 }) {
        this._tracer = tracer;
        this._redisClient = redisClient;
        this._logChannel = logChannel;
        this._cacheTTL = CACHE_TTL;
    }

    // GET todos con cache-aside en Redis
    async list(req, res) {
        const userID = req.user.username;
        try {
            const data = await this._getTodoData(userID);
            res.json(data.items);
        } catch (err) {
            console.error('Error listing todos', err);
            res.status(500).json({ error: err.message });
        }
    }

    // POST create + invalidar cache
    async create(req, res) {
        const userID = req.user.username;
        try {
            let data = await this._getTodoData(userID);

            const todo = {
                content: req.body.content,
                id: ++data.lastInsertedID
            };
            data.items[todo.id] = todo;

            await this._setTodoData(userID, data);

            this._logOperation(OPERATION_CREATE, userID, todo.id);

            res.json(todo);
        } catch (err) {
            console.error('Error creating todo', err);
            res.status(500).json({ error: err.message });
        }
    }

    // DELETE delete + invalidar cache
    async delete(req, res) {
        const userID = req.user.username;
        const id = req.params.taskId;
        try {
            let data = await this._getTodoData(userID);

            delete data.items[id];

            await this._setTodoData(userID, data);

            this._logOperation(OPERATION_DELETE, userID, id);

            res.status(204).send();
        } catch (err) {
            console.error('Error deleting todo', err);
            res.status(500).json({ error: err.message });
        }
    }

    _logOperation(opName, username, todoId) {
        this._tracer.scoped(() => {
            const traceId = this._tracer.id;
            this._redisClient.publish(this._logChannel, JSON.stringify({
                zipkinSpan: traceId,
                opName: opName,
                username: username,
                todoId: todoId,
            }));
        });
    }

    // Lee desde Redis primero
    _getTodoData(userID) {
        return new Promise((resolve, reject) => {
            const cacheKey = `todos:${userID}`;
            this._redisClient.get(cacheKey, (err, cached) => {
                if (err) return reject(err);

                if (cached) {
                    // devolver cache
                    return resolve(JSON.parse(cached));
                } else {
                    // inicializar si no existe
                    const data = {
                        items: {
                            '1': { id: 1, content: "Create new todo" },
                            '2': { id: 2, content: "Update me" },
                            '3': { id: 3, content: "Delete example ones" },
                        },
                        lastInsertedID: 3
                    };
                    this._setTodoData(userID, data)
                        .then(() => resolve(data))
                        .catch(reject);
                }
            });
        });
    }

    // Guarda en Redis con TTL
    _setTodoData(userID, data) {
        return new Promise((resolve, reject) => {
            const cacheKey = `todos:${userID}`;
            this._redisClient.setex(cacheKey, this._cacheTTL, JSON.stringify(data), (err) => {
                if (err) return reject(err);
                resolve();
            });
        });
    }
}

module.exports = TodoController;
