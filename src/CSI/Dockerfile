FROM  golang:1.17-alpine

WORKDIR /app

COPY ./src .

RUN go build -mod=vendor -o ./runnable .

CMD [ "/app/runnable" ]