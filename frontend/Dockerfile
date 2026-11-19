FROM node:16.20.2-bullseye-slim AS builder
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.28-alpine
COPY --from=builder /usr/src/app/dist/frontend/ /usr/share/nginx/html/
EXPOSE 80
