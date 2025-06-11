FROM golang:1.24

WORKDIR /app

# Copy go.mod and go.sum first (to leverage Docker cache)
COPY go.mod go.sum ./
RUN go mod download

# Copy rest of the files
COPY . .

RUN go build -o main .

EXPOSE 8080

CMD ["./main"]
