# Build args allow using mirrored base images (enterprise-friendly / sanction-proof)
ARG BASE_NODE=node:20-alpine
ARG BASE_NGINX=nginx:1.27-alpine

# ---------- Build stage ----------
FROM ${BASE_NODE} AS build
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
# Prefer npm ci if lockfile exists
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
RUN npm run build

# ---------- Runtime stage ----------
FROM ${BASE_NGINX} AS runtime
# Copy build
COPY --from=build /app/dist /usr/share/nginx/html
# Replace default nginx config for React SPA
RUN printf 'server {\n  listen 80;\n  server_name _;\n  root /usr/share/nginx/html;\n  location / { try_files $uri /index.html; }\n}\n' > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
