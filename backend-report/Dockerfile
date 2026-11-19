FROM golang:1.25.4-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/backend-report .

FROM alpine:3.22
WORKDIR /app
COPY --from=builder /out/backend-report ./
EXPOSE 8080
USER 65534:65534
CMD ["./backend-report"]
