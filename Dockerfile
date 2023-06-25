FROM golang:alpine as builder
RUN apk add build-base
RUN apk add git
COPY . /code
WORKDIR /code

RUN go mod init github.com/niranjankl/jenkins-pipeline-tutorial
# Run unit tests
#RUN go test

# Build app
RUN go build -o sample-app

FROM alpine

COPY --from=builder /code/sample-app /sample-app
CMD /sample-app
