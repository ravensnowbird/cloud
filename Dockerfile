#===========
# Build Stage
#===========
FROM bitwalker/alpine-elixir:1.5 as build

# Copy the source folder into the Docker image
COPY rel ./rel
COPY config ./config
COPY lib ./lib
COPY mix.exs .
COPY mix.lock .

# Install dependencies and build Release
RUN export MIX_ENV=prod && \
    mix deps.get && \
    mix release

# Extract Release archive to /rel for copying in next stage
RUN APP_NAME="hello_world" && \
    RELEASE_DIR=`ls -d _build/prod/rel/$APP_NAME/releases/*/` && \
    mkdir /export && \
    tar -xf "$RELEASE_DIR/$APP_NAME.tar.gz" -C /export

# Create a self-signed certificate
RUN apk add --no-cache openssl && \
    mkdir /cert && \
    openssl req -newkey rsa:2048 -nodes -keyout "/cert/hello_world.key" -x509 -days 365 -out "/cert/hello_world.crt" -subj "/C=NL/ST= /L= /O= /CN= "

#================
# Deployment Stage
#================
FROM pentacent/alpine-erlang-base:latest

# Set environment variables and expose port
EXPOSE 8080
ENV REPLACE_OS_VARS=true
# ENV APP_PORT=8080

# Copy and extract .tar.gz Release file from the previous stage
COPY --from=build /export/ .

RUN mkdir ./cert
COPY --from=build /cert/ ./cert

# Change user
USER default

# Set default entrypoint and command
ENTRYPOINT ["/opt/app/bin/hello_world"]
CMD ["foreground"]
