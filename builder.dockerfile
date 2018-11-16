FROM ruby:2.5

ENV LANG=C.UTF-8 \
    JEKYLL_ENV=production

RUN set -ex \
    && export NODE_VERSION=8.11.3 \
    && export GNUPGHOME="$(mktemp -d)" \
    && for key in \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      56730D5401028683275BD23C23EFEFE93C4CFFFE \
      77984A986EBC2AA786BC0F66B01FBB92821C587A \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    ; do \
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    \
    && export YARN_VERSION=1.9.2 \
    && for key in \
      6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
      gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    \
    && export ZOPFLI_VERSION=1.0.2 \
    && export ZOPFLI_DOWNLOAD_SHA=4a570307c37172d894ec4ef93b6e8e3aacc401e78cbcc51cf85b212dbc379a55 \
    && curl -fsSLO --compressed "https://github.com/google/zopfli/archive/zopfli-$ZOPFLI_VERSION.tar.gz" \
    && echo "$ZOPFLI_DOWNLOAD_SHA *zopfli-$ZOPFLI_VERSION.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/zopfli \
    && tar -xzf "zopfli-$ZOPFLI_VERSION.tar.gz" -C /usr/src/zopfli --strip-components=1 \
    && rm "zopfli-$ZOPFLI_VERSION.tar.gz" \
    && make -C /usr/src/zopfli \
    && install -m 775 /usr/src/zopfli/zopfli /usr/local/bin/ \
    && rm -rf /usr/src/zopfli \
    && { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
    && rm -r "$GNUPGHOME"

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ONBUILD COPY package.json yarn.lock /usr/src/app/
ONBUILD RUN export YARN_CACHE_FOLDER="$(mktemp -d)" \
    && yarn install --production --pure-lockfile \
    && rm -r "$YARN_CACHE_FOLDER"

ONBUILD COPY Gemfile Gemfile.lock /usr/src/app/
ONBUILD RUN bundle install

ONBUILD COPY . /usr/src/app

ONBUILD RUN set -ex && \
    if [ -x ./node_modules/.bin/webpack ]; then \
        ./node_modules/.bin/webpack --config ./config/webpack.config.prod.js; \
    else \
        echo '!! No webpack found, skipping.'; \
    fi

ONBUILD ARG JEKYLL_BUILD_ARGS=
ONBUILD RUN bundle exec jekyll build $JEKYLL_BUILD_ARGS

ONBUILD ARG BUILDER_LIGHT_BUILD=0
ONBUILD RUN set -ex && \
    if [ $BUILDER_LIGHT_BUILD = '0' ]; then \
        find _site \
            -type f \
            -name '*.html' -o \
            -name '*.js' -o \
            -name '*.css' -o \
            -name '*.svg' -o \
            -name '*.js.map' -o \
            -name '*.json' -o \
            -name '*.xml' \
        | xargs -P $(nproc) -I '{}' bash -c "echo 'Compressing {}...' && zopfli -i9 {}"; \
    else \
        echo "Skipping compression because of BUILDER_LIGHT_BUILD=$BUILDER_LIGHT_BUILD"; \
    fi
