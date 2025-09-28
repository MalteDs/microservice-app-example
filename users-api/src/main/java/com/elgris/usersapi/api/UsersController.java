package com.elgris.usersapi.api;

import com.elgris.usersapi.models.User;
import com.elgris.usersapi.repository.UserRepository;
import io.jsonwebtoken.Claims;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.TimeUnit;

@RestController()
@RequestMapping("/users")
public class UsersController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;


    @RequestMapping(value = "/", method = RequestMethod.GET)
    public List<User> getUsers() {
        String key = "users:all";
        List<User> cachedUsers = (List<User>) redisTemplate.opsForValue().get(key);
        if (cachedUsers != null) {
            return cachedUsers;
        }

        List<User> response = new LinkedList<>();
        userRepository.findAll().forEach(response::add);
        redisTemplate.opsForValue().set(key, response, 5, TimeUnit.MINUTES); // TTL 5 min
        return response;
    }

    @RequestMapping(value = "/{username}",  method = RequestMethod.GET)
    public User getUser(HttpServletRequest request, @PathVariable("username") String username) {

        Object requestAttribute = request.getAttribute("claims");
        if((requestAttribute == null) || !(requestAttribute instanceof Claims)){
            throw new RuntimeException("Did not receive required data from JWT token");
        }

        Claims claims = (Claims) requestAttribute;

        if (!username.equalsIgnoreCase((String)claims.get("username"))) {
            throw new AccessDeniedException("No access for requested entity");
        }

        String key = "users:" + username;
        User cachedUser = (User) redisTemplate.opsForValue().get(key);
        if (cachedUser != null) {
            return cachedUser;
        }

        User user = userRepository.findOneByUsername(username);
        if (user != null) {
            redisTemplate.opsForValue().set(key, user, 5, TimeUnit.MINUTES); // TTL 5 min
        }
        return user;
    }

}
