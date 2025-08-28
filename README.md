# React CI/CD Demo — زهره × مبینا

A pretty Vite + React + Tailwind template with GitLab CI/CD and Docker production image.

## Scripts
- `npm run dev` — start dev server
- `npm run build` — build production
- `npm run preview` — preview build

## Docker build
```bash
# Default (DockerHub base images)
docker build -t my/react-app .

# Sanction-proof: use mirrored base images in your GitLab Container Registry
docker build   --build-arg BASE_NODE=registry.example.com/my-base/node:20-alpine   --build-arg BASE_NGINX=registry.example.com/my-base/nginx:1.27-alpine   -t registry.example.com/my-group/my-app:latest .
```
