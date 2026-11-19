FROM maven:3.9.11-eclipse-temurin-17 AS builder
ARG VERSION=local
WORKDIR /usr/src/app
COPY ./src ./src
COPY *.xml ./
RUN mvn -B package && cp "target/sausage-store-$VERSION.jar" sausage-store.jar

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
RUN groupadd --system jaruser && useradd --system --gid jaruser jaruser \
    && install -d -o jaruser -g jaruser /logs/reports
COPY --chown=jaruser:jaruser --from=builder /usr/src/app/sausage-store.jar ./
EXPOSE 8080
USER jaruser
ENTRYPOINT ["java", "-jar", "sausage-store.jar"]
