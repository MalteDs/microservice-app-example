
FROM node:10-alpine as build
WORKDIR /app
COPY package*.json ./
# Instala dependencias necesarias para node-sass/node-gyp
RUN apk add --no-cache python2 make g++
ENV PYTHON=/usr/bin/python2 

RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
