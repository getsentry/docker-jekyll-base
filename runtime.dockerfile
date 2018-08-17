FROM nginx:1.14-alpine

ONBUILD COPY --from=0 /usr/src/app/_site/ /usr/share/nginx/html/
ONBUILD ADD nginx.conf /etc/nginx/conf.d/default.conf
