#
# step 1: checkout code
#
FROM alpine/git as code_checkout

# specify these using --build-arg these to use a different url/branch(or tag) to build from
ARG git_url=https://github.com/finos/waltz.git
ARG git_branch=master

WORKDIR /waltz-src
RUN git clone --single-branch --branch ${git_branch} ${git_url} .


#
# step 2: build waltz ui
#
FROM node:10.20.1 as ui_build

WORKDIR /waltz-src/waltz-ng

# install node dependencies
COPY --from=code_checkout /waltz-src/waltz-ng/package.json .
RUN npm install

# build ui
COPY --from=code_checkout /waltz-src/waltz-ng .
COPY --from=code_checkout /waltz-src/.git /waltz-src/.git
ENV BUILD_ENV=prod
RUN npm run build


#
# step 3: build waltz
#
FROM openjdk:8 as waltz_build

RUN apt-get update && apt-get install -y \
    maven \
    git

# mandatory param, eg: --build-arg maven_profiles=waltz-postgres,local-postgres
ARG maven_profiles
ARG skip_tests=true

# copy custom maven settings
COPY ./config/maven/settings.xml /etc/maven

WORKDIR /waltz-src

# copy source code
COPY --from=code_checkout /waltz-src .
COPY --from=ui_build /waltz-src/waltz-ng/dist ./waltz-ng/dist

# build
RUN mvn clean package -P${maven_profiles} -Dexec.skip=true -DskipTests=${skip_tests}


#
# step 4: copy output
#
FROM alpine:latest as build_output

WORKDIR /waltz-bin

# copy build output
COPY --from=waltz_build /waltz-src/waltz-web/target/waltz-web.war .