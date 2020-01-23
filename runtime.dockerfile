FROM nginx:1.16-alpine

ADD nginx.conf /etc/nginx/nginx.conf
RUN nginx -t

ONBUILD COPY --from=0 /usr/src/app/_site/ /usr/share/nginx/html/
ONBUILD ADD nginx.conf /etc/nginx/conf.d/default.conf
# Make sure our config is fine after adding it into the container
ONBUILD RUN nginx -t
