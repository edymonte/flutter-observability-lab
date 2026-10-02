# ---------- build do Flutter Web ----------
ARG FLUTTER_VERSION=3.24.5
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /app
COPY pubspec.yaml analysis_options.yaml ./
RUN flutter config --no-analytics --enable-web >/dev/null && flutter pub get
COPY lib ./lib
COPY web ./web
# 'flutter create' só completa o que falta no scaffold web (ícones, manifest); não sobrescreve arquivos existentes.
RUN flutter create --platforms=web --project-name payment_obs_dashboard . >/dev/null \
 && rm -rf test \
 && flutter build web --release --no-web-resources-cdn

# ---------- runtime ----------
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.d/40-obs-config.sh /docker-entrypoint.d/40-obs-config.sh
RUN chmod +x /docker-entrypoint.d/40-obs-config.sh
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
