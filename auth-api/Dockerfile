FROM golang:1.24.7-alpine AS builder
WORKDIR /src
COPY . .
RUN go mod download && go build -o auth-api

FROM alpine:latest
WORKDIR /app
COPY --from=builder /src/auth-api .
EXPOSE 8080
CMD ["./auth-api"]
