# Build stage — always runs on the native runner arch (amd64) regardless of target platform.
# Static files produced by Vite are platform-agnostic, so this is safe.
FROM --platform=$BUILDPLATFORM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ARG APP_VERSION=dev
ARG GITHUB_REPO
ARG VITE_GOOGLE_CLIENT_ID
ENV VITE_APP_VERSION=$APP_VERSION
ENV VITE_GITHUB_REPO=$GITHUB_REPO
ENV VITE_GOOGLE_CLIENT_ID=$VITE_GOOGLE_CLIENT_ID
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
