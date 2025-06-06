FROM openjdk:22-jdk-slim
RUN groupadd -r spring && useradd -r -g spring spring
ARG JAR_FILE=spring-boot-application/build/libs/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]