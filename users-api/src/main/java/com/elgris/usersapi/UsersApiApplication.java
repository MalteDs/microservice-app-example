package com.elgris.usersapi;

import com.elgris.usersapi.security.JwtAuthenticationFilter;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@SpringBootApplication
@EnableCaching
public class UsersApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(UsersApiApplication.class, args);
	}

	@Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
		RedisTemplate<String, Object> template = new RedisTemplate<>();
		template.setConnectionFactory(connectionFactory);

		template.setKeySerializer(new StringRedisSerializer());
		template.setHashKeySerializer(new StringRedisSerializer());
		template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
		template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());

		template.afterPropertiesSet();
		return template;
    }

	@Bean
	public CacheManager cacheManager(RedisTemplate<String, Object> redisTemplate) {
		// RedisCacheManager de Spring Data Redis
		RedisCacheManager cacheManager = new RedisCacheManager(redisTemplate);
		// tiempo de vida por defecto en segundos
		cacheManager.setDefaultExpiration(60);
		return cacheManager;
	}

}

