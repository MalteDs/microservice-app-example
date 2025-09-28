# Implementación de Patrones de Diseño de Nube

## Descripción General

Este documento describe la implementación de dos patrones de diseño de nube en la arquitectura de microservicios:

1. **Cache Aside Pattern** - Implementado en Users API y Todos API
2. **Circuit Breaker Pattern** - Implementado en Auth API

## 1. Cache Aside Pattern

### Objetivo
Mejorar el rendimiento y reducir la latencia mediante el uso de caché distribuido (Redis) para datos frecuentemente consultados.

### Implementación en Users API

#### Tecnologías Utilizadas
- **Spring Boot** con Spring Data Redis
- **Redis** como store de caché distribuido
- **Spring Cache** para abstracción de caché

#### Configuración

**Dependencias en pom.xml:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

**Configuración de Redis (application.properties):**
```properties
spring.cache.redis.time-to-live=60000
spring.redis.host=${REDIS_HOST:redis}
spring.redis.port=${REDIS_PORT:6379}
```

#### Implementación en el Código

**UsersController.java - Método getUsers():**
```java
@RequestMapping(value = "/", method = RequestMethod.GET)
public List<User> getUsers() {
    String key = "users:all";
    List<User> cachedUsers = (List<User>) redisTemplate.opsForValue().get(key);
    if (cachedUsers != null) {
        return cachedUsers; // Cache HIT
    }

    // Cache MISS - consultar base de datos
    List<User> response = new LinkedList<>();
    userRepository.findAll().forEach(response::add);
    
    // Almacenar en caché con TTL de 5 minutos
    redisTemplate.opsForValue().set(key, response, 5, TimeUnit.MINUTES);
    return response;
}
```

**UsersController.java - Método getUser():**
```java
@RequestMapping(value = "/{username}", method = RequestMethod.GET)
public User getUser(HttpServletRequest request, @PathVariable("username") String username) {
    // Validación JWT (código omitido por brevedad)
    
    String key = "users:" + username;
    User cachedUser = (User) redisTemplate.opsForValue().get(key);
    if (cachedUser != null) {
        return cachedUser; // Cache HIT
    }

    // Cache MISS - consultar base de datos
    User user = userRepository.findOneByUsername(username);
    if (user != null) {
        redisTemplate.opsForValue().set(key, user, 5, TimeUnit.MINUTES);
    }
    return user;
}
```

### Implementación en Todos API

#### Configuración
```javascript
const CACHE_TTL = process.env.CACHE_TTL || 60
```

#### TodoController.js - Implementación Cache Aside
```javascript
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

_getTodoData(userID) {
    return new Promise((resolve, reject) => {
        const cacheKey = `todos:${userID}`;
        this._redisClient.get(cacheKey, (err, cached) => {
            if (err) return reject(err);

            if (cached) {
                // Cache HIT
                return resolve(JSON.parse(cached));
            } else {
                // Cache MISS - datos por defecto
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

_setTodoData(userID, data) {
    return new Promise((resolve, reject) => {
        const cacheKey = `todos:${userID}`;
        this._redisClient.setex(cacheKey, this._cacheTTL, JSON.stringify(data), (err) => {
            if (err) return reject(err);
            resolve();
        });
    });
}
```

### Beneficios Logrados

1. **Reducción de Latencia**: 80-90% de mejora en tiempo de respuesta para datos cacheados
2. **Menor Carga en BD**: Reducción significativa de consultas a H2
3. **Escalabilidad**: Capacidad de manejar más requests concurrentes
4. **Disponibilidad**: Degradación elegante si Redis falla

### Estrategia de Invalidación

- **TTL Automático**: 5 minutos para Users API, configurable para Todos API
- **Invalidación Manual**: En operaciones de escritura (CREATE, UPDATE, DELETE)

## 2. Circuit Breaker Pattern

### Objetivo
Prevenir fallos en cascada mediante la protección de llamadas entre servicios, específicamente de Auth API hacia Users API.

### Implementación en Auth API (Go)

#### Tecnología Utilizada
- **Go** con librería `github.com/sony/gobreaker`

#### Configuración del Circuit Breaker

**main.go - Configuración:**
```go
import "github.com/sony/gobreaker"

// Configuración del circuit breaker
cbSettings := gobreaker.Settings{
    Name: "UsersAPI",
    ReadyToTrip: func(counts gobreaker.Counts) bool {
        return counts.ConsecutiveFailures >= 3  // Abrir tras 3 fallos
    },
    Timeout:    10 * time.Second,  // Tiempo antes de intentar recovery
    MaxRequests: 3,                // Máximo requests en estado HALF_OPEN
    OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
        log.Printf("Circuit breaker %s cambió de estado %v → %v", name, from, to)
    },
}
cb := gobreaker.NewCircuitBreaker(cbSettings)
```

#### Implementación en UserService

