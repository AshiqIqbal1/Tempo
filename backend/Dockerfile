FROM golang:alpine
RUN apk add --no-cache gcc musl-dev taglib-dev zlib-dev ca-certificates ffmpeg
WORKDIR /app
ENV GOTOOLCHAIN=auto
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /usr/local/bin/tempo ./cmd/server
EXPOSE 8081
ENTRYPOINT ["tempo"]