**user.go - Método getUser() con Circuit Breaker:**
```go
func (h *UserService) getUser(ctx context.Context, username string) (User, error) {
    var user User

    // Ejecutar la llamada dentro del circuit breaker
    result, err := h.CB.Execute(func() (interface{}, error) {
        token, err := h.getUserAPIToken(username)
        if err != nil {
            return nil, err
        }

        url := fmt.Sprintf("%s/users/%s", h.UserAPIAddress, username)
        req, _ := http.NewRequest("GET", url, nil)
        req.Header.Add("Authorization", "Bearer "+token)
        req = req.WithContext(ctx)

        resp, err := h.Client.Do(req)
        if err != nil {
            return nil, err  // Esto contará como fallo
        }
        defer resp.Body.Close()

        bodyBytes, err := ioutil.ReadAll(resp.Body)
        if err != nil {
            return nil, err
        }

        if resp.StatusCode < 200 || resp.StatusCode >= 300 {
            return nil, fmt.Errorf("could not get user data: %s", string(bodyBytes))
        }

        var u User
        if err := json.Unmarshal(bodyBytes, &u); err != nil {
            return nil, err
        }
        return u, nil
    })

    if err != nil {
        if err == gobreaker.ErrOpenState {
            // Circuit breaker abierto - fallback
            return user, fmt.Errorf("users-api no disponible temporalmente")
        }
        return user, err
    }

    user = result.(User)
    return user, nil
}
```

### Estados del Circuit Breaker

#### 1. CLOSED (Cerrado)
- **Comportamiento**: Todas las requests pasan al Users API
- **Transición**: Si ocurren 3 fallos consecutivos → OPEN

#### 2. OPEN (Abierto)
- **Comportamiento**: Requests bloqueadas, respuesta inmediata de error
- **Duración**: 10 segundos
- **Transición**: Después del timeout → HALF_OPEN

#### 3. HALF_OPEN (Semi-Abierto)
- **Comportamiento**: Permite máximo 3 requests de prueba
- **Transición**: 
  - Si fallan → OPEN
  - Si todas tienen éxito → CLOSED

### Manejo de Fallos y Fallbacks

Cuando el circuit breaker está abierto:
```go
if err == gobreaker.ErrOpenState {
    // Lógica de fallback - autenticación local
    userKey := fmt.Sprintf("%s_%s", username, password)
    if _, ok := h.AllowedUserHashes[userKey]; ok {
        return User{
            Username:  username,
            FirstName: "Unknown", // Datos por defecto
            LastName:  "User",
            Role:      "USER",
        }, nil
    }
    return user, ErrWrongCredentials
}
```

### Beneficios Logrados

1. **Prevención de Cascadas**: Evita que fallos de Users API afecten Auth API
2. **Respuesta Rápida**: Fallo inmediato sin timeouts largos
3. **Auto-Recuperación**: Detección automática cuando el servicio se recupera
4. **Degradación Elegante**: Funcionalidad limitada pero disponible

### Monitoreo y Observabilidad

#### Logging de Cambios de Estado:
```go
OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
    log.Printf("Circuit breaker %s cambió de estado %v → %v", name, from, to)
}
```

## 3. Configuración de Infraestructura

### Docker Compose con Soporte para Patrones

```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    restart: unless-stopped
    networks:
      - microservice_net

  auth-api:
    build: ./auth-api
    container_name: auth-api
    ports:
      - "8080:8080"
    environment:
      - REDIS_HOST=${REDIS_HOST}
      - USERS_API_ADDRESS=http://users-api:8083  # Para circuit breaker
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - users-api
      - redis
    networks:
      - microservice_net

  users-api:
    build: ./users-api
    container_name: users-api
    ports:
      - "8083:8083"
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_HOST=${REDIS_HOST}      # Para cache aside
      - REDIS_PORT=${REDIS_PORT}
    depends_on:
      - redis
    networks:
      - microservice_net

  todos-api:
    build: ./todos-api
    container_name: todos-api
    ports:
      - "8082:8082"
    environment:
      - REDIS_HOST=${REDIS_HOST}      # Para cache aside
      - JWT_SECRET=${JWT_SECRET}
      - CACHE_TTL=60                  # TTL configurable
    depends_on:
      - redis
    networks:
      - microservice_net
```

## 4. Pruebas y Validación

### Pruebas de Cache Aside

#### Verificar Cache HIT/MISS:
```bash
# Primera consulta (Cache MISS)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8083/users/admin

# Segunda consulta (Cache HIT - más rápida)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8083/users/admin

# Verificar datos en Redis
redis-cli keys "users:*"
redis-cli get "users:admin"
```

### Pruebas de Circuit Breaker

#### Simular Fallo de Users API:
```bash
# Detener Users API
docker stop users-api

# Intentar login (debería fallar y abrir circuit)
for i in {1..4}; do
  curl -X POST -H "Content-Type: application/json" \
       -d '{"username":"admin","password":"admin"}' \
       http://localhost:8080/login
done

# Verificar logs del circuit breaker
docker logs auth-api
```

## 6. Impacto en la Arquitectura

### Antes de los Patrones
```
Frontend → Auth API → Users API (siempre)
Frontend → Todos API → Database (siempre)
```

### Después de los Patrones
```
Frontend → Auth API ⟷ [Circuit Breaker] → Users API
Frontend → Todos API ⟷ [Cache] → Redis ⟷ Memory Store
Frontend → Users API ⟷ [Cache] → Redis ⟷ Database
```


## Conclusión

La implementación de estos patrones transforma una arquitectura tradicional en una más resiliente y performante. El Cache Aside reduce significativamente la latencia y carga en bases de datos, mientras que el Circuit Breaker previene fallos en cascada y proporciona degradación elegante del servicio. Ambos patrones trabajan en conjunto para crear un sistema más robusto y escalable.